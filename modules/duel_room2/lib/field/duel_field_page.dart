import 'dart:async';
import 'package:applog/console.dart' as console;
import 'dart:math' as math;
import 'dart:ui';

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:duel_room2/field/models/playmat_field_view_data.dart';
import 'package:duel_room2/field/widgets/field/prototype_playmat_field.dart';
import 'package:duel_room2/field/widgets/hud/duel_field_hud.dart';
import 'package:duel_room2/field/widgets/duel_animation_layers.dart';
import 'package:duel_room2/field/widgets/hud/hand_cards_bar.dart';
import 'package:duel_room2/field/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room2/field/widgets/inspector/duel_log_drawer.dart';
import 'package:duel_room2/field/widgets/inspector/zone_browser_modal.dart';
import 'package:duel_room2/field/widgets/menus/duel_field_popover_layout.dart';
import 'package:duel_room2/field/widgets/menus/field_action_popover.dart';
import 'package:duel_room2/field/widgets/menus/hand_action_popover.dart';
import 'package:duel_room2/field/widgets/menus/phase_action_menu.dart';
import 'package:duel_room2/field/widgets/overlay/chain_stack_overlay.dart';
import 'package:duel_room2/field/widgets/overlay/confirm_cards_dialog.dart';
import 'package:duel_room2/field/widgets/overlay/confirm_floating_card.dart';
import 'package:duel_room2/field/widgets/overlay/duel_select_overlay.dart';
import 'package:duel_room2/field/widgets/overlay/turn_order_hint.dart';
import 'package:duelink/duelink.dart' show PlayerInfo, PlayerType;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/models/battle_presentation.dart';
import 'package:biz/duel/models/draw_animation_event.dart';
import 'package:biz/duel/models/duel_menu.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:biz/duel/models/playmat_resolved_action.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/field/select_window_state.dart';

/// 决斗场地页：负责 store 接线与整体布局。
///
/// 与 duel_room1 的差异：
/// - 状态读取从 `context.watch<DuelFieldStore>()` 改为直连 watch 四个子状态
///   provider（duelField / selectWindow / cardConfirm / fieldOverlay），
///   任一变更即重建，语义等价原 ChangeNotifier 的全量 notifyListeners；
///   写单状态直连对应 Notifier；服务器消息由 DuelMessageRouter 分发，
///   跨状态的本地交互与菜单派生逻辑直接内联在本页；
/// - 先后攻提示从手动 addListener 兜底改为 `ref.listen(isFirstTurn)`；
/// - Flame 渲染分支与 RenderModeToggle 不实现，场地固定为
///   [PrototypePlaymatField]（Flutter 原型渲染）。
///
/// 选择/检视/菜单等交互状态由四个子状态持有，跨状态的菜单派生与
/// 交互入口直接内联在本页；弹层几何计算见 duel_field_popover_layout.dart。
class DuelFieldPage extends ConsumerStatefulWidget {
  final List<PlayerInfo> players;
  const DuelFieldPage(this.players, {super.key});

