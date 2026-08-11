import 'dart:async';
import 'dart:developer' as console;
import 'dart:math';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';

import 'package:service_loader/service_loader.dart';

import '../../service_singleton.dart';
import 'duel_room_exit.dart';
import 'duel/duel_field_store.dart';

/// 决斗房间状态仓库。
class DuelRoomStore extends ChangeNotifier {
  static const _autoHandPrefKey = 'duel.auto_hand_enabled';
  static const _autoTurnOrderPrefKey = 'duel.auto_turn_order_enabled';
  static const _autoDuelPrefKey = 'duel.auto_duel_enabled';
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
  List<DeckInfo> availableDecks = [];
  bool autoHandEnabled = false;
  bool autoTurnOrderEnabled = false;
  bool autoDuelEnabled = false;
  IDuelService? _duelService;
  final _dataService = ServiceSingleton.instance.dataService;
  final Random random = Random();
  StreamSubscription<RoomStage>? _roomStageSub;

  // ── 卡组校验 ──
  List<String>? invalidationDeckResult;

  PlayerInfo? get selfPlayer {
    final mySlotVal = selfType.slot;
    final myPlayer = players.firstWhere(
      (p) => p.pos == mySlotVal,
      orElse: () => PlayerInfo(name: '', pos: PlayerType.unknown.slot),
    );
    return myPlayer;
  }

  /// 当前自己对应的决斗位是否已经准备。
  bool get isSelfReady {
    final mySlot = selfType.slot;
    if (mySlot < 0 || mySlot > 1) {
      return false;
    }
    return players.where((p) => p.pos == selfType.slot).any((p) => p.ready);
  }

  /// 当前房间中双方玩家是否都已经准备。
  bool get isAllReady {
    if (players.length < 2) {
      return false;
    }
    for (final p in players) {
      if (p.pos == 0 || p.pos == 1) {
        if (!p.ready) {
          return false;
        }
      }
    }
    return true;
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
    _msgSub?.cancel();
    selfType = PlayerType.unknown;
    isHost = false;
    players = [];
    observerCount = 0;
    myHandResult = null;
    opponentHandResult = null;
    isFirstTurn = null;
    roomOptions = null;
    invalidationDeckResult = null;
    errorMessage = null;
    selectedDeckName = availableDecks.first.deckName;
    notifyListeners();
  }

  /// 从本地偏好中恢复自动操作开关。
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    autoHandEnabled = prefs.getBool(_autoHandPrefKey) ?? false;
    autoTurnOrderEnabled = prefs.getBool(_autoTurnOrderPrefKey) ?? false;
    autoDuelEnabled = prefs.getBool(_autoDuelPrefKey) ?? false;
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

