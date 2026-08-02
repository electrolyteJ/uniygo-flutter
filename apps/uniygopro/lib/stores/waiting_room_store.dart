import 'dart:async';
import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck_model.dart';
import '../services/deck_service.dart';

/// 等待房间状态仓库。
///
/// 负责维护大厅阶段、玩家列表、准备状态、自动猜拳/先后手配置，
/// 以及准备时要提交的卡组信息。
class WaitingRoomStore extends ChangeNotifier {
  static const _autoHandPrefKey = 'duel.auto_hand_enabled';
  static const _autoTurnOrderPrefKey = 'duel.auto_turn_order_enabled';

  WaitingRoomStore() {
    loadDecks();
    unawaited(_loadPreferences());
  }

  RoomStage stage = const RoomNotJoined();
  SelfType selfType = SelfType.unknown;
  bool isHost = false;
  List<RoomPlayer> players = [];
  int observerCount = 0;
  int? myHandResult;
  int? opponentHandResult;
  bool? isFirstTurn;
  RoomOptions? roomOptions;
  String? errorMessage;
  String? selectedDeckName;
  List<DeckMeta> availableDecks = [];
  bool autoHandEnabled = false;
  bool autoTurnOrderEnabled = false;
  IDuelService? _duelService;

  /// 当前自己对应的决斗位是否已经准备。
  bool get isSelfReady {
    final mySlot = selfType.slot;
    if (mySlot < 0 || mySlot > 1) {
      return false;
    }
    return players.any((player) => player.pos == mySlot && player.ready);
  }

  void markChanged() {
    notifyListeners();
  }

  /// 清空与当前房间会话相关的临时状态。
  void reset() {
    console.log('WaitingRoomStore.reset()');
    // 等待房间重置
    stage = const RoomNotJoined();
    selfType = SelfType.unknown;
    isHost = false;
    players = [];
    observerCount = 0;
    myHandResult = null;
    opponentHandResult = null;
    isFirstTurn = null;
    roomOptions = null;
    errorMessage = null;
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

  void setError(String message) {
    errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void ready(int handValue) {
    stage = RoomReady();
    notifyListeners();
  }

  void unready(int handValue) {
    stage = RoomUnready();
    notifyListeners();
  }
  void sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    _duelService?.chooseHand(hand);
    setHandResult(hand.value);
  }
  void setHandResult(int handValue) {
    stage = RoomSelectingHand();
    myHandResult = handValue;
    notifyListeners();
  }
  void sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    _duelService?.chooseTurnOrder(first);
    setTpResult(first);
  }
  void setTpResult(bool first) {
    stage = RoomInDuel(isFirstTurn: first);
    isFirstTurn = first;
    notifyListeners();
  }

  void kickPlayer(int pos) {
    _duelService?.kickPlayer(pos);
  }
  void becomeObserver(){
    _duelService?.becomeObserver();
  }

  void becomeDuelist(){
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

  void selectDeck(String deckName) {
    selectedDeckName = deckName;
    notifyListeners();
  }

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }

  /// 准备按钮入口：未准备时提交卡组并 ready，已准备时取消 ready。
  Future<void> toggleReady(BuildContext context) async {
    final isReady = players
        .where((p) => p.pos == selfType.slot)
        .any((p) => p.ready);
    if (isReady) {
      _duelService?.unready();
    } else {
      final deckName = selectedDeckName;
      if (deckName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先选择卡组'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final deckService = DeckService();
      final deck = await deckService.loadDeck(deckName);
      console.log('loadDeck: $deckName -> $deck');
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

  void enableTurnOrderSelection() {
    // if (stage is RoomSelectingHand) {
    //   stage = RoomSelectingTurn(myHand: myHandResult, opponentHand: opponentHandResult);
    // }
    notifyListeners();
  }
}