  @override
  ConsumerState<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends ConsumerState<DuelFieldPage>
    with TickerProviderStateMixin {
  static const double _topHudBodyHeight = 112.0;
  static const double _opponentHandGap = 10.0;
  static const double _inspectorTop = 124.0;
  static const double _logDrawerTop = 126.0;

  PlaymatAnchorData? _fieldAnchors;
  Map<int, Rect> _selfHandCardRects = const {};
  Map<int, Rect> _oppHandCardRects = const {};
  late final AnimationController _drawController;

  /// 抽卡动画 FIFO 队列：播放中到达的新事件排队等待，不再打断当前动画
  /// （连续抽卡场景，如「天使的施舍」）；同 id 更新就地 patch，不入队。
  /// 队列语义见 [DrawAnimationQueue]；页面只维护动画的启动/结束。
  final DrawAnimationQueue _drawQueue = DrawAnimationQueue();

  /// 正在播放的抽卡动画事件（取自队列 active），null 时不渲染动画层。
  DrawAnimationEvent? get _activeDrawEvent => _drawQueue.active;
  late final AnimationController _attackController;
  BattlePresentation? _activeAttack;

  /// 页面主 Stack 的 key：作为手牌矩形上报与抽卡动画的公共坐标空间
  /// （与场地 anchors 的 localToGlobal 祖先等价的视口坐标系）。
  final GlobalKey _bodyStackKey = GlobalKey();

  // 先后攻提示：进入场地页时居中短暂展示一次。
  bool _showTurnOrderHint = false;
  bool _isFirstTurn = false;

  // 四个子状态 + 跨状态控制器的便捷访问；读取经 ref.read，
  // 重建由 build 里的四个 ref.watch 驱动。
  DuelFieldState get _board => ref.read(duelFieldProvider);
  SelectWindowState get _select => ref.read(selectWindowProvider);
  CardConfirmState get _confirm => ref.read(cardConfirmProvider);
  FieldOverlayState get _overlay => ref.read(fieldOverlayProvider);
  DuelFieldNotifier get _boardN => ref.read(duelFieldProvider.notifier);
  SelectWindowNotifier get _selectN => ref.read(selectWindowProvider.notifier);
  CardConfirmNotifier get _confirmN => ref.read(cardConfirmProvider.notifier);
  FieldOverlayNotifier get _overlayN => ref.read(fieldOverlayProvider.notifier);
  YgoSoundService get _sound => ref.read(ygoSoundServiceProvider);

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      // easeOutCubic 前段位移占比高，过短会看不清飞行过程。
      duration: const Duration(milliseconds: 1400),
    );
    // 逐帧进度由 DrawCardAnimation 内部的 AnimatedBuilder 消费，
    // 页面只在动画开始（_playActiveDrawAnimation）与结束（status listener）时
    // setState，不再每帧重建整页。
    _drawController.addStatusListener(_handleDrawAnimationStatus);
    _attackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _attackController.addStatusListener(_handleAttackAnimationStatus);
    _scheduleTurnOrderHint();
    // 场地页在 RoomInDuel 才挂载：猜拳结果最短停留期间（biz 层兜底）
    // 开局 MSG_DRAW 已按服务器速度处理完毕，早于 build 里的 ref.listen
    // 注册，这里补播挂载前已到达的抽卡事件。状态只保留最新一条事件
    // （更早的已被覆盖），与 listener 的重复由队列同 id patch 去重。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(duelFieldProvider).drawAnimationEvent;
      if (pending == null) return;
      if (_drawQueue.submit(pending) == DrawQueueSubmitResult.started) {
        _playActiveDrawAnimation();
      }
    });
  }

  @override
  void dispose() {
    // 显式清空队列：dispose 后状态监听不再触发，残留事件不应滞留。
    _drawQueue.clear();
    _drawController.dispose();
    _attackController.dispose();
    super.dispose();
  }

  /// 进入场地页后读取先后攻信息，居中弹出一次提示。
  /// 观战者不提示；信息尚未到达时由 build 中的 `ref.listen(isFirstTurn)`
  /// 在值到达后兜底触发（替代 duel_room1 的手动 addListener）。
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

  void _handleDrawAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    // 当前动画播完：取出队列里的下一个事件继续播放；
    // 队列为空则移除动画层（setState 仅发生在动画开始/结束两端）。
    final next = _drawQueue.drain();
    setState(() {});
    if (next != null) {
      _drawController.forward(from: 0);
    }
  }

  /// 启动队列当前 active 事件的飞行动画（active 已由队列在 submit 时设置）。
  void _playActiveDrawAnimation() {
    if (!mounted) return;
    setState(() {});
    _drawController.forward(from: 0);
  }

  /// 抽卡/发牌动画期间，手牌下标 [index] 是否应隐藏。
  ///
  /// MSG_DRAW 把新卡追加到手牌末尾的同时触发飞行动画，若不隐藏，
  /// 手牌栏会先渲染出整张卡、动画再叠着飞一遍。这里在动画播放期间
  /// 隐藏末尾对应卡位：active 事件的卡等动画播完才显现，排队事件的
  /// 卡整段隐藏直到轮到它播放。
  bool _isDrawConcealed(int index, bool isSelf) {
    var activeCount = 0;
    var totalCount = 0;
    final current = _drawQueue.active;
    if (current != null && (current.player == _board.myController) == isSelf) {
      activeCount = current.codes.length;
      totalCount += activeCount;
    }
    for (final e in _drawQueue.pending) {
      if ((e.player == _board.myController) == isSelf) {
        totalCount += e.codes.length;
      }
    }
    if (totalCount == 0) return false;
    final handLength = isSelf
        ? _board.selfHand.length
        : _board.opponentHand.length;
    final start = (handLength - totalCount).clamp(0, 1 << 30);
    final rel = index - start;
    if (rel < 0 || rel >= totalCount) return false;
    // 排队事件的卡：整段隐藏，轮到它播放时才按 active 处理。
    if (rel >= activeCount) return true;
    // 动画播完（controller 到 1，status listener 随即 drain+setState）
    // 才展示整张卡。
    return _drawController.value < 1.0;
  }

  void _handleAttackAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _activeAttack == null) return;
    setState(() => _activeAttack = null);
  }

  void _playAttackAnimation(BattlePresentation presentation) {
    if (!mounted) return;
    setState(() => _activeAttack = presentation);
    _attackController.forward(from: 0);
  }

  /// PhaseLamp 可点击的完整条件：
  /// 1. 当前是己方回合（对方回合不能点）
  /// 2. 当前窗口下有可用阶段动作
  bool _canTapPhaseLamp() =>
      _board.currentPlayer == _board.myController &&
      ref.watch(phaseActionsProvider).isNotEmpty;

  void _handleAnchorsChanged(PlaymatAnchorData anchors) {
    if (!mounted || _fieldAnchors?.signature == anchors.signature) {
      return;
    }
    _fieldAnchors = anchors;
    // Defer setState to post-frame: anchors 可能在布局过程中上报，
    // build 期间不允许 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // ---- 视图数据与锚点 ----

  PlaymatFieldViewData _buildFieldViewData() {
    return PlaymatFieldViewData(
      fieldCards: Map<String, FieldCard>.from(_board.fieldCards),
      selfController: _board.myController,
      opponentController: 1 - _board.myController,
      selfDeckCount: _board.selfDeck,
      selfExtraCount: _board.selfExtra,
      selfGraveCount: _board.selfGrave,
      selfRemovedCount: _board.selfRemoved,
      selfExtraTopCode: _board.topZoneCode('self_extra'),
      selfGraveTopCode: _board.topZoneCode('self_grave'),
      selfRemovedTopCode: _board.topZoneCode('self_removed'),
      oppDeckCount: _board.oppDeck,
      oppExtraCount: _board.oppExtra,
      oppGraveCount: _board.oppGrave,
      oppRemovedCount: _board.oppRemoved,
      oppExtraTopCode: _board.topZoneCode('opp_extra'),
      oppGraveTopCode: _board.topZoneCode('opp_grave'),
      oppRemovedTopCode: _board.topZoneCode('opp_removed'),
    );
  }

  Rect _phaseLampRect(Size viewport) {
    final anchors = _fieldAnchors;
    if (anchors != null) {
      return anchors.phaseLampRect;
    }
    // anchors 未就绪时的兜底：与 DuelFieldLayout.phaseLampFallbackRatio 对齐。
    // x=0.88 对应 self_grave（我方墓地，棋盘右区 colX[6] Monster 行）；y=0.53 对应 Monster 行上沿附近。
    final fallback = Offset(viewport.width * 0.88, viewport.height * 0.53);
    return Rect.fromLTWH(fallback.dx, fallback.dy, 132, 44);
  }

  Rect? _fieldCardRect(Size viewport, FieldCard fieldCard) {
    final anchoredRect = _fieldAnchors?.slotRects[fieldSlotId(fieldCard)];
    if (anchoredRect != null) {
      return anchoredRect;
    }
    final fallback = fieldCardAnchor(viewport, fieldCard, _board.myController);
    return Rect.fromCenter(center: fallback, width: 68, height: 96);
  }

  @override
  Widget build(BuildContext context) {
    // 先后攻信息迟到时的兜底：值从 null 变为非 null 时弹出提示。
    ref.listen(duelRoomProvider.select((s) => s.isFirstTurn), (prev, next) {
      if (next == null) return;
      if (ref.read(duelRoomProvider).selfType == PlayerType.observer) return;
      _revealTurnOrderHint(next);
    });
    ref.listen(duelFieldProvider.select((s) => s.drawAnimationEvent), (
      prev,
      next,
    ) {
      if (next == null) {
        // 新对局开始（handleStart 清空事件）：丢弃未播完的动画与排队事件，
        // 避免上一局残留的抽卡动画飞进新局。
        if (_drawQueue.isNotEmpty) {
          _drawQueue.clear();
          _drawController.stop();
          setState(() {});
        }
        return;
      }
      switch (_drawQueue.submit(next)) {
        case DrawQueueSubmitResult.started:
          _playActiveDrawAnimation();
        case DrawQueueSubmitResult.patchedActive:
          // 同 id 更新命中播放中事件（MSG_CONFIRM_CARDS 后的 reveal 等）：
          // 只刷新画面数据，不重启动画。
          setState(() {});
        case DrawQueueSubmitResult.patchedQueued:
        case DrawQueueSubmitResult.enqueued:
          // 排队中：等当前动画播完由 status listener 依序取出。
          break;
      }
    });
    // 攻击宣言（MSG_ATTACK）时播放怪兽攻击动画；MSG_BATTLE 只是回填
    // 攻守数值，不重播。用 attackerAttack 是否为 null 区分两阶段。
    ref.listen(duelFieldProvider.select((s) => s.battlePresentation), (
      prev,
      next,
    ) {
      if (next == null || next.attackerAttack != null) return;
      _playAttackAnimation(next);
    });

    // 任一子状态变更都触发重建（等价原 ChangeNotifier 全量通知），
    // 读取经上方的 _board/_select/_confirm/_overlay getter。
    ref.watch(duelFieldProvider);
    ref.watch(selectWindowProvider);
    ref.watch(cardConfirmProvider);
    ref.watch(fieldOverlayProvider);
    final isMyTurn = _board.currentPlayer == _board.myController;
    final fieldViewData = _buildFieldViewData();
    if (ref.watch(needsHigherPriorityDismissProvider)) {
      // build 期间不能改状态，推迟到帧末让本地弹层让位。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlayN.clearLocalUi();
      });
    }
    final zoneBrowserKey = _overlay.openZoneBrowserKey;
    final zoneBrowserEntries = zoneBrowserKey == null
        ? const <ZoneBrowserCardEntry>[]
        : ref.watch(zoneBrowserEntriesProvider(zoneBrowserKey));
    final zoneBrowserActions = zoneBrowserKey == null
        ? const <ActionMenuEntry>[]
        : ref.watch(zoneBrowserActionsProvider(zoneBrowserKey));
    final handActionEntries = ref.watch(handActionMenuProvider);
    final phaseActionEntries = ref.watch(phaseActionMenuProvider);
    final fieldActionEntries = ref.watch(fieldActionMenuProvider);
    // 选择提示统一由 SelectPromptLayer 收口：呈现方式（放置横幅/就地操作栏/
    // 模态弹窗）由 store 判定，页面只区分 none 与 modal（modal 期间隐藏连锁叠层）。
    final selectPromptMode = _selectN.selectPromptMode;
    final topInset = MediaQuery.of(context).padding.top;
    final opponentHandTop = topInset + _topHudBodyHeight + _opponentHandGap;
    // viewport 仅用于 anchors 缺失时的 fallback 比例估算；
    // 弹层定位与避让统一由全局 Portal 的 Aligned 锚点负责。
    final viewport = MediaQuery.sizeOf(context);
    final hasFieldAnchors = _fieldAnchors != null;
    final phaseRect = _phaseLampRect(viewport);
    final selectedFieldCard = _overlay.selectedFieldCard;
    final fieldRect = selectedFieldCard == null
        ? null
        : _fieldCardRect(viewport, selectedFieldCard);
    // 弹层统一通过全局 Portal 渲染：底边对齐锚点矩形顶部，
    // 由 flutter_portal 自动避让屏幕边界。
    const overlayAnchor = Aligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      shiftToWithinBound: AxisFlag(x: true, y: true),
    );
    // 页面自带 Portal：内部的 PortalTarget（阶段菜单/场上操作/手牌菜单）
    // 不再依赖宿主 App 提供全局 Portal；宿主已有 Portal 时嵌套安全。
    final bodyStackAncestor =
        _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    return Portal(
      child: Scaffold(
        backgroundColor: const Color(0xFF010308),
        body: Stack(
          key: _bodyStackKey,
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            PrototypePlaymatField(
              data: fieldViewData,
              phase: _board.phase,
              phaseLampEnabled: _canTapPhaseLamp(),
              onPhaseLampTap: togglePhaseMenu,
              onFieldCardTap: handleFieldCardTap,
              onZoneTap: handleZoneInspect,
              onAnchorsChanged: _handleAnchorsChanged,
              selectedSlotId: _overlay.selectedFieldCard == null
                  ? null
                  : fieldSlotId(_overlay.selectedFieldCard!),
              selectableSlotIds: _selectN.inlineSelectableFieldKeys,
              checkedSlotIds: _selectN.inlineSelectedFieldKeys,
              placeTargetSlotIds: _select.placeTargetFieldKeys,
              confirmedSlotIds: _confirm.confirmedFieldSlotKeys,
              activatableZoneKeys: ref.watch(activatableZoneKeysProvider),
              deckShuffleTick: _board.deckShuffleTick,
              deckShufflePlayer: _board.deckShufflePlayer,
              extraShuffleTick: _board.extraShuffleTick,
              extraShufflePlayer: _board.extraShufflePlayer,
              onPlaceSlotTap: _selectN.respondSelectPlaceKey,
            ),
            _buildOpponentHandBar(bodyStackAncestor, opponentHandTop),
            _buildPhaseMenu(
              hasFieldAnchors,
              phaseRect,
              overlayAnchor,
              phaseActionEntries,
            ),
            _buildFieldMenu(fieldRect, overlayAnchor, fieldActionEntries),
            _buildSelfHandBar(
              bodyStackAncestor,
              handActionEntries,
              selectPromptMode,
            ),
            if (_activeDrawEvent != null)
              _buildDrawAnimationLayer(
                viewport,
                opponentHandTop,
                _activeDrawEvent!,
              ),
            if (_activeAttack != null)
              _buildAttackAnimationLayer(
                viewport,
                opponentHandTop,
                _activeAttack!,
              ),
            _buildCancelButton(),
            _buildHandShuffleButton(),
            _buildWaitingHint(),
            _buildHud(isMyTurn),
            if (zoneBrowserKey != null)
              _buildZoneBrowser(
                zoneBrowserKey,
                zoneBrowserEntries,
                zoneBrowserActions,
              ),
            if (selectPromptMode != SelectPromptMode.none)
              _buildSelectOverlay(selectPromptMode),
            if (_confirm.confirmPanel != null) _buildConfirmPanel(),
            if (_confirm.isFloatPreview) _buildFloatPreview(),
            if (selectPromptMode != SelectPromptMode.modal &&
                _confirm.confirmPanel == null)
              _buildChainOverlay(),
            if (_overlay.showInspector) _buildInspector(),
            _buildLogDrawer(),
            if (_showTurnOrderHint) _buildTurnOrderHint(),
          ],
        ),
      ),
    );
  }

  // ---- build 子层组装 ----

  Widget _buildOpponentHandBar(
    RenderBox? bodyStackAncestor,
    double opponentHandTop,
  ) {
    return Positioned(
      top: opponentHandTop,
      left: 0,
      right: 0,
      child: HandCardsBar(
        cardsVisible: false,
        handCodes: _board.opponentHand,
        cardRectsAncestor: bodyStackAncestor,
        shuffleTick: _board.handShufflePlayer == 1 - _board.myController
            ? _board.handShuffleTick
            : 0,
        onCardRectsChanged: (rects) => _oppHandCardRects = rects,
        isCardConcealed: _drawQueue.isNotEmpty
            ? (index) => _isDrawConcealed(index, false)
            : null,
        concealListenable: _drawController,
        highlightedSequences:
            _confirm.confirmedHandOwner != _board.myController &&
                _confirm.confirmedHandSequences.isNotEmpty
            ? _confirm.confirmedHandSequences
            : const {},
      ),
    );
  }

  Widget _buildPhaseMenu(
    bool hasFieldAnchors,
    Rect phaseRect,
    Aligned overlayAnchor,
    List<ActionMenuEntry> phaseActionEntries,
  ) {
    if (!hasFieldAnchors ||
        !_overlay.showPhaseMenu ||
        phaseActionEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned.fromRect(
      rect: phaseRect,
      child: PortalTarget(
        visible: true,
        anchor: overlayAnchor,
        portalFollower: PhaseActionMenu(actions: phaseActionEntries),
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildFieldMenu(
    Rect? fieldRect,
    Aligned overlayAnchor,
    List<ActionMenuEntry> fieldActionEntries,
  ) {
    if (fieldRect == null) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: fieldRect,
      child: PortalTarget(
        visible: fieldActionEntries.isNotEmpty,
        anchor: overlayAnchor,
        portalFollower: FieldActionPopover(actions: fieldActionEntries),
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSelfHandBar(
    RenderBox? bodyStackAncestor,
    List<ActionMenuEntry> handActionEntries,
    SelectPromptMode selectPromptMode,
  ) {
    // 观战者（非决斗位）没有「我方手牌」：双方手牌都应显示卡背。
    final isDuelist = ref.read(duelRoomProvider).selfType.isDuelist;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: HandCardsBar(
        cardsVisible: isDuelist,
        handCodes: _board.selfHand,
        cardRectsAncestor: bodyStackAncestor,
        shuffleTick: _board.handShufflePlayer == _board.myController
            ? _board.handShuffleTick
            : 0,
        onCardRectsChanged: (rects) => _selfHandCardRects = rects,
        isCardConcealed: _drawQueue.isNotEmpty
            ? (index) => _isDrawConcealed(index, true)
            : null,
        concealListenable: _drawController,
        selectedCardSequence: _overlay.selectedHandSequence,
        onCardTap: handleHandCardTap,
        overlayContent: handActionEntries.isEmpty
            ? null
            : HandActionPopover(actions: handActionEntries),
        overlayVisible:
            _overlay.selectedHandSequence != null &&
            handActionEntries.isNotEmpty,
        highlightedSequences:
            _confirm.confirmedHandOwner == _board.myController &&
                _confirm.confirmedHandSequences.isNotEmpty
            ? _confirm.confirmedHandSequences
            : selectPromptMode == SelectPromptMode.inline
            ? _selectN.inlineSelectableHandSequences
            : const {},
        checkedSequences: selectPromptMode == SelectPromptMode.inline
            ? _selectN.inlineSelectedHandSequences
            : const {},
      ),
    );
  }

  Widget _buildCancelButton() {
    return Positioned(
      bottom: 104,
      right: 16,
      child: Tooltip(
        message: '取消操作',
        child: IconButton.filled(
          onPressed: canCancelOperation ? cancelOperation : null,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }

  /// 洗切手牌按钮：本地重排己方手牌并播放抖动动画（纯展示层）。
  Widget _buildHandShuffleButton() {
    final canShuffle = _board.selfHand.length >= 2;
    return Positioned(
      bottom: 104,
      left: 16,
      child: Tooltip(
        message: '洗切手牌',
        child: IconButton.filled(
          onPressed: canShuffle ? _boardN.shuffleSelfHand : null,
          icon: const Icon(Icons.shuffle),
        ),
      ),
    );
  }

  Widget _buildWaitingHint() {
    return Positioned(
      bottom: 18,
      right: 16,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            _select.currentSelect?.player == _board.myController
                ? '等待你的操作'
                : '等待对手操作',
            style: const TextStyle(
              color: Color(0xFF8B9BB4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud(bool isMyTurn) {
    return DuelFieldHud(
      players: widget.players,
      isMyTurn: isMyTurn,
      onOpenZoneBrowser: openZoneBrowser,
    );
  }

  Widget _buildZoneBrowser(
    String zoneBrowserKey,
    List<ZoneBrowserCardEntry> zoneBrowserEntries,
    List<ActionMenuEntry> zoneBrowserActions,
  ) {
    return ZoneBrowserModal(
      zoneBrowserKey: zoneBrowserKey,
      cards: zoneBrowserEntries,
      selectedCardSequence: _overlay.selectedZoneBrowserSequence,
      onCardTap: inspectZoneBrowserCard,
      onClose: closeZoneBrowser,
      selectedActions: zoneBrowserActions,
      hiddenCount: ref.watch(zoneHiddenCountProvider(zoneBrowserKey)),
      cardNameBuilder: (code) =>
          _boardN.getCardInfo(code)?.name ?? 'Card #$code',
    );
  }

  Widget _buildSelectOverlay(SelectPromptMode selectPromptMode) {
    return Positioned.fill(
      child: DuelSelectOverlay(
        mode: selectPromptMode,
        onInspectCard: inspectCard,
      ),
    );
  }

  Widget _buildConfirmPanel() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _confirmN.dismissConfirmPanel(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.65),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: ConfirmCardsDialog(
              title: _confirm.confirmPanel!.title,
              codes: _confirm.confirmPanel!.codes,
              cardNameBuilder: (code) =>
                  _boardN.getCardInfo(code)?.name ?? 'Card #$code',
              onDismiss: () => _confirmN.dismissConfirmPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChainOverlay() {
    final showChain1 = ref.watch(ygoSettingsProvider).showChain1Animation;
    return Positioned.fill(
      child: IgnorePointer(
        child: ChainStackOverlay(
          chains: _board.chains,
          chainSealed: _board.chainSealed,
          showChain1Animation: showChain1,
          cardNameBuilder: (code) =>
              _boardN.getCardInfo(code)?.name ?? 'Card #$code',
        ),
      ),
    );
  }

  Widget _buildInspector() {
    final inspectedCardCode = _overlay.inspectedCardCode;
    final inspectedCardInfo = inspectedCardCode == null
        ? _overlay.inspectedCardInfo
        : _boardN.getCardInfo(inspectedCardCode) ?? _overlay.inspectedCardInfo;
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

  Widget _buildLogDrawer() {
    return Positioned(
      top: _logDrawerTop,
      right: 16,
      child: DuelLogDrawer(logs: _board.duelLogs),
    );
  }

  Widget _buildTurnOrderHint() {
    return Positioned.fill(
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
    );
  }

  Widget _buildAttackAnimationLayer(
    Size viewport,
    double opponentHandTop,
    BattlePresentation presentation,
  ) {
    return AttackAnimation(
      controller: _attackController,
      source: _attackSlotRect(viewport, presentation.attackerZoneKey),
      target: _attackTargetRect(viewport, opponentHandTop, presentation),
      cardVisual: _attackCardVisual(presentation),
    );
  }

  /// 场上卡槽矩形：优先用场地锚点，缺失时用 [fieldCardAnchor] 兜底。
  Rect _attackSlotRect(Size viewport, String slotId) {
    final anchored = _fieldAnchors?.slotRects[slotId];
    if (anchored != null) return anchored;
    final card = _board.fieldCards[slotId];
    if (card != null) {
      return Rect.fromCenter(
        center: fieldCardAnchor(viewport, card, _board.myController),
        width: 68,
        height: 96,
      );
    }
    return Rect.fromLTWH(
      viewport.width / 2 - 34,
      viewport.height / 2 - 48,
      68,
      96,
    );
  }

  /// 攻击动画终点：攻击怪兽时是对方怪兽卡槽，直接攻击时是被攻击玩家的手牌位置。
  Rect _attackTargetRect(
    Size viewport,
    double opponentHandTop,
    BattlePresentation presentation,
  ) {
    final defenderZoneKey = presentation.defenderZoneKey;
    if (defenderZoneKey != null) {
      return _attackSlotRect(viewport, defenderZoneKey);
    }
    // 直接攻击：飞向被攻击玩家的手牌位置（对方手牌在上，己方手牌在下）。
    final attackerController =
        int.tryParse(presentation.attackerZoneKey.split('_').first) ?? 0;
    final attackingSelf = attackerController == _board.myController;
    final targetCenter = attackingSelf
        ? Offset(viewport.width / 2, opponentHandTop + 48)
        : Offset(viewport.width / 2, viewport.height - 48);
    return Rect.fromCenter(center: targetCenter, width: 68, height: 96);
  }

  Widget _attackCardVisual(BattlePresentation presentation) {
    final code = _board.fieldCards[presentation.attackerZoneKey]?.code;
    if (code != null && code > 0) {
      return CardImage(code: code, width: 68, height: 96);
    }
    return Container(
      width: 68,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1B3A), Color(0xFF0A0B1E)],
        ),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.style, color: Color(0xFF00F0FF), size: 28),
      ),
    );
  }

  Widget _buildDrawAnimationLayer(
    Size viewport,
    double opponentHandTop,
    DrawAnimationEvent event,
  ) {
    final source = _drawSourceRect(viewport, opponentHandTop, event);
    final target = _drawTargetRect(viewport, opponentHandTop, event);
    final isSelf = event.player == _board.myController;
    final code = event.codes.isNotEmpty ? event.codes.first : 0;
    // 进度驱动的布局收敛到子组件，内部经 AnimatedBuilder 只重建自己，
    // 页面层不再随动画每帧 setState。
    return DrawCardAnimation(
      controller: _drawController,
      source: source,
      target: target,
      cardVisual: _drawCardVisual(code, isSelf, revealCard: event.revealCard),
    );
  }

  Rect _drawSourceRect(
    Size viewport,
    double opponentHandTop,
    DrawAnimationEvent event,
  ) {
    final isSelf = event.player == _board.myController;
    final deckKey = isSelf ? 'self_deck' : 'opp_deck';
    return _fieldAnchors?.slotRects[deckKey] ??
        Rect.fromLTWH(
          viewport.width / 2 - 32,
          isSelf ? viewport.height - 120 : opponentHandTop + 6,
          64,
          90,
        );
  }

  Rect _drawTargetRect(
    Size viewport,
    double opponentHandTop,
    DrawAnimationEvent event,
  ) {
    final isSelf = event.player == _board.myController;
    final handRects = isSelf ? _selfHandCardRects : _oppHandCardRects;
    final handCodes = isSelf ? _board.selfHand : _board.opponentHand;
    if (handCodes.isNotEmpty) {
      final targetIndex = isSelf ? handCodes.length - 1 : 0;
      final targetRect = handRects[targetIndex];
      if (targetRect != null) return targetRect;
    }
    if (isSelf) {
      return Rect.fromLTWH(
        viewport.width - 64 - 12,
        viewport.height - 96,
        64,
        90,
      );
    }
    return Rect.fromLTWH(12, opponentHandTop + 6, 64, 90);
  }

  Widget _drawCardVisual(int code, bool isSelf, {required bool revealCard}) {
    if (isSelf || revealCard) {
      return CardImage(code: code, width: 64, height: 90);
    }
    return Container(
      width: 64,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1B3A), Color(0xFF0A0B1E)],
        ),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.style, color: Color(0xFF00F0FF), size: 28),
      ),
    );
  }

  Widget _buildFloatPreview() {
    final isSelf = _confirm.floatPreviewOwner == _board.myController;
    final zoneKey = _confirm.floatPreviewIsExtra
        ? (isSelf ? 'self_extra' : 'opp_extra')
        : (isSelf ? 'self_deck' : 'opp_deck');
    final zoneRect = _fieldAnchors?.slotRects[zoneKey];

    double? top, bottom, left, right;
    if (zoneRect != null) {
      // 夹取到 >= 0，避免预览卡片飘出可视区域（锚点贴近屏幕边缘时）。
      top = math.max(0.0, zoneRect.top - 200);
      left = math.max(0.0, zoneRect.center.dx - 75);
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
        codes: _confirm.floatPreviewCodes,
        // 当前展示下标由 notifier 计时推进（每卡 750ms + 500ms），
        // 组件自身不再持有自动关闭时序。
        currentIndex: _confirm.floatPreviewIndex,
        title: _confirm.floatPreviewIsExtra ? '额外卡组顶部' : '卡组顶部',
        cardNameBuilder: (code) =>
            _boardN.getCardInfo(code)?.name ?? 'Card #$code',
        onDismiss: () => _confirmN.dismissConfirmPanel(),
      ),
    );
  }

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
    console.log(
      'inspectCard: code=$code, info=${_overlay.inspectedCardInfo?.name}',
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
    console.log(
      'handleFieldCardTap: card='
      '${fieldCard == null ? 'null' : 'code=${fieldCard.code} c=${fieldCard.controller} z=${fieldCard.zone} s=${fieldCard.sequence} pos=${fieldCard.position}'} '
      'actions=[${actions.map((action) => '${action.kind.name}:${action.response}:c=${action.controller}:z=${action.location}:s=${action.sequence}:code=${action.code}').join(', ')}]',
    );
    _overlayN.applyFieldCardSelection(
      fieldCard == null || actions.isEmpty ? null : fieldCard,
    );
  }

  bool get canCancelOperation =>
      _overlay.hasAnyOverlayOpen ||
      _overlay.showInspector ||
      _select.inlineSelectedCount > 0;

  void cancelOperation() {
    // 就地选择窗口优先：先清空已勾选的卡（等价「取消本次点选」），
    // 不放弃整个选择窗口。
    if (_select.inlineSelectedCount > 0) {
      _selectN.clearInlineSelection();
      return;
    }
    // 关闭全部本地浮层（手牌/场上/区域浏览器/阶段菜单）与检视抽屉。
    _overlayN.clearLocalUi();
    if (_overlay.showInspector) _overlayN.dismissInspector();
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