  Future<void> setAutoDuelEnabled(bool value) async {
    if (isSelfReady && value != autoDuelEnabled) {
      return;
    }
    autoDuelEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDuelPrefKey, value);
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
    // 不做乐观状态更新：先后攻由服务器裁决（AI 可能覆盖选择，如
    // SIMPLE_AI 强制人类先攻）。提前设置 stage/isFirstTurn 会导致：
    //  1. DuelFieldPage 在乐观 RoomInDuel 上提前挂载，弹出取到错误值的提示；
    //  2. 紧接着服务器下发 RoomStartDuel（与 RoomInDuel 平级）使页面卸载，
    //     再下发 RoomInDuel(first:...) 又重挂，导致先后攻提示重复出现。
    // 故仅发送选择，stage/isFirstTurn 均由服务器下发的 RoomInDuel 驱动。
    _duelService?.chooseTurnOrder(first);
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
    final decks = await _dataService.loadDeckList();
    availableDecks = decks;
    console.log(
      'Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}',
    );
    if (selectedDeckName == null && decks.isNotEmpty) {
      selectedDeckName = decks.first.deckName;
    }
    notifyListeners();
  }

  Future<({List<CardInfo> main, List<CardInfo> extra, List<CardInfo> side})?>
  selectDeck(BuildContext context, String? deckName) async {
    if (deckName == null) {
      return null;
    }
    selectedDeckName = deckName;
    final deckInfo = await _dataService.loadDeck(deckName);
    console.log('loadDeck: $deckName -> $deckInfo');
    if (deckInfo == null || deckInfo.mainDeck.isEmpty) {
      return null;
    }
    final main = await _resolveCards(deckInfo.mainDeck);
    final extra = await _resolveCards(deckInfo.extraDeck);
    final side = await _resolveCards(deckInfo.sideDeck);

    // ── 禁限卡表校验 ──
    if (roomOptions?.noCheckDeck == false) {
      final lflistHash = roomOptions!.lfTableHash;
      final lfTable = await _dataService.getLfTable(lflistHash);
      if (lfTable != null) {
        final validator = DeckValidator(lfInfos: lfTable.lfInfos);
        invalidationDeckResult = validator.validate(main, extra, side);
      } else {
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
    return (main: main, extra: extra, side: side);
  }

  Future<void> refreshSelectedDeckValidation(BuildContext context) async {
    await loadDecks();
    if (!context.mounted) return;
    await selectDeck(context, selectedDeckName);
  }

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }

  /// 准备按钮入口：未准备时提交卡组并 ready，已准备时取消 ready。
  Future<void> toggleReady(BuildContext context) async {
    if (isSelfReady) {
      _duelService?.unready();
    } else {
      final duelFieldStore = context.read<DuelFieldStore>();
      if (invalidationDeckResult?.isNotEmpty == true) {
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
      final result = await selectDeck(context, selectedDeckName);
      if (result == null || result.main.isEmpty) {
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
      final mainBytes = _deckToBytes(result.main.map((c) => c.code).toList());
      final extraBytes = _deckToBytes(result.extra.map((c) => c.code).toList());
      duelFieldStore.setKnownSelfExtraDeckCodes(
        result.extra.map((c) => c.code).toList(),
      );
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

  String? errorMessage;
  void setError(int type, int code) {
    errorMessage = _errorMessage(type, code);
    notifyListeners();
  }

  String _errorMessage(int type, int code) {
    switch (type) {
      case 1:
        return '连接已断开';
      case 2:
        return '你已经被踢出房间';
      case 3:
        return '错误: $code';
      case 4:
        return '卡组无效 (错误码: $code)';
      case 5:
        return '卡组数量不正确 (错误码: $code)';
      case 6:
        return '主卡组需要至少40张';
      case 7:
        return '额外卡组不能超过15张';
      case 8:
        return '副卡组不能超过15张';
      case 9:
        return '禁限卡表不匹配';
      default:
        return '服务器错误: type=$type code=$code';
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  StreamSubscription<YgoStocMsg>? _msgSub;

  void bindRoomStageChange(BuildContext context) {
    _msgSub = _duelService?.onServerMessage.listen((msg) {
      if (msg.errorMsg != null) {
        final err = msg.errorMsg!;
        setError(err.errorType, err.errorCode);
      }
    });
    _roomStageSub = _duelService?.onRoomStageChange.listen((roomStage) {
      if (!context.mounted) return;
      players = roomStage.players;
      observerCount = roomStage.observerCount;
      stage = roomStage;
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
          // 自动加入决斗：房主开启 autoDuelEnabled，双方准备后自动 startDuel
          if (isHost && autoDuelEnabled && isAllReady) {
            console.log('Auto duel enabled and all ready, starting duel...');
            _duelService?.startDuel();
          }
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
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  Future<LfTable?> getLfTable(int hash) async {
    return _dataService.getLfTable(hash);
  }

  Future<List<CardInfo>> _resolveCards(List<DeckCard> deckCards) async {
    final result = <CardInfo>[];
    for (final dc in deckCards) {
      try {
        final card = await _dataService.getCard(dc.code);
        if (card != null) {
          for (var i = 0; i < dc.count; i++) {
            result.add(card);
          }
        }
      } catch (e) {
        console.log('Failed to resolve card ${dc.code}: $e');
      }
    }
    return result;
  }
}
