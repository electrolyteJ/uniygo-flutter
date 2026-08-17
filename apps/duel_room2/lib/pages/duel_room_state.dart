import 'dart:async';
import 'dart:developer' as console;
import 'dart:math';

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';

import 'package:biz/util/ygo_data_util.dart';
import 'package:duelink/duelink.dart' hide CardInfo;

import 'duel/duel_field_state.dart';

/// 卡组解析结果：主卡/额外/副卡的卡信息列表。
typedef ResolvedDeck = ({
  List<CardInfo> main,
  List<CardInfo> extra,
  List<CardInfo> side,
});

/// 最近一次提交给服务器的卡组构成（卡码列表）。
///
/// match 模式（三局两胜）局间换备时作为数量基准：
/// 换备后主/额/副各分区数量必须与提交时一致。
typedef SubmittedDeck = ({List<int> main, List<int> extra, List<int> side});

/// 换备编辑的卡组分区。
enum SidingZone { main, extra, side }

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
    this.submittedDeck,
    this.sidingDeck,
    this.sidingBaseline,
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

  /// 最近一次提交的卡组构成（准备时提交，换备确认后用新构成替换）。
  ///
  /// 换备的数量基准；为 null 表示尚未提交过卡组
  /// （此时进入换备阶段会回退到当前所选卡组的构成）。
  final SubmittedDeck? submittedDeck;

  /// 正在编辑的换备构成（仅 RoomSideDecking 阶段非 null）。
  final ResolvedDeck? sidingDeck;

  /// 本次换备的基准构成（进入换备阶段时初始化，仅该阶段非 null）。
  final ResolvedDeck? sidingBaseline;

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
    Object? submittedDeck = _sentinel,
    Object? sidingDeck = _sentinel,
    Object? sidingBaseline = _sentinel,
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
      submittedDeck: identical(submittedDeck, _sentinel)
          ? this.submittedDeck
          : submittedDeck as SubmittedDeck?,
      sidingDeck: identical(sidingDeck, _sentinel)
          ? this.sidingDeck
          : sidingDeck as ResolvedDeck?,
      sidingBaseline: identical(sidingBaseline, _sentinel)
          ? this.sidingBaseline
          : sidingBaseline as ResolvedDeck?,
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
  ///
  /// 必须 pos0 与 pos1 两个决斗位都有人就绪才算「全部就绪」：
  /// 旧实现只看 `players.length >= 2`，tag 模式下来了两个同队座位
  /// （如 pos0+pos2）也会误判为可以开局。
  bool get isAllReady {
    final pos0 = players.where((p) => p.pos == 0).toList();
    final pos1 = players.where((p) => p.pos == 1).toList();
    if (pos0.isEmpty || pos1.isEmpty) {
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

  // ─── 换备（match 模式局间换 Side Deck）───────────────

  /// 换备编辑中的主卡组（非换备阶段为 null）。
  List<CardInfo>? get sidingMain => sidingDeck?.main;

  /// 换备编辑中的额外卡组（非换备阶段为 null）。
  List<CardInfo>? get sidingExtra => sidingDeck?.extra;

  /// 换备编辑中的副卡组（非换备阶段为 null）。
  List<CardInfo>? get sidingSide => sidingDeck?.side;

  /// 当前换备构成各分区数量是否与基准一致（一致才允许提交）。
  bool get isSidingCountsValid {
    final siding = sidingDeck;
    final baseline = sidingBaseline;
    if (siding == null || baseline == null) return false;
    return siding.main.length == baseline.main.length &&
        siding.extra.length == baseline.extra.length &&
        siding.side.length == baseline.side.length;
  }
}

final duelRoomProvider = NotifierProvider<DuelRoomNotifier, DuelRoomState>(
  DuelRoomNotifier.new,
);

/// 房间级连接生命周期钩子：房间 ProviderScope 销毁时兜底断开 socket。
///
/// 应用级单例 duelService 的连接不随房间页面回收，若不主动断开，
/// 系统返回等方式离开房间后服务器会一直保留座位。房间页需在本 scope 内
/// `ref.watch` 本 provider 使其创建，scope 销毁即触发 onDispose。
/// [IDuelService.disconnect] 幂等，与 duel_room_exit.dart 中显式的
/// disconnect 重复调用是安全的。
final roomConnectionLifetimeProvider = Provider<void>((ref) {
  ref.onDispose(() {
    unawaited(ref.read(duelServiceProvider).disconnect());
  });
});

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

  /// 自动猜拳延时器：手动出拳或退出房间时必须取消，
  /// 否则玩家已手动出拳后定时器仍会再自动出一次拳。
  Timer? _autoHandTimer;
  bool _disposed = false;

  /// 是否已进入离开房间流程（backHome 去重用）。
  bool _leaving = false;

  /// 是否已进入离开流程。
  ///
  /// 供离房兜底导航（leaveRoomAfterNotJoined）判断「是否已有主动退出
  /// 在跑」：已标记则只补导航、不重复音效/断开。
  bool get isLeaving => _leaving;

  /// 标记进入离开流程；已标记则返回 false，
  /// 防止 disconnect 触发的 RoomNotJoined 再次走一遍退出流程。
  bool markLeaving() {
    if (_leaving) return false;
    _leaving = true;
    return true;
  }

  @override
  DuelRoomState build() {
    ref.onDispose(() {
      _disposed = true;
      _roomStageSub?.cancel();
      _msgSub?.cancel();
      _autoHandTimer?.cancel();
    });
    loadDecks();
    unawaited(_loadPreferences());
    return const DuelRoomState();
  }

  /// 从本地偏好中恢复自动操作开关。
  ///
  /// 失败时经由 [DuelRoomState.errorMessage] 渠道提示，
  /// 不让异步异常变成未处理异常。
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      state = state.copyWith(
        autoHandEnabled: prefs.getBool(_autoHandPrefKey) ?? false,
        autoTurnOrderEnabled: prefs.getBool(_autoTurnOrderPrefKey) ?? false,
        autoDuelEnabled: prefs.getBool(_autoDuelPrefKey) ?? false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '读取自动操作设置失败: $e');
    }
  }

  /// 设置自动猜拳开关。
  ///
  /// 返回是否被接受：已准备时禁止变更（返回 false），
  /// 页面据此决定是否播放提示音，避免被拒绝的操作也响音。
  Future<bool> setAutoHandEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoHandEnabled) {
      return false;
    }
    state = state.copyWith(autoHandEnabled: value);
    await _persistAutoPref(_autoHandPrefKey, value);
    return true;
  }

  /// 设置自动随机先后手开关。语义同 [setAutoHandEnabled]。
  Future<bool> setAutoTurnOrderEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoTurnOrderEnabled) {
      return false;
    }
    state = state.copyWith(autoTurnOrderEnabled: value);
    await _persistAutoPref(_autoTurnOrderPrefKey, value);
    return true;
  }

  /// 设置自动加入决斗开关。语义同 [setAutoHandEnabled]。
  Future<bool> setAutoDuelEnabled(bool value) async {
    if (state.isSelfReady && value != state.autoDuelEnabled) {
      return false;
    }
    state = state.copyWith(autoDuelEnabled: value);
    await _persistAutoPref(_autoDuelPrefKey, value);
    return true;
  }

  /// 持久化自动操作开关；失败走 errorMessage 渠道，不抛未处理异常。
  Future<void> _persistAutoPref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      await prefs.setBool(key, value);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '保存自动操作设置失败: $e');
    }
  }

  void sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    // 手动出拳后取消自动出拳定时器，避免重复出拳。
    _autoHandTimer?.cancel();
    _autoHandTimer = null;
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
    try {
      final decks = await _dataService.loadDeckList();
      if (_disposed) return;
      console.log(
        'Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}',
      );
      state = state.copyWith(
        availableDecks: decks,
        selectedDeckName:
            state.selectedDeckName ??
            (decks.isEmpty ? null : decks.first.deckName),
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '卡组列表加载失败: $e');
    }
  }

  /// 选择指定卡组并执行禁限卡表校验。
  ///
  /// 返回 `(deck: 加载结果, error: 失败原因)`：
  /// - 成功时 deck 非空、error 为 null；
  /// - 校验失败/卡组为空/加载失败时 deck 为 null、error 为真实原因，
  ///   供 [toggleReady] 等调用方直接展示（不再吞成「卡组为空或加载失败」）。
  ///
  /// 每个 await 之后都检查 [_disposed]，避免房间 scope 销毁后继续写 state。
  Future<({ResolvedDeck? deck, String? error})> selectDeck(
    String? deckName,
  ) async {
    if (deckName == null) {
      return (deck: null, error: '未选择卡组');
    }
    state = state.copyWith(selectedDeckName: deckName);
    DeckInfo? deckInfo;
    try {
      deckInfo = await _dataService.loadDeck(deckName);
    } catch (e) {
      return (deck: null, error: '卡组加载失败: $e');
    }
    if (_disposed) return (deck: null, error: null);
    console.log('loadDeck: $deckName -> $deckInfo');
    if (deckInfo == null || deckInfo.mainDeck.isEmpty) {
      return (deck: null, error: '卡组为空或不存在');
    }
    final main = await _resolveCards(deckInfo.mainDeck);
    if (_disposed) return (deck: null, error: null);
    final extra = await _resolveCards(deckInfo.extraDeck);
    if (_disposed) return (deck: null, error: null);
    final side = await _resolveCards(deckInfo.sideDeck);
    if (_disposed) return (deck: null, error: null);

    // ── 禁限卡表校验 ──
    final result = await _validateDeckLegality(main, extra, side);
    if (_disposed) return (deck: null, error: null);
    state = state.copyWith(invalidationDeckResult: result);
    if (result != null && result.isNotEmpty) {
      return (deck: null, error: '卡组不合规: ${result.first}');
    }
    return (deck: (main: main, extra: extra, side: side), error: null);
  }

  /// 对任意卡组构成执行与 [selectDeck] 相同的禁限卡表校验。
  ///
  /// 返回违规项列表；空列表 = 通过；null = 未校验（房间未开启卡组检查、
  /// 禁限表不可用或加载失败），此时由服务器在提交卡组时兜底校验。
  ///
  /// 换备确认（[confirmSiding]）复用本方法：换备只交换卡位，
  /// 不改变全卡池总量，合法性与提交时一致；此校验兜底禁限表在局间
  /// 变化等极端情况。
  Future<List<String>?> _validateDeckLegality(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) async {
    final options = state.roomOptions;
    if (options == null || options.noCheckDeck) return null;
    try {
      final lfTable = await _dataService.getLfTable(options.lfTableHash);
      if (lfTable == null) return null;
      final validator = DeckValidator(lfInfos: lfTable.lfInfos);
      return validator.validate(main, extra, side);
    } catch (e) {
      // 禁限卡表未加载/加载失败时无法本地校验：跳过本地校验，
      // 由服务器在提交卡组时兜底校验。
      console.log('Deck validation skipped (banlist unavailable): $e');
      return null;
    }
  }

  Future<void> refreshSelectedDeckValidation() async {
    await loadDecks();
    await selectDeck(state.selectedDeckName);
  }

  /// 准备按钮入口：未准备时提交卡组并 ready，已准备时取消 ready。
  ///
  /// 返回 null 表示已正常提交/取消；返回非空字符串表示校验失败原因，
  /// 由调用方（页面）负责展示。
  ///
  /// 每次都重新走 [selectDeck] 校验（不再提前拦截上一次的
  /// invalidationDeckResult）：玩家在编辑器修复卡组后旧的失败结果
  /// 不应继续阻止准备，而新的校验失败会报告真实原因。
  Future<String?> toggleReady() async {
    if (state.isSelfReady) {
      _duelService.unready();
      return null;
    }
    final selection = await selectDeck(state.selectedDeckName);
    if (_disposed) return null;
    if (selection.error != null) {
      return selection.error;
    }
    final deck = selection.deck;
    if (deck == null || deck.main.isEmpty) {
      return '卡组为空或加载失败';
    }
    final mainCodes = deck.main.map((c) => c.code).toList();
    final extraCodes = deck.extra.map((c) => c.code).toList();
    final sideCodes = deck.side.map((c) => c.code).toList();
    final mainBytes = deckToBytes(mainCodes);
    final extraBytes = deckToBytes(extraCodes);
    final sideBytes = deckToBytes(sideCodes);
    ref
        .read(duelFieldProvider.notifier)
        .setKnownSelfExtraDeckCodes(extraCodes);
    // match 模式下副卡组随首次提交一并上送，作为局间换备的卡池。
    _duelService.submitDeck(mainBytes, extraBytes, sideBytes);
    // 记录提交的卡组构成：match 模式换备的数量基准。
    state = state.copyWith(
      submittedDeck: (main: mainCodes, extra: extraCodes, side: sideCodes),
    );
    _duelService.ready();
    return null;
  }

  void setError(int type, int code) {
    state = state.copyWith(errorMessage: _errorMessage(type, code));
  }

  /// 直接设置错误文案（连接失败等非服务器错误），
  /// 与服务器错误共用 errorMessage 渠道，由页面 SnackBar 展示。
  void setErrorText(String message) {
    state = state.copyWith(errorMessage: message);
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
      // 离开换备阶段时清理换备编辑状态（进入由下方 case 初始化）。
      if (roomStage is! RoomSideDecking &&
          (state.sidingDeck != null || state.sidingBaseline != null)) {
        next = next.copyWith(sidingDeck: null, sidingBaseline: null);
      }
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
            // 定时器由 _autoHandTimer 持有：手动出拳（sendHand）与
            // scope 销毁时都会取消，避免过期回调重复出拳。
            _autoHandTimer?.cancel();
            _autoHandTimer = Timer(const Duration(milliseconds: 700), () {
              _autoHandTimer = null;
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
        case RoomSideDecking():
          // match 模式局间换备：初始化换备编辑状态（异步解析卡信息）。
          unawaited(_enterSideDecking());
          break;
        default:
          break;
      }
      state = next;
    });
  }

  // ─── 换备（match 模式局间换 Side Deck）───────────────

  /// 进入换备阶段：初始化换备编辑状态。
  ///
  /// 优先以最近一次提交的卡组构成（[DuelRoomState.submittedDeck]）为基准；
  /// 没有提交记录时回退到当前所选卡组的构成（走 [selectDeck]，
  /// 含同一套禁限校验）。解析完成后才写入 state，期间 UI 显示加载态。
  Future<void> _enterSideDecking() async {
    ResolvedDeck? comp;
    final submitted = state.submittedDeck;
    if (submitted != null) {
      comp = await _resolveDeckCodes(
        submitted.main,
        submitted.extra,
        submitted.side,
      );
    } else {
      final selection = await selectDeck(state.selectedDeckName);
      comp = selection.deck;
    }
    if (_disposed) return;
    // 阶段可能已前进（如服务器快速下发下一局 DUEL_START），
    // 仅在仍处于换备阶段时写入。
    if (state.stage is! RoomSideDecking) return;
    if (comp == null) {
      state = state.copyWith(errorMessage: '换备数据初始化失败');
      return;
    }
    final baseline = (
      main: [...comp.main],
      extra: [...comp.extra],
      side: [...comp.side],
    );
    state = state.copyWith(
      sidingDeck: (
        main: [...comp.main],
        extra: [...comp.extra],
        side: [...comp.side],
      ),
      sidingBaseline: baseline,
    );
  }

  /// 将换备基准的卡码列表解析为卡信息（复用 dataService 的卡片缓存）。
  ///
  /// 无法解析的卡码用占位卡信息兜底，保证换备 UI 仍可编辑与回移。
  Future<ResolvedDeck> _resolveDeckCodes(
    List<int> main,
    List<int> extra,
    List<int> side,
  ) async {
    return (
      main: await _resolveCodeList(main),
      extra: await _resolveCodeList(extra),
      side: await _resolveCodeList(side),
    );
  }

  Future<List<CardInfo>> _resolveCodeList(List<int> codes) async {
    final result = <CardInfo>[];
    for (final code in codes) {
      CardInfo? card;
      try {
        card = await _dataService.getCard(code);
      } catch (e) {
        console.log('Failed to resolve card $code for siding: $e');
      }
      if (_disposed) return result;
      result.add(card ?? CardInfo(code: code, type: 0, name: '卡片 $code'));
    }
    return result;
  }

  /// 换备：把 [from] 分区下标 [index] 处的卡移动到 [to] 分区。
  ///
  /// 只允许 主卡组↔副卡组、额外卡组↔副卡组；主卡组↔额外卡组非法
  /// （YGOPro 换备规则）。返回是否执行了移动：
  /// 分区对非法、下标越界、不在换备阶段或换备数据未就绪时为 false。
  bool moveSidingCard(SidingZone from, SidingZone to, int index) {
    if (state.stage is! RoomSideDecking) return false;
    final siding = state.sidingDeck;
    if (siding == null || from == to) return false;
    final isMainExtraSwap =
        (from == SidingZone.main && to == SidingZone.extra) ||
        (from == SidingZone.extra && to == SidingZone.main);
    if (isMainExtraSwap) return false;
    final fromList = switch (from) {
      SidingZone.main => siding.main,
      SidingZone.extra => siding.extra,
      SidingZone.side => siding.side,
    };
    if (index < 0 || index >= fromList.length) return false;
    final card = fromList[index];
    final main = [...siding.main];
    final extra = [...siding.extra];
    final side = [...siding.side];
    switch (from) {
      case SidingZone.main:
        main.removeAt(index);
      case SidingZone.extra:
        extra.removeAt(index);
      case SidingZone.side:
        side.removeAt(index);
    }
    switch (to) {
      case SidingZone.main:
        main.add(card);
      case SidingZone.extra:
        extra.add(card);
      case SidingZone.side:
        side.add(card);
    }
    state = state.copyWith(sidingDeck: (main: main, extra: extra, side: side));
    return true;
  }

  /// 换备：放弃当前编辑，恢复为基准构成。
  void resetSiding() {
    if (state.stage is! RoomSideDecking) return;
    final baseline = state.sidingBaseline;
    if (baseline == null) return;
    state = state.copyWith(
      sidingDeck: (
        main: [...baseline.main],
        extra: [...baseline.extra],
        side: [...baseline.side],
      ),
    );
  }

  /// 换备确认：提交换备后的卡组并 ready。
  ///
  /// 前置条件：处于换备阶段、换备数据已就绪、各分区数量与基准一致；
  /// 数量一致时再执行与 [selectDeck] 相同的禁限卡表校验。
  /// 返回 null 表示已提交；返回非空字符串为失败原因（页面负责展示）。
  ///
  /// 提交成功后新构成替换 [DuelRoomState.submittedDeck]，
  /// 成为下一局换备的数量基准。
  Future<String?> confirmSiding() async {
    if (state.stage is! RoomSideDecking) return '当前不在换备阶段';
    final siding = state.sidingDeck;
    final baseline = state.sidingBaseline;
    if (siding == null || baseline == null) return '换备数据尚未就绪';
    if (siding.main.length != baseline.main.length ||
        siding.extra.length != baseline.extra.length ||
        siding.side.length != baseline.side.length) {
      return '卡组数量与基准不一致，无法提交';
    }
    final legality = await _validateDeckLegality(
      siding.main,
      siding.extra,
      siding.side,
    );
    if (_disposed) return null;
    if (legality != null && legality.isNotEmpty) {
      return '卡组不合规: ${legality.first}';
    }
    final mainCodes = siding.main.map((c) => c.code).toList();
    final extraCodes = siding.extra.map((c) => c.code).toList();
    final sideCodes = siding.side.map((c) => c.code).toList();
    ref
        .read(duelFieldProvider.notifier)
        .setKnownSelfExtraDeckCodes(extraCodes);
    _duelService.submitDeck(
      deckToBytes(mainCodes),
      deckToBytes(extraCodes),
      deckToBytes(sideCodes),
    );
    _duelService.ready();
    // 新构成成为下一次换备的基准。
    state = state.copyWith(
      submittedDeck: (main: mainCodes, extra: extraCodes, side: sideCodes),
      sidingBaseline: (
        main: [...siding.main],
        extra: [...siding.extra],
        side: [...siding.side],
      ),
    );
    return null;
  }

  /// 按 lfTableHash 缓存的禁限表 Future，避免每次 build 重建 future
  /// 导致 FutureBuilder 反复重跑。
  final Map<int, Future<LfTable?>> _lfTableFutures = {};

  /// 获取禁限卡表。
  ///
  /// 以 [hash] 为 key 做记忆化：页面每次 build 都拿同一个 future，
  /// FutureBuilder 不会反复重跑。禁限表未加载时底层会抛异常，
  /// 该错误被保留在 future 中，由 UI 依 `snapshot.hasError`
  /// 显示「加载失败」而不是误导性的「不限制」。
  Future<LfTable?> getLfTable(int hash) {
    return _lfTableFutures.putIfAbsent(
      hash,
      () => _dataService.getLfTable(hash),
    );
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
