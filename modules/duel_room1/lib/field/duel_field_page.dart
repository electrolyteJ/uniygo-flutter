import 'dart:async';
import 'dart:ui';

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
import 'package:duelink/duelink.dart' show PlayerInfo, PlayerType, RoomInDuel;
import 'package:ygo_data/card_info.dart' as pkg;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duel_room1/field/duel_flame_game.dart';
import 'package:duel_room1/field/models/chain_order_map.dart';
import 'package:duel_room1/field/models/duel_field_layout.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/models/phase_rail_layout.dart';
import 'package:duel_room1/field/flame_playmat_field.dart';
import 'package:duel_room1/field/widgets/hud/phase_bar.dart';
import 'package:duel_room1/field/widgets/hud/player_status_card.dart';
import 'package:duel_room1/field/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room1/field/widgets/inspector/zone_browser_modal.dart';
import 'package:duel_room1/field/widgets/menus/duel_field_popover_layout.dart';
import 'package:duel_room1/field/widgets/menus/field_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/phase_action_menu.dart';
import 'package:duel_room1/field/widgets/selector/announce_dialog.dart';
import 'package:duel_room1/field/widgets/selector/card_selector.dart';
import 'package:duel_room1/field/widgets/overlay/confirm_cards_dialog.dart';
import 'package:duel_room1/field/widgets/overlay/confirm_floating_card.dart';
import 'package:duel_room1/field/widgets/selector/position_selector.dart';
import 'package:duel_room1/field/widgets/overlay/select_prompt_layer.dart';
import 'package:duel_room1/field/widgets/overlay/turn_order_hint.dart';
import 'package:duel_room1/field/widgets/selector/yes_no_dialog.dart';
import 'package:duel_room1/duel_room_exit.dart';

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
///   [FlameFieldSnapshot] 推入 [DuelFlameGame]（不走 build 副作用），
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
  final bool hudVisible;

  const DuelFieldPage(this.players, {super.key, this.hudVisible = true});

  @override
  ConsumerState<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends ConsumerState<DuelFieldPage> {
  static const double _topHudBodyHeight = 112.0;
  static const double _opponentHandGap = 10.0;
  static const double _inspectorTop = 124.0;

  DuelFlameGame? _flameGame;
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
  CardConfirmNotifier get _confirmN => ref.read(cardConfirmProvider.notifier);
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
    _confirmSub = ref.listenManual(cardConfirmProvider, (_, _) => _pushSnapshot());
    _overlaySub = ref.listenManual(fieldOverlayProvider, (_, _) => _pushSnapshot());
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
    if (!mounted || !widget.hudVisible) return;
    final queue = isSelf ? _drawQueueSelf : _drawQueueOpp;
    if (isSelf ? _drawPlayingSelf : _drawPlayingOpp) return;
    final active = queue.active;
    if (active == null) return;
    final game = _flameGame;
    if (game == null) {
      // 游戏尚未创建（理论上不会：场地页常驻挂载），丢弃本段动画防卡死。
      queue.drain();
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
    if (oldWidget.hudVisible == widget.hudVisible) return;
    // 手牌栏可见性跟随 HUD（猜拳/等待阶段场地页仅作背景）。
    _flameGame?.setHandBarsVisible(widget.hudVisible);
    // HUD 由隐藏转为可见（如猜拳结果最短停留结束进入对局）时，
    // 补播停留期间排队但未能播放的抽卡/发牌动画（双方各自补播）。
    if (widget.hudVisible) {
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

  DuelFlameGame _ensureFlameGame() {
    final existing = _flameGame;
    if (existing != null) return existing;
    final game = DuelFlameGame(
      onCardSelect: handleFieldCardTap,
      onZoneInspect: handleZoneInspect,
      onPhaseLampTap: togglePhaseMenu,
      isPhaseLampEnabled: _canTapPhaseLamp,
      onPlaceSlotTap: (key) => _selectN.respondSelectPlaceKey(key),
      onHandCardTap: handleHandCardTap,
      onAnchorsChanged: _handleAnchorsChanged,
    );
    _flameGame = game;
    // 手牌栏可见性与对方栏顶边距随页面状态初始化（后续变化分别由
    // didUpdateWidget 与 build 推送）。
    game.setHandBarsVisible(widget.hudVisible);
    game.setOppHandTopY(
      MediaQuery.of(context).padding.top + _topHudBodyHeight + _opponentHandGap,
    );
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
    );
  }

  /// 己方手牌快照（底部手牌栏）。
  ///
  /// 高亮/勾选集合的来源与原 Flutter 版 HandCardsBar 挂载处一致：
  /// 手牌确认（MSG_CONFIRM_CARDS）优先，否则就地选择窗口的高亮/勾选。
  HandSnapshot _buildSelfHandSnapshot() {
    final confirm = _confirm;
    final isDuelist = ref.read(duelRoomProvider).selfType.isDuelist;
    final inlineActive =
        _selectN.selectPromptMode == SelectPromptMode.inline;
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

  Widget _buildBattlefield() {
    // 快照推送已移至 listenManual 订阅（见 initState）；
    // build 只负责挂载 GameWidget，不在此推状态。
    // onAnchorsChanged 在 _ensureFlameGame 构造游戏时注入，组件不重复传。
    return FlamePlaymatField(game: _ensureFlameGame());
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
      height: PhaseRailLayout.height + 20,
    );
  }

  Rect? _fieldCardRect(Size viewport, FieldCard fieldCard) {
    final anchoredRect = _fieldAnchors?.slotRects[fieldSlotId(fieldCard)];
    if (anchoredRect != null) {
      return anchoredRect;
    }
    final fallback = fieldCardAnchor(viewport, fieldCard, _board.myController);
    return Rect.fromCenter(
      center: fallback,
      width: DuelFieldLayout.slotWidth,
      height: DuelFieldLayout.slotHeight,
    );
  }

  Widget _buildTopHud(DuelHudSlice hud, List<PlayerInfo> players) {
    final mc = hud.myController;
    final isMyTurn = hud.currentPlayer == mc;
    // 引擎玩家编号 → 队伍 → 座位名字：tag（双打）模式座位 0-3、
    // 队伍为 pos % 2，引擎消息里的玩家编号是队伍号，同队队友名字
    // 以 " / " 连接展示；1v1 每队恰一座位，与旧的 pos 精确匹配一致。
    // 见 biz 的 teamOfSeat / teamDisplayName。
    // players 取 DuelFieldState.players（局中最新），未下发时退回 widget.players。
    final effectivePlayers = players.isNotEmpty ? players : widget.players;
    // 引擎编号 → 队伍/座位经 teamOfEnginePlayer 的「myController ↔ mySeat」
    // 锚点映射：服务端猜拳 TPResult 可能交换 players[]（引擎编号 ≠ 座位号），
    // 直接拿引擎编号当座位会把名字与 LP 错位（观感即"生命值对调"）。
    final selfName = teamDisplayName(
      _board.teamOfEnginePlayer(mc),
      effectivePlayers,
      fallback: '我方',
    );
    final oppName = teamDisplayName(
      _board.teamOfEnginePlayer(1 - mc),
      effectivePlayers,
      fallback: '对方',
    );
    // 当前回合玩家的剩余时间
    final turnTimeLeft = hud.currentPlayer == mc
        ? hud.selfTimeLeft
        : hud.opponentTimeLeft;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _buildHudIconButton(
              icon: Icons.arrow_back,
              onPressed: () {
                backHomeDialog(
                  context: context,
                  ref: ref,
                  title: '退出决斗',
                  content: '是否确认退出当前决斗？',
                );
              },
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerStatusCard(
                      name: oppName,
                      lp: hud.opponentLp,
                      lpDelta: hud.opponentLpDelta,
                      lpEventId: hud.opponentLpEventId,
                      isSelf: false,
                      isActiveTurn: !isMyTurn,
                      handCount: hud.opponentHandCount,
                      deckCount: hud.oppDeck,
                      extraCount: hud.oppExtra,
                      graveCount: hud.oppGrave,
                      removedCount: hud.oppRemoved,
                      onExtraTap: () => openZoneBrowser('opp_extra'),
                      onGraveTap: () => openZoneBrowser('opp_grave'),
                      onRemovedTap: () => openZoneBrowser('opp_removed'),
                    ),
                    const SizedBox(width: 16),
                    PhaseBar(
                      turnCount: hud.turnCount,
                      isMyTurn: isMyTurn,
                      leftTimeSeconds: turnTimeLeft,
                    ),
                    const SizedBox(width: 16),
                    PlayerStatusCard(
                      name: selfName,
                      lp: hud.selfLp,
                      lpDelta: hud.selfLpDelta,
                      lpEventId: hud.selfLpEventId,
                      isSelf: true,
                      isActiveTurn: isMyTurn,
                      handCount: hud.selfHandCount,
                      deckCount: hud.selfDeck,
                      extraCount: hud.selfExtra,
                      graveCount: hud.selfGrave,
                      removedCount: hud.selfRemoved,
                      onExtraTap: () => openZoneBrowser('self_extra'),
                      onGraveTap: () => openZoneBrowser('self_grave'),
                      onRemovedTap: () => openZoneBrowser('self_removed'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB8060B14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x3300F0FF), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x1A00F0FF), blurRadius: 24),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white.withValues(alpha: 0.92)),
            tooltip: '返回',
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  // ---- 选择提示组装 ----

  /// 把选择子状态组装成 [SelectPromptLayer] 的纯 UI props，
  /// 选择响应（respondXxx）的分发全部收口在这里；所有 respond* 调用
  /// 都带上当前窗口的 generation，过期窗口的响应由 notifier 丢弃。
  Widget _buildSelectPromptLayer(SelectPromptMode mode) {
    final select = _select.currentSelect;
    switch (mode) {
      case SelectPromptMode.none:
        return const SizedBox.shrink();
      case SelectPromptMode.place:
        return SelectPromptLayer(
          mode: mode,
          placeTargetCount: _select.placeTargetFieldKeys.length,
        );
      case SelectPromptMode.inline:
        // 多选（非单张、非连锁、非解除选择）才需要本地确认按钮。
        final showConfirm =
            select != null &&
            select.type != SelectType.chain &&
            select.type != SelectType.unselect &&
            !(select.min == 1 && select.max == 1);
        return SelectPromptLayer(
          mode: mode,
          inlineHint: _select.inlineSelectHint,
          inlineCancelLabel: select?.cancelable == true
              ? (select!.type == SelectType.chain ? '不连锁' : '取消')
              : null,
          inlineShowFinish:
              select?.type == SelectType.unselect && select!.finishable,
          inlineShowConfirm: showConfirm,
          inlineCanConfirm: _select.inlineSelectCanConfirm,
          onInlineCancel: _selectN.cancelInlineSelect,
          onInlineFinish: _selectN.finishInlineUnselect,
          onInlineConfirm: _selectN.confirmInlineSelect,
        );
      case SelectPromptMode.modal:
        return SelectPromptLayer(
          mode: mode,
          modalChild: select == null ? null : _buildSelectModal(select),
        );
    }
  }

  /// 模态选择弹窗：选项落在不可直接点击的区域的回退，
  /// 以及排序/计数器/效果选项等复杂交互。
  Widget _buildSelectModal(SelectState select) {
    final onInspectCard = inspectCard;
    final generation = select.generation;
    switch (select.type) {
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectCard(sequences, generation: generation),
          onCancel: () =>
              _selectN.respondSelectCard([], generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.unselect:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectUnselectCard(
            sequences.isEmpty ? null : sequences.first,
            generation: generation,
          ),
          onCancel: () =>
              _selectN.respondSelectUnselectCard(null, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectChain(
            sequences.isNotEmpty ? sequences.first : -1,
            generation: generation,
          ),
          onCancel: () =>
              _selectN.respondSelectChain(-1, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              _selectN.respondSelectPosition(position, generation: generation),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          cardCode: select.options.isNotEmpty
              ? select.options.first.code
              : null,
          onInspectCard: onInspectCard,
          onYes: () =>
              _selectN.respondSelectEffectYn(true, generation: generation),
          onNo: () =>
              _selectN.respondSelectEffectYn(false, generation: generation),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          cardCode: select.options.isNotEmpty
              ? select.options.first.code
              : null,
          onInspectCard: onInspectCard,
          onYes: () =>
              _selectN.respondSelectYesNo(true, generation: generation),
          onNo: () =>
              _selectN.respondSelectYesNo(false, generation: generation),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
            generation: generation,
          ),
          onCancel: () =>
              _selectN.respondSelectOption(0, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceCard:
        return AnnounceCardDialog(
          // 受限宣言（抹杀之指名者等）：把引擎下发的可宣言卡集合
          // 传给弹窗直接罗列候选；null 时退回自由宣言搜索。
          declarableCodes: _select.announceCardDeclarableCodes,
          onLoadDeclarable: _selectN.loadDeclarableCards,
          onSearch: _selectN.searchAnnounceCards,
          onSelect: (code) =>
              _selectN.respondAnnounceCard(code, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceNumber:
        return AnnounceChoiceDialog(
          title: '宣言数值',
          options: select.options,
          onSelect: (index) =>
              _selectN.respondAnnounceNumber(index, generation: generation),
        );
      case SelectType.announceAttrib:
        return AnnounceChoiceDialog(
          title: '宣言属性',
          options: select.options,
          onSelect: (index) =>
              _selectN.respondAnnounceAttrib(index, generation: generation),
        );
      case SelectType.announceRace:
        return AnnounceChoiceDialog(
          title: '宣言种族',
          options: select.options,
          onSelect: (index) =>
              _selectN.respondAnnounceRace(index, generation: generation),
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectSum(sequences, generation: generation),
          onCancel: () => _selectN.respondSelectSum([], generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectCounter(sequences, generation: generation),
          onCancel: () =>
              _selectN.respondSelectCounter([], generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSortCard(sequences, generation: generation),
          onCancel: () => _selectN.respondSortCard([], generation: generation),
          onInspectCard: onInspectCard,
        );
      default:
        return const SizedBox.shrink();
    }
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
    _flameGame?.setOppHandTopY(
      MediaQuery.of(context).padding.top + _topHudBodyHeight + _opponentHandGap,
    );
    return Portal(
      child: Scaffold(
        backgroundColor: const Color(0xFF010308),
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _buildBattlefield()),
            // HUD 层仅对局进行中展示；非对局阶段本页作为半透明等待弹窗
            // 背后的场地背景常驻挂载（对齐 godot：duel_ui 决斗开始才显示）。
            if (widget.hudVisible) Positioned.fill(child: _buildHudOverlay()),
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
    final viewport = MediaQuery.sizeOf(context);
    final hasFieldAnchors = _fieldAnchors != null;
    final phaseRect = _phaseLampRect(viewport);
    // 弹层统一通过 Portal 渲染：底边对齐锚点矩形顶部，
    // 由 flutter_portal 自动避让屏幕边界。
    const overlayAnchor = Aligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      shiftToWithinBound: AxisFlag(x: true, y: true),
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
            return Positioned.fromRect(
              rect: phaseRect,
              child: PortalTarget(
                visible: true,
                anchor: overlayAnchor,
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
            return Positioned.fromRect(
              rect: rect,
              child: PortalTarget(
                visible: entries.isNotEmpty,
                anchor: overlayAnchor,
                portalFollower: FieldActionPopover(actions: entries),
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
            return Positioned.fromRect(
              rect: rect,
              child: PortalTarget(
                visible: true,
                anchor: overlayAnchor,
                portalFollower: HandActionPopover(actions: entries),
                child: const SizedBox.shrink(),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => _buildTopHud(
            ref.watch(duelFieldProvider.select(selectHudSlice)),
            ref.watch(duelFieldProvider.select((s) => s.players)),
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final key = ref.watch(
              fieldOverlayProvider.select((s) => s.openZoneBrowserKey),
            );
            if (key == null) return const SizedBox.shrink();
            final selectedSeq = ref.watch(
              fieldOverlayProvider.select((s) => s.selectedZoneBrowserSequence),
            );
            return ZoneBrowserModal(
              zoneBrowserKey: key,
              cards: ref.watch(zoneBrowserEntriesProvider(key)),
              selectedCardSequence: selectedSeq,
              onCardTap: inspectZoneBrowserCard,
              onClose: closeZoneBrowser,
              selectedActions: ref.watch(zoneBrowserActionsProvider(key)),
              hiddenCount: ref.watch(zoneHiddenCountProvider(key)),
              cardNameBuilder: (code) =>
                  _boardN.getCardInfo(code)?.name ?? 'Card #$code',
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final mode = ref.watch(selectPromptModeProvider);
            // 同模式内的窗口推进（选项/提示语变化）也要驱动重建。
            ref.watch(
              selectWindowProvider.select(
                (s) => (
                  s.currentSelect,
                  s.inlineSelectHint,
                  s.inlineSelectCanConfirm,
                  s.placeTargetFieldKeys.length,
                ),
              ),
            );
            if (mode == SelectPromptMode.none) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(child: _buildSelectPromptLayer(mode));
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final panel = ref.watch(
              cardConfirmProvider.select((s) => s.confirmPanel),
            );
            if (panel == null) return const SizedBox.shrink();
            // 卡名缓存到达时刷新面板文字。
            ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
            return Positioned.fill(
              child: GestureDetector(
                onTap: () => _confirmN.dismissConfirmPanel(),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: ConfirmCardsDialog(
                      title: panel.title,
                      codes: panel.codes,
                      cardNameBuilder: (code) =>
                          _boardN.getCardInfo(code)?.name ?? 'Card #$code',
                      onDismiss: () => _confirmN.dismissConfirmPanel(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final preview = ref.watch(
              cardConfirmProvider.select(
                (s) => (
                  isFloat: s.isFloatPreview,
                  owner: s.floatPreviewOwner,
                  isExtra: s.floatPreviewIsExtra,
                  codes: s.floatPreviewCodes,
                  index: s.floatPreviewIndex,
                ),
              ),
            );
            if (!preview.isFloat) return const SizedBox.shrink();
            return _buildFloatPreview(preview);
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final inspector = ref.watch(
              fieldOverlayProvider.select(
                (s) => (
                  show: s.showInspector,
                  code: s.inspectedCardCode,
                  info: s.inspectedCardInfo,
                ),
              ),
            );
            if (!inspector.show) return const SizedBox.shrink();
            // 卡信息异步到达（ensureCardInfo 批次完成）时刷新卡名。
            ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
            return _buildInspector(inspector);
          },
        ),
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
    return Positioned(
      left: 18,
      top: _inspectorTop,
      bottom: 160,
      child: CardDetailDrawer(
        cardInfo: inspectedCardInfo,
        cardCode: inspectedCardCode,
        onClose: _overlayN.dismissInspector,
      ),
    );
  }

  Widget _buildFloatPreview(
    ({bool isFloat, int? owner, bool isExtra, List<int> codes, int index})
    preview,
  ) {
    // 下标越界（codes 变短等瞬态）时不渲染，避免 RangeError。
    if (preview.index >= preview.codes.length) {
      return const SizedBox.shrink();
    }
    final isSelf = preview.owner == _board.myController;
    final zoneKey = preview.isExtra
        ? (isSelf ? 'self_extra' : 'opp_extra')
        : (isSelf ? 'self_deck' : 'opp_deck');
    final zoneRect = _fieldAnchors?.slotRects[zoneKey];

    double? top, bottom, left, right;
    if (zoneRect != null) {
      top = zoneRect.top - 200;
      left = zoneRect.center.dx - 75;
    } else {
      if (isSelf) {
        bottom = 30;
        right = 30;
      } else {
        top = 120;
        right = 30;
      }
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: ConfirmFloatingCard(
        codes: preview.codes,
        // 当前展示下标由 notifier 计时推进（每卡 750ms + 500ms 收尾），
        // 组件自身不再持有逐张计时与自动关闭逻辑。
        currentIndex: preview.index,
        title: preview.isExtra ? '额外卡组顶部' : '卡组顶部',
        cardNameBuilder: (code) =>
            _boardN.getCardInfo(code)?.name ?? 'Card #$code',
        onDismiss: () => _confirmN.dismissConfirmPanel(),
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

  void handleHandCardTap(int sequence, int code) {
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (_selectN.inlineSelectActive) {
      handleInlineHandCardTap(sequence, code);
      return;
    }
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyHandCardTap(sequence, code, _boardN.getCardInfo(code));
  }

  void handleFieldCardTap(FieldCard? fieldCard, int? code) {
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (fieldCard != null && _selectN.inlineSelectActive) {
      handleInlineFieldCardTap(fieldCard);
      return;
    }
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
