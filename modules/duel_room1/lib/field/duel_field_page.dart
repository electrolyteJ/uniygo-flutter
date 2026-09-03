import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:biz/duel/models/draw_animation_event.dart';
import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:biz/duel/models/playmat_resolved_action.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room1/field/widgets/confirm/duel_confirm_dialog.dart';
import 'package:duel_room1/field/widgets/selector/duel_select_prompt.dart';
import 'package:duelink/duelink.dart' show PlayerInfo, PlayerType, RoomInDuel;
import 'package:flame/game.dart';
import 'package:resource_data/card_info.dart' as pkg;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duel_room1/field/duel_field_game.dart';
import 'package:duel_room1/field/util/chain_order_map.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/components/phase_rail/phase_rail_layout.dart';
import 'package:duel_room1/field/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room1/field/widgets/inspector/zone_browser_panel.dart';
import 'package:duel_room1/field/widgets/menus/duel_field_popover_layout.dart';
import 'package:duel_room1/field/widgets/menus/field_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_menu.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/phase_action_menu.dart';
import 'package:duel_room1/field/widgets/turn_order_hint.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';
import 'package:duel_room1/duel_room_exit.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

import 'components/hand_card/hand.dart';

/// 决斗场地页：负责 biz/duel Provider 接线、Flame 游戏生命周期与整体布局。
///
/// Riverpod 版（对照 duel_room2 的 field/duel_field_page.dart）：
/// - 状态读取从 `context.watch<DuelFieldStore>()` 改为直连 watch 四个子状态
///   provider（duelField / selectWindow / cardConfirm / fieldOverlay），
///   任一变更即重建，语义等价原 ChangeNotifier 的全量 notifyListeners；
///   写单状态直连对应 Notifier；服务器消息由 DuelMessageRouter 分发，
///   跨状态的本地交互与菜单派生逻辑直接内联在本页；
/// - 先后攻提示从手动 addListener 兜底改为 `ref.listen(isFirstTurn)`；
/// - 与 duel_room2 的差异：场地用自绘 Flame 渲染（room1 的存在意义）。
///   widget 层经 listenManual 订阅 duelField/selectWindow 后把
///   [FlameFieldSnapshot] 推入 [DuelFieldGame]（不走 build 副作用），
///   Flame component 不直接 watch，渲染循环与 Riverpod 解耦；
///   Flame 侧槽位组件布局期一次建好，快照变化只原地更新内容。
///
/// 选择/检视/菜单等交互状态由四个子状态持有；弹层几何计算见
/// duel_field_popover_layout.dart。
class DuelFieldPage extends ConsumerStatefulWidget {
  final List<PlayerInfo> players;

  /// 是否展示对局 HUD（顶栏/手牌/日志抽屉/选择弹层等）。
  ///
  /// 场地页自进房起常驻挂载作为全屏背景（见 duel_room_page.dart）；
  /// 非对局阶段传 false，仅渲染 Flame 场地、隐藏全部 HUD
  /// （对齐 godot：duel_ui 决斗开始才显示）。
  final bool isInDuel;

  const DuelFieldPage(this.players, {super.key, this.isInDuel = true});

  @override
  ConsumerState<DuelFieldPage> createState() => _DuelFieldPageState();
}

enum DuelPrimaryPanel { none, zone, confirm, inspector }

class CompactDuelTopHud extends StatelessWidget {
  const CompactDuelTopHud({
    super.key,
    required this.status,
    required this.timer,
  });

  final Widget status;
  final Widget timer;

  @override
  Widget build(BuildContext context) {
    final hs = DuelRoomLayout.of(context).hudScale;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.fromLTRB(12 * hs, 8 * hs, 12 * hs, 0),
        child: Row(
          children: [
            Flexible(child: status),
            Expanded(child: Center(child: timer)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

DuelPrimaryPanel selectDuelPrimaryPanel({
  required bool isCompact,
  required bool hasInspector,
  required bool hasConfirmPanel,
  required bool hasZoneBrowser,
}) {
  if (!isCompact) return DuelPrimaryPanel.none;
  if (hasInspector) return DuelPrimaryPanel.inspector;
  if (hasConfirmPanel) return DuelPrimaryPanel.confirm;
  if (hasZoneBrowser) return DuelPrimaryPanel.zone;
  return DuelPrimaryPanel.none;
}

class DuelPrimaryPanelHost extends StatelessWidget {
  const DuelPrimaryPanelHost({
    super.key,
    required this.selectedPanel,
    required this.zoneBuilder,
    required this.confirmBuilder,
    required this.inspectorBuilder,
  });

  final DuelPrimaryPanel selectedPanel;
  final WidgetBuilder zoneBuilder;
  final Widget Function(BuildContext context, bool showPanel) confirmBuilder;
  final WidgetBuilder inspectorBuilder;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          if (selectedPanel == DuelPrimaryPanel.none ||
              selectedPanel == DuelPrimaryPanel.zone)
            zoneBuilder(context),
          confirmBuilder(
            context,
            selectedPanel != DuelPrimaryPanel.inspector &&
                selectedPanel != DuelPrimaryPanel.zone,
          ),
          if (selectedPanel == DuelPrimaryPanel.none ||
              selectedPanel == DuelPrimaryPanel.inspector)
            inspectorBuilder(context),
        ],
      ),
    );
  }
}

class _DuelFieldPageState extends ConsumerState<DuelFieldPage> {
  static const double _opponentHandGap = 10.0;
  DuelRoomLayoutSpec? _layoutSpec;

