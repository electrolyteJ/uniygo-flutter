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
}

final duelRoomProvider =
    NotifierProvider<DuelRoomNotifier, DuelRoomState>(DuelRoomNotifier.new);

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
        selectedDeckName: state.selectedDeckName ??
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
    final options = state.roomOptions;
    if (options?.noCheckDeck == false) {
      final lflistHash = options!.lfTableHash;
      List<String>? result;
      try {
        final lfTable = await _dataService.getLfTable(lflistHash);
        if (lfTable != null) {
          final validator = DeckValidator(lfInfos: lfTable.lfInfos);
          result = validator.validate(main, extra, side);
        }
      } catch (e) {
        // 禁限卡表未加载/加载失败时无法本地校验：跳过本地校验，
        // 由服务器在提交卡组时兜底校验。
        console.log('Deck validation skipped (banlist unavailable): $e');
        result = null;
      }
      if (_disposed) return (deck: null, error: null);
      state = state.copyWith(invalidationDeckResult: result);
      if (result != null && result.isNotEmpty) {
        return (deck: null, error: '卡组不合规: ${result.first}');
      }
    } else {
      state = state.copyWith(invalidationDeckResult: null);
    }
    return (deck: (main: main, extra: extra, side: side), error: null);
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
    final mainBytes = deckToBytes(deck.main.map((c) => c.code).toList());
    final extraBytes = deckToBytes(deck.extra.map((c) => c.code).toList());
    ref
        .read(duelFieldProvider.notifier)
        .setKnownSelfExtraDeckCodes(deck.extra.map((c) => c.code).toList());
    _duelService.submitDeck(mainBytes, extraBytes);
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
        default:
          break;
      }
      state = next;
    });
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
