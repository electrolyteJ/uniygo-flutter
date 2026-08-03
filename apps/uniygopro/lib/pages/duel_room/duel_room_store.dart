import 'dart:async';
import 'dart:developer' as console;
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:service_loader/service_loader.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_card/lf_table.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_card_mycard/src/deck_validator.dart';

import '../../models/deck_model.dart';
import '../../services/deck_service.dart';
import '../../widgets/shared/duel_room.dart';

/// 决斗房间状态仓库。
class DuelRoomStore extends ChangeNotifier {
  static const _autoHandPrefKey = 'duel.auto_hand_enabled';
  static const _autoTurnOrderPrefKey = 'duel.auto_turn_order_enabled';
  List<String> duelLogs = [];
  RoomStage stage = const RoomNotJoined();
  PlayerType selfType = PlayerType.unknown;
  bool isHost = false;
  List<PlayerInfo> players = [];
  int observerCount = 0;
  int? myHandResult;
  int? opponentHandResult;
  bool? isFirstTurn;
  RoomOptions? roomOptions;

  String? selectedDeckName;
  List<DeckMeta> availableDecks = [];
  bool autoHandEnabled = false;
  bool autoTurnOrderEnabled = false;
  IDuelService? _duelService;
  final cardService = ServiceFactory.create<CardService>();
  final Random random = Random();
  StreamSubscription<RoomStage>? _roomStageSub;

  // ── 卡组校验 ──
  List<String>? invalidationDeckResult;

  PlayerInfo? get selfPlayer {
    final mySlotVal = selfType.slot;
    final myPlayer = players
        .firstWhere(
      (p) => p.pos == mySlotVal,
      orElse: () => PlayerInfo(name: '', pos: PlayerType.unknown.slot));
    return myPlayer;
  }

  /// 当前自己对应的决斗位是否已经准备。
  bool get isSelfReady {
    final mySlot = selfType.slot;
    if (mySlot < 0 || mySlot > 1) {
      return false;
    }
    return players
        .where((p) => p.pos == selfType.slot)
        .any((p) => p.ready);
  }

  DuelRoomStore() {
    loadDecks();
    unawaited(_loadPreferences());
  }