  DuelRoomLayoutSpec get _layout => _layoutSpec ?? DuelRoomLayout.of(context);

  bool get _compactHud => _layout.isCompact;

  /// 对方手牌栏顶边距（屏幕坐标）：状态栏 + 顶栏 + 间隙，随 HUD 缩放。
  double _oppHandTopY(DuelRoomLayoutSpec spec) =>
      spec.safePadding.top +
      spec.topHudHeight +
      _opponentHandGap * spec.hudScale;

  DuelFieldGame? _flameGame;
  PlaymatAnchorData? _fieldAnchors;

  // 抽卡动画：双方各一条 FIFO 队列（biz 纯逻辑）+ Flame 飞行组件。
  // 双方并行播放：开局发牌是我方/对方两条 MSG_DRAW，同时起飞才符合
  // 真实发牌手感（ygopro/MD 均为双方同时）；同一方的连续抽卡
  // （如天使的施舍）仍严格串行——同一手牌栏的隐藏/揭示下标不能交错。
  final DrawAnimationQueue _drawQueueSelf = DrawAnimationQueue();
  final DrawAnimationQueue _drawQueueOpp = DrawAnimationQueue();

  /// 各侧是否有抽卡飞行动画正在播放（防止同侧并行播放两段动画）。
  bool _drawPlayingSelf = false;
  bool _drawPlayingOpp = false;

  /// 事件 id → 入队时预隐藏的手牌下标（见 game.concealDrawTargets）。
  ///
  /// 隐藏必须发生在入队时（含排队事件）：否则连续抽卡（开局双方各
  /// 抽 5 张是两条 MSG_DRAW）时，排队事件的手牌会先亮出来，
  /// 等播到它时动画再叠着飞一遍。
  final Map<int, List<int>> _concealedDrawTargets = {};

  /// 事件归属侧的队列（己方/对方）。
  DrawAnimationQueue _drawQueueOf(DrawAnimationEvent event) =>
      event.player == _board.myController ? _drawQueueSelf : _drawQueueOpp;

  /// 双方各自的洗牌 tick（单调递增）：handShuffleTick 是全局共享序号，
  /// 直接透传给两侧手牌栏会在"对方洗牌→己方洗牌"时把 0 值变化误判成
  /// 新的洗牌事件，这里按 player 拆成每侧独立的单调 tick。
  int _selfHandShuffleTick = 0;
  int _oppHandShuffleTick = 0;

  // 快照推送订阅：只有场地/选择窗口状态变化才推入 Flame，
  // 替代原先 build 路径上的 applySnapshot 副作用。
  ProviderSubscription<DuelFieldState>? _boardSub;
  ProviderSubscription<SelectWindowState>? _selectSub;
  ProviderSubscription<CardConfirmState>? _confirmSub;
  ProviderSubscription<FieldOverlayState>? _overlaySub;

  // 先后攻提示：进入场地页时居中短暂展示一次。
  bool _showTurnOrderHint = false;
  bool _isFirstTurn = false;

  // 四个子状态 + 跨状态控制器的便捷访问；读取经 ref.read，
  // 重建由 build 里的四个 ref.watch 驱动。
  DuelFieldState get _board => ref.read(duelFieldProvider);

  SelectWindowState get _select => ref.read(selectWindowProvider);

  FieldOverlayState get _overlay => ref.read(fieldOverlayProvider);

  CardConfirmState get _confirm => ref.read(cardConfirmProvider);

  DuelFieldNotifier get _boardN => ref.read(duelFieldProvider.notifier);

  SelectWindowNotifier get _selectN => ref.read(selectWindowProvider.notifier);

  FieldOverlayNotifier get _overlayN => ref.read(fieldOverlayProvider.notifier);

  YgoSoundService get _sound => ref.read(ygoSoundServiceProvider);

