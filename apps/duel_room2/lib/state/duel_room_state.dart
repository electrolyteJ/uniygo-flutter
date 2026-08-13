import 'dart:async';
import 'dart:developer' as console;
import 'dart:math';

import 'package:biz/ygo_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';

import '../../util/ygo_data_util.dart';
import '../../providers/service_providers.dart';
import 'duel_field_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
/// 房间页不可变状态快照。
///
/// 房间阶段/玩家列表等均由服务端事件整体替换，适合不可变建模；
/// 修改一律走 [DuelRoomNotifier] 的方法。
class DuelRoomState {
  const DuelRoomState({
    this.stage = const RoomNotJoined(),
    this.selfType = PlayerType.unknown,
    this.isHost = false,
    this.players = const [],
    this.observerCount = 0,
    this.myHandResult,
    this.opponentHandResult,
    this.isFirstTurn,
    this.roomOptions,
    this.selectedDeckName,
    this.availableDecks = const [],
    this.autoHandEnabled = false,
    this.autoTurnOrderEnabled = false,
    this.autoDuelEnabled = false,
    this.invalidationDeckResult,
    this.errorMessage,
  });

  final RoomStage stage;
  final PlayerType selfType;
  final bool isHost;
  final List<PlayerInfo> players;
  final int observerCount;
  final int? myHandResult;
  final int? opponentHandResult;
  final bool? isFirstTurn;
  final RoomOptions? roomOptions;

  final String? selectedDeckName;
  final List<DeckInfo> availableDecks;
  final bool autoHandEnabled;
  final bool autoTurnOrderEnabled;
  final bool autoDuelEnabled;

  /// 卡组校验结果（null=未校验/不校验，空列表=通过）。
  final List<String>? invalidationDeckResult;
  final String? errorMessage;

  static const _sentinel = Object();

  DuelRoomState copyWith({
    RoomStage? stage,
    PlayerType? selfType,
    bool? isHost,
    List<PlayerInfo>? players,
    int? observerCount,
    Object? myHandResult = _sentinel,
    Object? opponentHandResult = _sentinel,
    Object? isFirstTurn = _sentinel,
    Object? roomOptions = _sentinel,
    Object? selectedDeckName = _sentinel,
    List<DeckInfo>? availableDecks,
    bool? autoHandEnabled,
    bool? autoTurnOrderEnabled,
    bool? autoDuelEnabled,
    Object? invalidationDeckResult = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return DuelRoomState(
      stage: stage ?? this.stage,
      selfType: selfType ?? this.selfType,
      isHost: isHost ?? this.isHost,
      players: players ?? this.players,
      observerCount: observerCount ?? this.observerCount,
      myHandResult: identical(myHandResult, _sentinel)
          ? this.myHandResult
          : myHandResult as int?,
      opponentHandResult: identical(opponentHandResult, _sentinel)
          ? this.opponentHandResult
          : opponentHandResult as int?,
      isFirstTurn: identical(isFirstTurn, _sentinel)
          ? this.isFirstTurn
          : isFirstTurn as bool?,
      roomOptions: identical(roomOptions, _sentinel)
          ? this.roomOptions
          : roomOptions as RoomOptions?,
      selectedDeckName: identical(selectedDeckName, _sentinel)
          ? this.selectedDeckName
          : selectedDeckName as String?,
      availableDecks: availableDecks ?? this.availableDecks,
      autoHandEnabled: autoHandEnabled ?? this.autoHandEnabled,
      autoTurnOrderEnabled: autoTurnOrderEnabled ?? this.autoTurnOrderEnabled,
      autoDuelEnabled: autoDuelEnabled ?? this.autoDuelEnabled,
      invalidationDeckResult: identical(invalidationDeckResult, _sentinel)
          ? this.invalidationDeckResult
          : invalidationDeckResult as List<String>?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

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
}

final duelRoomProvider =
    NotifierProvider<DuelRoomNotifier, DuelRoomState>(DuelRoomNotifier.new);

/// 决斗房间控制器（Riverpod 版 DuelRoomStore）。
///
/// 与 Provider 版的差异：
/// - 不再持有 BuildContext：导航由页面 `ref.listen(stage)` 负责，
///   准备失败的提示通过 [toggleReady] 的返回值交给页面弹 SnackBar。
/// - 流订阅从 `bind(context)` 改为 [start]（由页面在 connect 完成后调用），
///   取消逻辑收敛在 `ref.onDispose`。
class DuelRoomNotifier extends Notifier<DuelRoomState> {
  static const _autoHandPrefKey = 'duel.auto_hand_enabled';
  static const _autoTurnOrderPrefKey = 'duel.auto_turn_order_enabled';
  static const _autoDuelPrefKey = 'duel.auto_duel_enabled';

  IDuelService get _duelService => ref.read(duelServiceProvider);
  YgoDataService get _dataService => ref.read(dataServiceProvider);
  final Random random = Random();
  StreamSubscription<RoomStage>? _roomStageSub;
  StreamSubscription<YgoStocMsg>? _msgSub;
  bool _disposed = false;

  @override
  DuelRoomState build() {
    ref.onDispose(() {
      _disposed = true;
      _roomStageSub?.cancel();
      _msgSub?.cancel();
    });
    loadDecks();
    unawaited(_loadPreferences());
    return const DuelRoomState();
  }

  /// 从本地偏好中恢复自动操作开关。
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    state = state.copyWith(
      autoHandEnabled: prefs.getBool(_autoHandPrefKey) ?? false,
      autoTurnOrderEnabled: prefs.getBool(_autoTurnOrderPrefKey) ?? false,
      autoDuelEnabled: prefs.getBool(_autoDuelPrefKey) ?? false,
    );
  }

  Future<void> setAutoHandEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoHandEnabled) {
      return;
    }
    state = state.copyWith(autoHandEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoHandPrefKey, value);
  }