  void markChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    console.log('DuelRoomStore.dispose()');
  }

  /// 清空与当前房间会话相关的临时状态。
  void reset() {
    console.log('DuelRoomStore.reset()');
    // 等待房间重置
    stage = const RoomNotJoined();
    _roomStageSub?.cancel();
    selfType = PlayerType.unknown;
    isHost = false;
    players = [];
    observerCount = 0;
    myHandResult = null;
    opponentHandResult = null;
    isFirstTurn = null;
    roomOptions = null;
    invalidationDeckResult = null;
    selectedDeckName = availableDecks.first.deckName;
    notifyListeners();
  }

  /// 从本地偏好中恢复自动操作开关。
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    autoHandEnabled = prefs.getBool(_autoHandPrefKey) ?? false;
    autoTurnOrderEnabled = prefs.getBool(_autoTurnOrderPrefKey) ?? false;
    notifyListeners();
  }

  Future<void> setAutoHandEnabled(bool value) async {
    if (isSelfReady && value != autoHandEnabled) {
      return;
    }
    autoHandEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoHandPrefKey, value);
    notifyListeners();
  }

  Future<void> setAutoTurnOrderEnabled(bool value) async {
    if (isSelfReady && value != autoTurnOrderEnabled) {
      return;
    }
    autoTurnOrderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoTurnOrderPrefKey, value);
    notifyListeners();
  }
  void sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    stage = RoomSelectingHand();
    myHandResult = hand.value;
    _duelService?.chooseHand(hand);
    notifyListeners();
  }

  void sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    stage = RoomInDuel(isFirstTurn: first);
    isFirstTurn = first;
    _duelService?.chooseTurnOrder(first);
    notifyListeners();
  }

  void kickPlayer(int pos) {
    _duelService?.kickPlayer(pos);
  }

  void becomeObserver() {
    _duelService?.becomeObserver();
  }

  void becomeDuelist() {
    _duelService?.becomeDuelist();
  }

  void startDuel() {
    _duelService?.startDuel();
  }

  Future<void> loadDecks() async {
    final deckService = DeckService();
    final builtinDecks = await deckService.loadBuiltinDecks();
    final userDecks = await deckService.loadDeckList();
    final decks = [...builtinDecks, ...userDecks];
    availableDecks = decks;
    console.log(
      'Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}',
    );
    if (selectedDeckName == null && decks.isNotEmpty) {
      selectedDeckName = decks.first.deckName;
    }
    notifyListeners();
  }

  Future<EditingDeck?> selectDeck(BuildContext context, String? deckName) async {
    if (deckName == null) {
      return null;
    }
    selectedDeckName = deckName;
    final deckService = DeckService();
    final deck = await deckService.loadDeck(deckName);
    console.log('loadDeck: $deckName -> $deck');
    if (deck == null || deck.main.isEmpty) {
      return null;
    }
    // ── 禁限卡表校验 ──
    if (roomOptions?.noCheckDeck == false) {
      final lflistHash = roomOptions!.lfTableHash;
      final lfTable =await cardService.getLfTable(lflistHash);
      if (lfTable !=null) {
        final validator = DeckValidator(lfInfos: lfTable.lfInfos);
        invalidationDeckResult = validator.validate(deck.main, deck.extra, deck.side);
      } else {
        // 服务端指定了卡表但客户端未加载该表，跳过校验
        invalidationDeckResult = null;
      }
      if (invalidationDeckResult?.isNotEmpty == true) {
        notifyListeners();
        return null;
      }
    } else {
      invalidationDeckResult = null;
    }
    notifyListeners();
    return deck;
  }

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }

  /// 准备按钮入口：未准备时提交卡组并 ready，已准备时取消 ready。
  Future<void> toggleReady(BuildContext context) async {
    if (isSelfReady) {
      _duelService?.unready();
    } else {
      if (invalidationDeckResult?.isNotEmpty == true) {
        // 卡组未通过校验，不允许准备
        // 展示第一个违规原因
        if (context.mounted) {
          final firstError = invalidationDeckResult!.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('卡组不合规: $firstError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final deck = await selectDeck(context, selectedDeckName);
      if (deck == null || deck.main.isEmpty) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('卡组为空或加载失败'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final mainBytes = _deckToBytes(deck.main.map((c) => c.code).toList());
      final extraBytes = _deckToBytes(deck.extra.map((c) => c.code).toList());
      _duelService?.submitDeck(mainBytes, extraBytes);
      _duelService?.ready();
    }
  }

  /// 把卡组中的卡片代码编码成服务端需要的 little-endian 字节序列。
  Uint8List _deckToBytes(List<int> codes) {
    final bytes = Uint8List(codes.length * 4);
    final bd = ByteData.view(bytes.buffer);
    for (int i = 0; i < codes.length; i++) {
      bd.setInt32(i * 4, codes[i], Endian.little);
    }
    return bytes;
  }

  void bindRoomStageChange(BuildContext context) {
    _roomStageSub = _duelService?.onRoomStageChange.listen((roomStage) {
      players = roomStage.players;
      observerCount = roomStage.observerCount;
      stage = roomStage;
      console.log('Room stage changed: $roomStage');
      switch (roomStage) {
        case RoomNotJoined():
          //游戏结束或者离开房间后，重置房间状态
          backHome(context);
          break;
        case RoomJoined():
          break;
        case RoomInLobby():
          selfType = roomStage.selfType;
          isHost = roomStage.isHost;
          roomOptions = roomStage.options;
          break;
        case RoomSelectingHand():
          if (autoHandEnabled) {
            Timer(const Duration(milliseconds: 700), () {
              opponentHandResult = 0;
              final hands = HandType.values
                  .where((hand) => hand != HandType.unknown)
                  .toList();
              sendHand(hands[random.nextInt(hands.length)]);
            });
          }
          break;
        case RoomHandResult():
          myHandResult = roomStage.myHand;
          opponentHandResult = roomStage.opponentHand;
          break;
        case RoomSelectingTurn():
          if (autoTurnOrderEnabled) {
            sendTp(random.nextBool());
          }
          break;
        case RoomInDuel():
          myHandResult = 0;
          opponentHandResult = 0;
          isFirstTurn = roomStage.isFirstTurn;
          break;
        case RoomDuelEnded():
          backHome(context);
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }
  Future<LfTable?> getLfTable(int hash) async {
    return cardService.getLfTable(hash);
  }
}