  @override
  void initState() {
    super.initState();
    _scheduleTurnOrderHint();
    _boardSub = ref.listenManual(duelFieldProvider, (_, _) => _pushSnapshot());
    _selectSub = ref.listenManual(
      selectWindowProvider,
      (_, _) => _pushSnapshot(),
    );
    // 手牌已 Flame 化：选中/高亮/确认等交互态也在快照里，
    // 这两个 provider 的变化同样要推快照。
    _confirmSub = ref.listenManual(
      cardConfirmProvider,
      (_, _) => _pushSnapshot(),
    );
    _overlaySub = ref.listenManual(
      fieldOverlayProvider,
      (_, _) => _pushSnapshot(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final spec = DuelRoomLayout.of(context);
    if (_layoutSpec == spec) return;
    _layoutSpec = spec;
    _flameGame
      ?..setLayoutSpec(spec)
      ..setOppHandTopY(_oppHandTopY(spec));
  }

  @override
  void dispose() {
    // 显式清空队列：dispose 后状态监听不再触发，残留事件不应滞留。
    _drawQueueSelf.clear();
    _drawQueueOpp.clear();
    _boardSub?.close();
    _selectSub?.close();
    _confirmSub?.close();
    _overlaySub?.close();
    super.dispose();
  }

  /// 启动 [isSelf] 侧队列当前 active 事件的 Flame 飞行动画。
  /// 双方队列互不阻塞（并行发牌）；同侧严格串行。
  /// HUD 不可见时不播放：猜拳结果最短停留期间 MSG_DRAW 已按服务器
  /// 速度到达，若此时开播动画会在手牌栏隐藏下白白播完（开局发牌
  /// 玩家完全看不到）；事件留在队列里等 HUD 可见后由 didUpdateWidget 补播。
  void _playActiveDrawFlight(bool isSelf) {
    if (!mounted || !widget.isInDuel) return;
    final queue = isSelf ? _drawQueueSelf : _drawQueueOpp;
    if (isSelf ? _drawPlayingSelf : _drawPlayingOpp) return;
    final active = queue.active;
    if (active == null) return;
    final game = _flameGame;
    if (game == null) {
      // 游戏尚未创建（理论上不会：场地页常驻挂载），丢弃本侧待发动画
      // 防卡死。必须用 clear 而非 drain：drain 会把下一个排队事件提为
      // active 却无人播放，后续 submit 全部堵在它后面；对应的藏牌
      // 记录一并清掉，避免泄漏。
      _concealedDrawTargets.remove(active.id);
      queue.clear();
      return;
    }
    if (isSelf) {
      _drawPlayingSelf = true;
    } else {
      _drawPlayingOpp = true;
    }
    final indices = _concealedDrawTargets.remove(active.id) ?? const [];
    game.playDrawFlight(active, indices, () {
      if (isSelf) {
        _drawPlayingSelf = false;
      } else {
        _drawPlayingOpp = false;
      }
      if (!mounted) return;
      // 当前动画播完：取出本侧队列里的下一个事件继续播放。
      if (queue.drain() != null) {
        _playActiveDrawFlight(isSelf);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DuelFieldPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isInDuel == widget.isInDuel) return;
    // 手牌栏可见性跟随 HUD（猜拳/等待阶段场地页仅作背景）。
    _flameGame?.setHandBarsVisible(widget.isInDuel);
    // HUD 由隐藏转为可见（如猜拳结果最短停留结束进入对局）时，
    // 补播停留期间排队但未能播放的抽卡/发牌动画（双方各自补播）。
    if (widget.isInDuel) {
      _playActiveDrawFlight(true);
      _playActiveDrawFlight(false);
    }
  }

  /// 把最新快照推入 Flame 游戏（订阅回调与首帧初始化共用）。
  /// world 未加载完成时 applySnapshot 只替换快照引用，安全。
  void _pushSnapshot() {
    _flameGame?.applySnapshot(_buildFlameSnapshot());
  }

  /// 进入场地页后读取先后攻信息，居中弹出一次提示。
  /// 观战者不提示；信息尚未到达时由 build 中的 `ref.listen(isFirstTurn)`
  /// 在值到达后兜底触发（替代旧版的手动 addListener）。
  void _scheduleTurnOrderHint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final room = ref.read(duelRoomProvider);
      if (room.selfType == PlayerType.observer) return;
      final isFirst = room.isFirstTurn;
      if (isFirst != null) {
        _revealTurnOrderHint(isFirst);
      }
    });
  }

  void _revealTurnOrderHint(bool isFirst) {
    if (!mounted || _showTurnOrderHint) return;
    _isFirstTurn = isFirst;
    ref.read(ygoSoundServiceProvider).playTurnHint();
    setState(() => _showTurnOrderHint = true);
  }

  // ---- Flame 场地 ----

  /// PhaseLamp 可点击的完整条件：
  /// 1. 当前是己方回合（对方回合不能点）
  /// 2. 当前窗口下有可用阶段动作
  ///
  /// 用 ref.read 而非 ref.watch：本方法也会被 Flame 侧的
  /// isPhaseLampEnabled 回调（build 之外）调用。
  bool _canTapPhaseLamp() =>
      _board.currentPlayer == _board.myController &&
      ref.read(phaseActionsProvider).isNotEmpty;

  /// 投降按钮（阶段轨道顶端）可用性：对局进行中且非观战。
  /// 用 ref.read：会被 Flame 侧 isSurrenderEnabled 回调在 build 外调用。
  bool _canSurrender() =>
      _board.duelResult == null &&
      ref.read(duelRoomProvider).selfType.isDuelist;

  /// 投降按钮点击：确认弹窗 → surrender()；不导航，结算由 MSG_WIN 接管。
  void _handleSurrenderTap() {
    if (!_canSurrender()) return;
    showSurrenderConfirmDialog(context: context, ref: ref);
  }

  DuelFieldGame _ensureFlameGame() {
    final existing = _flameGame;
    if (existing != null) return existing;
    final game = DuelFieldGame(
      onCardSelect: handleFieldCardTap,
      onZoneInspect: handleZoneInspect,
      onPhaseLampTap: togglePhaseMenu,
      isPhaseLampEnabled: _canTapPhaseLamp,
      onSurrenderTap: _handleSurrenderTap,
      isSurrenderEnabled: _canSurrender,
      onPlaceSlotTap: (key) => _selectN.respondSelectPlaceKey(key),
      onHandCardTap: handleHandCardTap,
      onHandCardSecondaryTap: handleHandCardSecondaryTap,
      onFieldCardSecondaryTap: handleFieldCardSecondaryTap,
      contextMenuEnabled: PlatformAdaptive.of(context).supportsContextMenu,
      onAnchorsChanged: _handleAnchorsChanged,
    );
    _flameGame = game;
    // 手牌栏可见性与对方栏顶边距随页面状态初始化（后续变化分别由
    // didUpdateWidget 与 build 推送）。
    game.setFieldVisible(widget.isInDuel);
    game.setHandBarsVisible(widget.isInDuel);
    final spec = _layout;
    game.setLayoutSpec(spec);
    game.setOppHandTopY(_oppHandTopY(spec));
    // 初始快照推迟到首帧后推入（此时 Provider 已可读；
    // 后续变化由 listenManual 订阅驱动，不走 build）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pushSnapshot();
    });
    return game;
  }