  Future<void> setAutoTurnOrderEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoTurnOrderEnabled) {
      return;
    }
    state = state.copyWith(autoTurnOrderEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoTurnOrderPrefKey, value);
  }

  Future<void> setAutoDuelEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoDuelEnabled) {
      return;
    }
    state = state.copyWith(autoDuelEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDuelPrefKey, value);
  }

  void sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    state = state.copyWith(
      stage: RoomSelectingHand(),
      myHandResult: hand.value,
    );
    _duelService.chooseHand(hand);
  }

  void sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    // 不做乐观状态更新：先后攻由服务器裁决（AI 可能覆盖选择，如
    // SIMPLE_AI 强制人类先攻）。提前设置 stage/isFirstTurn 会导致：
    //  1. DuelFieldPage 在乐观 RoomInDuel 上提前挂载，弹出取到错误值的提示；
    //  2. 紧接着服务器下发 RoomStartDuel（与 RoomInDuel 平级）使页面卸载，
    //     再下发 RoomInDuel(first:...) 又重挂，导致先后攻提示重复出现。
    // 故仅发送选择，stage/isFirstTurn 均由服务器下发的 RoomInDuel 驱动。
    _duelService.chooseTurnOrder(first);
  }

  void kickPlayer(int pos) {
    _duelService.kickPlayer(pos);
  }

  void becomeObserver() {
    _duelService.becomeObserver();
  }

  void becomeDuelist() {
    _duelService.becomeDuelist();
  }

  void startDuel() {
    _duelService.startDuel();
  }

  Future<void> loadDecks() async {
    final decks = await _dataService.loadDeckList();
    if (_disposed) return;
    console.log(
      'Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}',
    );
    state = state.copyWith(
      availableDecks: decks,
      selectedDeckName: state.selectedDeckName ??
          (decks.isEmpty ? null : decks.first.deckName),
    );
  }

  Future<({List<CardInfo> main, List<CardInfo> extra, List<CardInfo> side})?>
  selectDeck(String? deckName) async {
    if (deckName == null) {
      return null;
    }
    state = state.copyWith(selectedDeckName: deckName);
    final deckInfo = await _dataService.loadDeck(deckName);
    console.log('loadDeck: $deckName -> $deckInfo');
    if (deckInfo == null || deckInfo.mainDeck.isEmpty) {
      return null;
    }
    final main = await _resolveCards(deckInfo.mainDeck);
    final extra = await _resolveCards(deckInfo.extraDeck);
    final side = await _resolveCards(deckInfo.sideDeck);

    // ── 禁限卡表校验 ──
    final options = state.roomOptions;
    if (options?.noCheckDeck == false) {
      final lflistHash = options!.lfTableHash;
      final lfTable = await _dataService.getLfTable(lflistHash);
      List<String>? result;
      if (lfTable != null) {
        final validator = DeckValidator(lfInfos: lfTable.lfInfos);
        result = validator.validate(main, extra, side);
      }
      state = state.copyWith(invalidationDeckResult: result);
      if (result?.isNotEmpty == true) {
        return null;
      }
    } else {
      state = state.copyWith(invalidationDeckResult: null);
    }
    return (main: main, extra: extra, side: side);
  }

  Future<void> refreshSelectedDeckValidation() async {
    await loadDecks();
    await selectDeck(state.selectedDeckName);
  }

  /// 准备按钮入口：未准备时提交卡组并 ready，已准备时取消 ready。
  ///
  /// 返回 null 表示已正常提交/取消；返回非空字符串表示校验失败原因，
  /// 由调用方（页面）负责展示。
  Future<String?> toggleReady() async {
    if (state.isSelfReady) {
      _duelService.unready();
      return null;
    }
    if (state.invalidationDeckResult?.isNotEmpty == true) {
      return '卡组不合规: ${state.invalidationDeckResult!.first}';
    }
    final result = await selectDeck(state.selectedDeckName);
    if (result == null || result.main.isEmpty) {
      return '卡组为空或加载失败';
    }
    final mainBytes = deckToBytes(result.main.map((c) => c.code).toList());
    final extraBytes = deckToBytes(result.extra.map((c) => c.code).toList());
    ref
        .read(duelFieldProvider.notifier)
        .setKnownSelfExtraDeckCodes(result.extra.map((c) => c.code).toList());
    _duelService.submitDeck(mainBytes, extraBytes);
    _duelService.ready();
    return null;
  }

  void setError(int type, int code) {
    state = state.copyWith(errorMessage: _errorMessage(type, code));
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
    state = state.copyWith(errorMessage: null);
  }

  /// 开始订阅房间消息。必须在 `duelService.connect()` 完成后调用，
  /// 否则订阅会被路由到默认 WebSocket 服务。
  void start() {
    _msgSub = _duelService.onServerMessage.listen((msg) {
      if (msg.errorMsg != null) {
        final err = msg.errorMsg!;
        setError(err.errorType, err.errorCode);
      }
    });
    _roomStageSub = _duelService.onRoomStageChange.listen((roomStage) {
      // 导航（RoomNotJoined → 回首页）由页面 ref.listen(stage) 负责，
      // 控制器只维护状态。
      var next = state.copyWith(
        players: roomStage.players,
        observerCount: roomStage.observerCount,
        stage: roomStage,
      );
      switch (roomStage) {
        case RoomNotJoined():
          break;
        case RoomJoined():
          break;
        case RoomInLobby():
          next = next.copyWith(
            selfType: roomStage.selfType,
            isHost: roomStage.isHost,
            roomOptions: roomStage.options,
          );
          // 自动加入决斗：房主开启 autoDuelEnabled，双方准备后自动 startDuel
          if (next.isHost && next.autoDuelEnabled && next.isAllReady) {
            console.log('Auto duel enabled and all ready, starting duel...');
            _duelService.startDuel();
          }
          break;
        case RoomSelectingHand():
          if (state.autoHandEnabled) {
            Timer(const Duration(milliseconds: 700), () {
              if (_disposed) return;
              final hands = HandType.values
                  .where((hand) => hand != HandType.unknown)
                  .toList();
              sendHand(hands[random.nextInt(hands.length)]);
            });
          }
          break;
        case RoomHandResult():
          next = next.copyWith(
            myHandResult: roomStage.myHand,
            opponentHandResult: roomStage.opponentHand,
          );
          break;
        case RoomSelectingTurn():
          if (state.autoTurnOrderEnabled) {
            sendTp(random.nextBool());
          }
          break;
        case RoomInDuel():
          next = next.copyWith(
            myHandResult: 0,
            opponentHandResult: 0,
            isFirstTurn: roomStage.isFirstTurn,
          );
          break;
        case RoomDuelEnded():
          break;
        default:
          break;
      }
      state = next;
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