  void _handleAnchorsChanged(PlaymatAnchorData anchors) {
    if (!mounted || _fieldAnchors?.signature == anchors.signature) {
      return;
    }
    _fieldAnchors = anchors;
    // Defer setState to post-frame: onGameResize may fire during Flame's
    // LayoutBuilder build, and calling setState during build is forbidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // ---- 视图数据与锚点 ----

  /// 从 biz/duel Provider 组装推入 Flame 的状态快照。
  FlameFieldSnapshot _buildFlameSnapshot() {
    return FlameFieldSnapshot(
      fieldCards: Map<String, FieldCard>.from(_board.fieldCards),
      myController: _board.myController,
      phase: _board.phase,
      inDamageStep: _board.inDamageStep,
      battlePresentation: _board.battlePresentation,
      selfDeckShuffleTick: _board.selfDeckShuffleTick,
      oppDeckShuffleTick: _board.oppDeckShuffleTick,
      selfExtraShuffleTick: _board.selfExtraShuffleTick,
      oppExtraShuffleTick: _board.oppExtraShuffleTick,
      summonEffectTick: _board.summonEffectTick,
      summonEffectEvent: _board.summonEffectEvent,
      cardMoveTick: _board.cardMoveTick,
      cardMoveEvent: _board.cardMoveEvent,
      selfDeck: _board.selfDeck,
      oppDeck: _board.oppDeck,
      zoneCodes: {
        for (final key in const [
          'self_grave',
          'opp_grave',
          'self_extra',
          'opp_extra',
          'self_removed',
          'opp_removed',
        ])
          key: _board.getZoneCodes(key),
      },
      inlineSelectedFieldKeys: _selectN.inlineSelectedFieldKeys,
      inlineSelectableFieldKeys: _selectN.inlineSelectableFieldKeys,
      placeTargetFieldKeys: _select.placeTargetFieldKeys,
      activatableZoneKeys: ref.read(activatableZoneKeysProvider),
      chainOrderBySlotKey: buildChainOrderMaps(
        _board.chains,
        _board.myController,
      ).field,
      selfHand: _buildSelfHandSnapshot(),
      oppHand: _buildOppHandSnapshot(),
      // ── HUD 字段（回合徽章/中央计时/左侧状态卡；不参与快照判等）──
      turnCount: _board.turnCount,
      currentPlayer: _board.currentPlayer,
      selfTimeLeft: _board.selfTimeLeft,
      opponentTimeLeft: _board.opponentTimeLeft,
      selfLp: _board.selfLp,
      opponentLp: _board.opponentLp,
      selfExtra: _board.selfExtra,
      oppExtra: _board.oppExtra,
      selfGrave: _board.selfGrave,
      oppGrave: _board.oppGrave,
      selfRemoved: _board.selfRemoved,
      oppRemoved: _board.oppRemoved,
      selfName: _selfName,
      oppName: _oppName,
      lpChangeTick: _board.lpChangeTick,
      lpChangeEvent: _board.lpChangeEvent,
    );
  }

  /// 我方显示名：players 取局中最新（DuelFieldState.players），
  /// 未下发时退回 widget.players；tag 模式同队名字 " / " 连接。
  String get _selfName => teamDisplayName(
    _board.teamOfEnginePlayer(_board.myController),
    _effectivePlayers,
    fallback: '我方',
  );

  String get _oppName => teamDisplayName(
    _board.teamOfEnginePlayer(1 - _board.myController),
    _effectivePlayers,
    fallback: '对方',
  );

  List<PlayerInfo> get _effectivePlayers =>
      _board.players.isNotEmpty ? _board.players : widget.players;

  /// 己方手牌快照（底部手牌栏）。
  ///
  /// 高亮/勾选集合的来源与原 Flutter 版 HandCardsBar 挂载处一致：
  /// 手牌确认（MSG_CONFIRM_CARDS）优先，否则就地选择窗口的高亮/勾选。
  HandSnapshot _buildSelfHandSnapshot() {
    final confirm = _confirm;
    final isDuelist = ref.read(duelRoomProvider).selfType.isDuelist;
    final inlineActive = _selectN.selectPromptMode == SelectPromptMode.inline;
    final confirmedOnSelf =
        confirm.confirmedHandOwner == _board.myController &&
        confirm.confirmedHandSequences.isNotEmpty;
    return HandSnapshot(
      codes: _board.selfHand,
      // 观战者（非决斗位）不显示卡面：selfHand 的 0 占位码会渲染成卡背。
      faceUp: isDuelist,
      selectedIndex: _overlay.selectedHandSequence,
      highlightedIndices: confirmedOnSelf
          ? confirm.confirmedHandSequences
          : inlineActive
          ? _selectN.inlineSelectableHandSequences
          : const {},
      checkedIndices: inlineActive
          ? _selectN.inlineSelectedHandSequences
          : const {},
      chainOrderByIndex: buildChainOrderMaps(
        _board.chains,
        _board.myController,
      ).selfHand,
      shuffleTick: _selfHandShuffleTick,
    );
  }

  /// 对方手牌快照（顶部手牌栏；卡面恒为卡背）。
  HandSnapshot _buildOppHandSnapshot() {
    final confirm = _confirm;
    final confirmedOnOpp =
        confirm.confirmedHandOwner != _board.myController &&
        confirm.confirmedHandSequences.isNotEmpty;
    return HandSnapshot(
      codes: _board.opponentHand,
      faceUp: false,
      selectedIndex: null,
      highlightedIndices: confirmedOnOpp
          ? confirm.confirmedHandSequences
          : const {},
      checkedIndices: const {},
      chainOrderByIndex: buildChainOrderMaps(
        _board.chains,
        _board.myController,
      ).oppHand,
      shuffleTick: _oppHandShuffleTick,
    );
  }

  Rect _phaseLampRect(Size viewport) {
    final anchors = _fieldAnchors;
    if (anchors != null) {
      return anchors.phaseLampRect;
    }
    // anchors 未就绪时的兜底：右侧垂直阶段轨道（PhaseRailLayout）的
    // 近似位置——视口右缘外 6%、垂直居中。
    return Rect.fromCenter(
      center: Offset(viewport.width * 0.94, viewport.height * 0.5),
      width: PhaseRailLayout.pillWidth + 20,
      height: PhaseRailLayout.heightWithButton + 20,
    );
  }

  Rect? _fieldCardRect(Size viewport, FieldCard fieldCard) {
    final anchoredRect = _fieldAnchors?.slotRects[fieldSlotId(fieldCard)];
    if (anchoredRect != null) {
      return anchoredRect;
    }
    final fallback = fieldCardAnchor(
      viewport,
      fieldCard,
      _board.myController,
      safeRect: DuelRoomLayout.of(context).safeRect,
    );
    return Rect.fromCenter(
      center: fallback,
      width: DuelFieldLayout.slotWidth,
      height: DuelFieldLayout.slotHeight,
    );
  }

  /// 顶部 HUD：紧凑模式下仅承接中央计时（对方状态芯片已由 Flame 层
  /// PlayerStatusCardComponent 在对方手牌右侧常驻展示）。
  Widget _buildTopHud() {
    if (!_compactHud) return const SizedBox.shrink();
    return CompactDuelTopHud(
      status: const SizedBox.shrink(),
      timer: _buildCompactTimer(),
    );
  }

  /// 紧凑模式的中央计时（顶栏内）：当前回合方剩余时间 MM:SS，
  /// ≤30s 变红，否则金色（对齐 CenterTimerComponent 语义）。
  Widget _buildCompactTimer() {
    return Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(
          duelFieldProvider.select(
            (s) => (
              selfTime: s.selfTimeLeft,
              oppTime: s.opponentTimeLeft,
              current: s.currentPlayer,
              mine: s.myController,
              turn: s.turnCount,
            ),
          ),
        );
        final seconds = s.current == s.mine ? s.selfTime : s.oppTime;
        final active = s.turn > 0 && seconds > 0;
        final urgent = active && seconds <= 30;
        final color = !active
            ? const Color(0xFF8B9BB4)
            : urgent
            ? const Color(0xFFFF4D4D)
            : const Color(0xFFFFD700);
        final m = (seconds ~/ 60).toString().padLeft(2, '0');
        final sec = (seconds % 60).toString().padLeft(2, '0');
        return Text(
          active ? 'T${s.turn} · $m:$sec' : '--:--',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            letterSpacing: 1.0,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 先后攻提示：随 stage 进入 RoomInDuel 触发（isFirstTurn 与 stage 由
    // 服务器在同一帧状态里下发，见 DuelRoomNotifier）。场地页常驻挂载后
    // 不能再靠页面重建兜底；match 模式多局之间 isFirstTurn 可能同值、
    // select 不触发，故改监听 stage 变迁。
    ref.listen(duelRoomProvider.select((s) => s.stage), (prev, next) {
      if (next is! RoomInDuel || prev is RoomInDuel) return;
      final room = ref.read(duelRoomProvider);
      final isFirst = room.isFirstTurn;
      if (isFirst == null || room.selfType == PlayerType.observer) return;
      _revealTurnOrderHint(isFirst);
    });

    // 任一子状态变更都触发重建（等价原 ChangeNotifier 全量通知），
    // 读取经上方的 _board/_select/_confirm/_overlay getter。
    // 不再整页 watch 四子状态：各区域经 Consumer + select/派生 provider
    // 订阅自己的切片（HUD/手牌/日志/弹层各自独立重建）。
    if (ref.watch(needsHigherPriorityDismissProvider)) {
      // build 期间不能改状态，推迟到帧末让本地弹层让位。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlayN.clearLocalUi();
      });
    }
    // 抽卡事件（MSG_DRAW）：FIFO 队列播放 Flame 飞行动画。
    ref.listen(duelFieldProvider.select((s) => s.drawAnimationEvent), (
      prev,
      next,
    ) {
      if (next == null) {
        // 新对局开始（handleStart 清空事件）：丢弃未播完的动画与排队事件，
        // 避免上一局残留的抽卡动画飞进新局。
        _drawQueueSelf.clear();
        _drawQueueOpp.clear();
        _drawPlayingSelf = false;
        _drawPlayingOpp = false;
        _concealedDrawTargets.clear();
        _flameGame?.cancelDrawFlights();
        return;
      }
      final isSelf = next.player == _board.myController;
      switch (_drawQueueOf(next).submit(next)) {
        case DrawQueueSubmitResult.started:
          // 入队即隐藏目标卡位（含下一条排队分支），再开播。
          _concealedDrawTargets[next.id] =
              _flameGame?.concealDrawTargets(next) ?? const [];
          _playActiveDrawFlight(isSelf);
        case DrawQueueSubmitResult.enqueued:
          // 排队中的事件同样立即隐藏：手牌不得先于动画出现。
          _concealedDrawTargets[next.id] =
              _flameGame?.concealDrawTargets(next) ?? const [];
          break;
        case DrawQueueSubmitResult.patchedActive:
          // 同 id 更新命中播放中事件（MSG_CONFIRM_CARDS 后的 reveal 等）：
          // Flame 飞行卡的视觉在起飞时定型，中途不更新（与旧实现差异：
          // 不再重绘飞行中的卡面，落地后的手牌卡仍按最新快照渲染）。
          break;
        case DrawQueueSubmitResult.patchedQueued:
          // 排队中：等当前动画播完由 onDone 回调依序取出。
          break;
      }
    });
    // 洗手牌事件（MSG_SHUFFLE_HAND）：按 player 拆到每侧独立的单调 tick。
    ref.listen(duelFieldProvider.select((s) => s.handShuffleTick), (
      prev,
      next,
    ) {
      if (next == 0) return;
      final board = ref.read(duelFieldProvider);
      setState(() {
        if (board.handShufflePlayer == board.myController) {
          _selfHandShuffleTick = next;
        } else {
          _oppHandShuffleTick = next;
        }
      });
      // tick 随快照进 Flame：本监听（build 注册）晚于 initState 注册的
      // 快照订阅，boardSub 推送的仍是旧 tick，这里更新后补推一次。
      _pushSnapshot();
    });
    // 弹层几何（viewport/phaseRect/overlayAnchor 等）已随 HUD 层移至
    // _buildHudOverlay。
    // 页面自带 Portal：内部的 PortalTarget（阶段菜单/场上操作/手牌菜单）
    // 不再依赖宿主 App 提供全局 Portal；宿主已有 Portal 时嵌套安全。
    // 对方手牌栏顶边距推入 Flame（状态栏/顶部 HUD 高度决定其位置）；
    // 手牌栏可见性由 didUpdateWidget 与 _ensureFlameGame 推入。
    return Portal(
      child: Scaffold(
        backgroundColor: const Color(0xFF010308),
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: GameWidget(game: _ensureFlameGame())),
            // HUD 层仅对局进行中展示；非对局阶段本页作为半透明等待弹窗
            // 背后的场地背景常驻挂载（对齐 godot：duel_ui 决斗开始才显示）。
            if (widget.isInDuel) Positioned.fill(child: _buildHudOverlay()),
          ],
        ),
      ),
    );
  }

  /// 对局 HUD 叠层：顶栏/双方手牌/日志抽屉/选择弹层等全部覆盖件。
  /// 弹层几何与原 build 内联实现一致（统一经 Portal 的 Aligned 锚点避让）。
  Widget _buildHudOverlay() {
    // viewport 仅用于 anchors 缺失时的 fallback 比例估算；
    // 弹层定位与避让统一由 Portal 的 Aligned 锚点负责。
    final viewport = _layout.viewport;
    final hasFieldAnchors = _fieldAnchors != null;
    final phaseRect = _phaseLampRect(viewport);
    // 弹层统一通过 Portal 渲染：底边对齐锚点矩形顶部，
    // 由 flutter_portal 自动避让屏幕边界。
    final overlayAnchor = SafeAligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: const Offset(0, -8),
      safePadding: _layout.safePadding,
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final selectPlayer = ref.watch(
                  selectWindowProvider.select((s) => s.currentSelect?.player),
                );
                final mc = ref.watch(
                  duelFieldProvider.select((s) => s.myController),
                );
                return Text(
                  selectPlayer == mc ? '等待你的操作' : '等待对手操作',
                  style: const TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Orbitron',
                  ),
                );
              },
            ),
          ),
        ),

        Consumer(
          builder: (context, ref, _) {
            final show = ref.watch(
              fieldOverlayProvider.select((s) => s.showPhaseMenu),
            );
            final entries = ref.watch(phaseActionMenuProvider);
            if (!hasFieldAnchors || !show || entries.isEmpty) {
              return const SizedBox.shrink();
            }
            // 锚定到轨道末端的阶段菜单按钮，菜单在按钮左侧展开
            // （原来锚整条轨道上方：轨道加按钮后高 200+，菜单悬在
            // 屏幕右上方、离点击点远，观感突兀）。
            final buttonRect = _flameGame?.phaseActionButtonRect() ?? phaseRect;
            return Positioned.fromRect(
              rect: buttonRect,
              child: PortalTarget(
                visible: true,
                anchor: SafeAligned(
                  follower: Alignment.centerRight,
                  target: Alignment.centerLeft,
                  offset: const Offset(-8, 0),
                  safePadding: _layout.safePadding,
                ),
                portalFollower: PhaseActionMenu(actions: entries),
                child: const SizedBox.shrink(),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final card = ref.watch(
              fieldOverlayProvider.select((s) => s.selectedFieldCard),
            );
            final entries = ref.watch(fieldActionMenuProvider);
            final rect = card == null ? null : _fieldCardRect(viewport, card);
            if (rect == null) return const SizedBox.shrink();
            final menuWidth = menuWidthFor(_layout);
            return Positioned.fromRect(
              rect: rect,
              child: PortalTarget(
                visible: entries.isNotEmpty,
                anchor: overlayAnchor,
                portalFollower: FieldActionPopover(
                  actions: entries,
                  arrowDx: popoverArrowDx(
                    anchorRect: rect,
                    safeRect: _layout.safeRect,
                    menuWidth: menuWidth,
                  ),
                ),
                child: const SizedBox.shrink(),
              ),
            );
          },
        ),
        // 手牌操作菜单：手牌栏已 Flame 化，菜单仍是 Flutter Portal 弹层，
        // 锚定矩形从游戏侧拉式查询（替代原来的帧末矩形上报）。
        Consumer(
          builder: (context, ref, _) {
            final selectedSeq = ref.watch(
              fieldOverlayProvider.select((s) => s.selectedHandSequence),
            );
            final entries = ref.watch(handActionMenuProvider);
            if (selectedSeq == null || entries.isEmpty) {
              return const SizedBox.shrink();
            }
            final rect = _flameGame?.selectedHandCardRect();
            if (rect == null) return const SizedBox.shrink();
            final menuWidth = menuWidthFor(_layout);
            return Positioned.fromRect(
              rect: rect,
              child: PortalTarget(
                visible: true,
                anchor: overlayAnchor,
                portalFollower: HandActionPopover(
                  actions: entries,
                  arrowDx: popoverArrowDx(
                    anchorRect: rect,
                    safeRect: _layout.safeRect,
                    menuWidth: menuWidth,
                  ),
                ),
                child: const SizedBox.shrink(),
              ),
            );
          },
        ),
        _buildTopHud(),
        Consumer(
          builder: (context, ref, _) {
            final hasConfirmPanel = ref.watch(
              cardConfirmProvider.select((s) => s.confirmPanel != null),
            );
            final overlayPanels = ref.watch(
              fieldOverlayProvider.select(
                (s) => (
                  hasInspector: s.showInspector,
                  hasZoneBrowser: s.openZoneBrowserKey != null,
                  inspectorCode: s.inspectedCardCode,
                  inspectorInfo: s.inspectedCardInfo,
                ),
              ),
            );
            final selectedPanel = selectDuelPrimaryPanel(
              isCompact: _layout.isCompact,
              hasInspector: overlayPanels.hasInspector,
              hasConfirmPanel: hasConfirmPanel,
              hasZoneBrowser: overlayPanels.hasZoneBrowser,
            );
            return DuelPrimaryPanelHost(
              selectedPanel: selectedPanel,
              zoneBuilder: (context) => Consumer(
                builder: (context, ref, _) {
                  final key = ref.watch(
                    fieldOverlayProvider.select((s) => s.openZoneBrowserKey),
                  );
                  if (key == null) return const SizedBox.shrink();
                  final selectedSeq = ref.watch(
                    fieldOverlayProvider.select(
                      (s) => s.selectedZoneBrowserSequence,
                    ),
                  );
                  return ZoneBrowserPanel(
                    zoneBrowserKey: key,
                    cards: ref.watch(zoneBrowserEntriesProvider(key)),
                    selectedCardSequence: selectedSeq,
                    onCardTap: inspectZoneBrowserCard,
                    onClose: closeZoneBrowser,
                    selectedActions: ref.watch(zoneBrowserActionsProvider(key)),
                    activatableSequences: ref.watch(
                      zoneBrowserActivatableSequencesProvider(key),
                    ),
                    hiddenCount: ref.watch(zoneHiddenCountProvider(key)),
                    cardNameBuilder: (code) =>
                        _boardN.getCardInfo(code)?.name ?? 'Card #$code',
                  );
                },
              ),
              confirmBuilder: (context, showPanel) => DuelConfirmDialog(
                slotRectOf: (key) => _fieldAnchors?.slotRects[key],
                onInspectCard: inspectCard,
                onInspectPanelCard: inspectPanelCard,
                showConfirmPanel: showPanel,
              ),
              inspectorBuilder: (context) {
                if (!overlayPanels.hasInspector) {
                  return const SizedBox.shrink();
                }
                ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
                return _buildInspector((
                  show: true,
                  code: overlayPanels.inspectorCode,
                  info: overlayPanels.inspectorInfo,
                ));
              },
            );
          },
        ),
        // 选择提示弹层：模式判定、呈现与 respondXxx 分发
        // 全部收口在 DuelSelectPrompt。
        DuelSelectPrompt(onInspectCard: inspectCard),
        if (_showTurnOrderHint)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: TurnOrderHint(
                  isFirst: _isFirstTurn,
                  onDismiss: () {
                    if (mounted) {
                      setState(() => _showTurnOrderHint = false);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInspector(
    ({bool show, int? code, pkg.CardInfo? info}) inspector,
  ) {
    final inspectedCardCode = inspector.code;
    final inspectedCardInfo = inspectedCardCode == null
        ? inspector.info
        : _boardN.getCardInfo(inspectedCardCode) ?? inspector.info;
    // 紧凑模式（小屏）：抽屉贴着顶栏与手牌栏之间排布，
    // 桌面的 124/160 固定边距在矮视口会把抽屉压成一条缝。
    final spec = _layout;
    final rect = cardDetailDrawerRect(spec);
    return Positioned.fromRect(
      rect: rect,
      child: CardDetailDrawer(
        cardInfo: inspectedCardInfo,
        cardCode: inspectedCardCode,
        onClose: _overlayN.dismissInspector,
      ),
    );
  }

  // ---- 交互入口（对照 duel_room2 内联实现） ----

  /// 检视卡片：触发卡信息加载并打开详情抽屉。
  /// 主动加载避免非常规路径（连锁确认等）得知 code 的卡
  /// 一直停留在 Card #xxxx 占位。
  void _inspectCardMut(
    int? code, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code == null || code <= 0) return;
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyInspect(
      code,
      _boardN.getCardInfo(code),
      preserveHandSelection: preserveHandSelection,
      preserveZoneBrowser: preserveZoneBrowser,
    );
  }

  void inspectCard(int code) {
    if (code <= 0) return;
    _sound.playDialogOpen();
    _inspectCardMut(code);
  }

  void inspectPanelCard(int code) {
    if (code <= 0) return;
    _sound.playDialogOpen();
    _inspectCardMut(code, preserveZoneBrowser: true);
  }

  /// 就地选择模式下点击手牌：可选中则按当前选择语义处理，
  /// 否则仅检视卡片详情。
  void handleInlineHandCardTap(int sequence, int code) {
    final index = _selectN.inlineOptionIndexForHand(sequence);
    if (index == null) {
      _inspectCardMut(code, preserveHandSelection: true);
      return;
    }
    _applyInlineOptionTap(index, code);
  }

  /// 就地选择模式下点击场上卡：可选中则按当前选择语义处理，
  /// 否则仅检视卡片详情。
  void handleInlineFieldCardTap(FieldCard card) {
    final index = _selectN.inlineOptionIndexForField(card);
    if (index == null) {
      _inspectCardMut(card.code);
      return;
    }
    _applyInlineOptionTap(index, card.code);
  }

  void _applyInlineOptionTap(int index, int code) {
    final select = _select.currentSelect;
    if (select == null) return;
    _inspectCardMut(code);
    switch (select.type) {
      case SelectType.chain:
        // 连锁：点卡即发动，响应为选项下标（与 response 一一对应）。
        _selectN.respondSelectChain(index);
        return;
      case SelectType.unselect:
        // 解除选择：点卡即向服务端切换勾选状态。
        _selectN.respondSelectUnselectCard(index);
        return;
      default:
        break;
    }
    // 单选：点卡即提交；多选：本地勾选后由确认按钮提交。
    if (select.min == 1 && select.max == 1) {
      _selectN.respondInlineMulti([index]);
      return;
    }
    _selectN.toggleInlineOption(index);
  }

  // ---- 手牌 ----

  /// 手牌单击：选中该手牌并检视（清掉浏览器/场上选中与阶段菜单）。
  void handleHandCardTap(int sequence, int code) {
    // HUD 隐藏（猜拳/等待阶段场地页仅作背景）时不响应手牌点击：
    // HandBarComponent 靠 renderTree 早退隐藏，但 Flame 点击分发不
    // 随渲染关闭，隐形卡仍可被点中。
    if (!widget.isInDuel) return;
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (_selectN.inlineSelectActive) {
      handleInlineHandCardTap(sequence, code);
      return;
    }
    _showHandCardMenu(sequence, code);
  }

  /// 右键/辅助点击手牌：始终打开检视与手牌动作菜单，
  /// 不受就地选择窗口影响。
  void handleHandCardSecondaryTap(int sequence, int code) {
    if (!widget.isInDuel) return;
    _sound.playDialogOpen();
    _showHandCardMenu(sequence, code);
  }

  void _showHandCardMenu(int sequence, int code) {
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyHandCardTap(sequence, code, _boardN.getCardInfo(code));
  }

  void handleFieldCardTap(FieldCard? fieldCard, int? code) {
    // 与 handleHandCardTap 同理：HUD 隐藏阶段不响应场上点击。
    if (!widget.isInDuel) return;
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (fieldCard != null && _selectN.inlineSelectActive) {
      handleInlineFieldCardTap(fieldCard);
      return;
    }
    _showFieldCardMenu(fieldCard, code);
  }

  /// 右键/辅助点击场上卡：始终打开检视与动作菜单，
  /// 不受就地选择窗口影响。
  void handleFieldCardSecondaryTap(FieldCard fieldCard, int code) {
    if (!widget.isInDuel) return;
    _sound.playDialogOpen();
    _showFieldCardMenu(fieldCard, code);
  }

  void _showFieldCardMenu(FieldCard? fieldCard, int? code) {
    final effectiveCode = code ?? fieldCard?.code;
    if (effectiveCode != null) {
      _inspectCardMut(effectiveCode);
    }
    final actions = fieldCard == null
        ? const <PlaymatResolvedAction>[]
        : resolveFieldActions(fieldCard, _select, _board);
    _overlayN.applyFieldCardSelection(
      fieldCard == null || actions.isEmpty ? null : fieldCard,
    );
  }

  static bool isBrowsableZone(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
      case 'opp_grave':
      case 'self_removed':
      case 'opp_removed':
      case 'self_extra':
      case 'opp_extra':
        return true;
      default:
        return false;
    }
  }

  void handleZoneInspect(String zoneKey) {
    if (isBrowsableZone(zoneKey)) {
      openZoneBrowser(zoneKey);
    }
  }

  void openZoneBrowser(String zoneKey) {
    _sound.playZoneOpen();
    _overlayN.openZoneBrowser(zoneKey);
  }

  void closeZoneBrowser() {
    if (!_overlayN.closeZoneBrowser()) return;
    _sound.playZoneClose();
  }

  void inspectZoneBrowserCard(int sequence, int code) {
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyZoneBrowserCardInspect(
      sequence,
      code,
      _boardN.getCardInfo(code),
    );
  }

  void togglePhaseMenu() {
    if (ref.read(phaseActionsProvider).isEmpty) {
      return;
    }
    final next = !_overlay.showPhaseMenu;
    if (next) {
      _sound.playMenuOpen();
    } else {
      _sound.playMenuClose();
    }
    _overlayN.setPhaseMenuVisible(next);
  }
}
