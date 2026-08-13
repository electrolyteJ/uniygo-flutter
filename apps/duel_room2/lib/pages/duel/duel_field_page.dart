import 'dart:ui';


import 'package:biz/service_providers.dart';
import 'package:duel_room2/pages/duel/widgets/field/playmat_anchor_data.dart';
import 'package:duel_room2/pages/duel/widgets/field/playmat_field_view_data.dart';
import 'package:duel_room2/pages/duel/widgets/field/prototype_playmat_field.dart';
import 'package:duel_room2/pages/duel/widgets/hud/hand_cards_bar.dart';
import 'package:duel_room2/pages/duel/widgets/hud/phase_bar.dart';
import 'package:duel_room2/pages/duel/widgets/hud/player_status_card.dart';
import 'package:duel_room2/pages/duel/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room2/pages/duel/widgets/inspector/duel_log_drawer.dart';
import 'package:duel_room2/pages/duel/widgets/inspector/zone_browser_modal.dart';
import 'package:duel_room2/pages/duel/widgets/menus/duel_field_popover_layout.dart' hide fieldSlotId;
import 'package:duel_room2/pages/duel/widgets/menus/field_action_popover.dart';
import 'package:duel_room2/pages/duel/widgets/menus/hand_action_popover.dart';
import 'package:duel_room2/pages/duel/widgets/menus/phase_action_menu.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/announce_card_dialog.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/card_selector.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/chain_stack_overlay.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/confirm_cards_dialog.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/confirm_floating_card.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/position_selector.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/select_prompt_layer.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/turn_order_hint.dart';
import 'package:duel_room2/pages/duel/widgets/overlay/yes_no_dialog.dart';
import 'package:duel_room2/widgets/card_image.dart';
import 'package:duelink/duelink.dart' show PlayerType, PlayerInfo;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../duel_room_state.dart';
import 'card_confirm_state.dart';
import 'duel_field_state.dart';
import 'duel_field_controller.dart';
import 'field_overlay_state.dart';
import 'models/draw_animation_event.dart';
import 'models/duel_menu.dart';
import 'models/field_card.dart';
import 'models/field_zone_key.dart';
import 'models/select_state.dart';
import 'select_window_state.dart';

import '../duel_room_exit.dart';

/// 决斗场地页：负责 store 接线与整体布局。
///
/// 与 duel_room1 的差异：
/// - 状态读取从 `context.watch<DuelFieldStore>()` 改为直连 watch 四个子状态
///   provider（duelField / selectWindow / cardConfirm / fieldOverlay），
///   任一变更即重建，语义等价原 ChangeNotifier 的全量 notifyListeners；
///   写单状态直连对应 Notifier，跨状态交互经
///   `ref.read(duelFieldControllerProvider)` 取控制器调用；
/// - 先后攻提示从手动 addListener 兜底改为 `ref.listen(isFirstTurn)`；
/// - Flame 渲染分支与 RenderModeToggle 不实现，场地固定为
///   [PrototypePlaymatField]（Flutter 原型渲染）。
///
/// 选择/检视/菜单等交互状态由四个子状态持有，[DuelFieldController]
/// 只做跨状态编排；弹层几何计算见 duel_field_popover_layout.dart。
class DuelFieldPage extends ConsumerStatefulWidget {
  final List<PlayerInfo> players;
  const DuelFieldPage(this.players, {super.key});

  @override
  ConsumerState<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends ConsumerState<DuelFieldPage>
    with SingleTickerProviderStateMixin {
  static const double _topHudBodyHeight = 112.0;
  static const double _opponentHandGap = 10.0;
  static const double _inspectorTop = 124.0;
  static const double _logDrawerTop = 126.0;

  PlaymatAnchorData? _fieldAnchors;
  Map<int, Rect> _selfHandCardRects = const {};
  Map<int, Rect> _oppHandCardRects = const {};
  late final AnimationController _drawController;
  DrawAnimationEvent? _activeDrawEvent;
  int? _activeDrawEventId;

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
  SelectWindowNotifier get _selectN =>
      ref.read(selectWindowProvider.notifier);
  CardConfirmNotifier get _confirmN =>
      ref.read(cardConfirmProvider.notifier);
  FieldOverlayNotifier get _overlayN =>
      ref.read(fieldOverlayProvider.notifier);
  DuelFieldController get _controller =>
      ref.read(duelFieldControllerProvider);

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _drawController.addListener(_handleDrawAnimationTick);
    _drawController.addStatusListener(_handleDrawAnimationStatus);
    _scheduleTurnOrderHint();
  }

  @override
  void dispose() {
    _drawController.dispose();
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
    if (_activeDrawEvent?.id != _activeDrawEventId) return;
    if (!mounted) return;
    setState(() {
      _activeDrawEvent = null;
      _activeDrawEventId = null;
    });
  }

  void _handleDrawAnimationTick() {
    if (mounted) setState(() {});
  }

  void _playDrawAnimation(DrawAnimationEvent event) {
    if (!mounted) return;
    setState(() {
      _activeDrawEvent = event;
      _activeDrawEventId = event.id;
    });
    _drawController.forward(from: 0);
  }

  /// PhaseLamp 可点击的完整条件：
  /// 1. 当前是己方回合（对方回合不能点）
  /// 2. 当前窗口下有可用阶段动作
  bool _canTapPhaseLamp() =>
      _board.currentPlayer == _board.myController &&
      _controller.phaseActionsForCurrentWindow().isNotEmpty;

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

  Widget _buildBattlefield(PlaymatFieldViewData fieldViewData) {
    return PrototypePlaymatField(
      data: fieldViewData,
      phase: _board.phase,
      phaseLampEnabled: _canTapPhaseLamp(),
      onPhaseLampTap: _controller.togglePhaseMenu,
      onFieldCardTap: _controller.handleFieldCardTap,
      onZoneTap: _controller.handleZoneInspect,
      onAnchorsChanged: _handleAnchorsChanged,
      selectedSlotId: _overlay.selectedFieldCard == null
          ? null
          : fieldSlotId(_overlay.selectedFieldCard!),
      selectableSlotIds: _selectN.inlineSelectableFieldKeys,
      checkedSlotIds: _selectN.inlineSelectedFieldKeys,
      placeTargetSlotIds: _select.placeTargetFieldKeys,
      confirmedSlotIds: _confirm.confirmedFieldSlotKeys,
      onPlaceSlotTap: _selectN.respondSelectPlaceKey,
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
    final fallback = fieldCardAnchor(
      viewport,
      fieldCard,
      _board.myController,
    );
    return Rect.fromCenter(center: fallback, width: 68, height: 96);
  }

  Widget _buildTopHud(bool isMyTurn) {
    final mc = _board.myController;
    final selfName = widget.players
            .where((p) => p.pos == mc)
            .map((p) => p.name)
            .firstOrNull ??
        '我方';
    final oppName = widget.players
            .where((p) => p.pos == 1 - mc)
            .map((p) => p.name)
            .firstOrNull ??
        '对方';
    // 当前回合玩家的剩余时间
    final currentTurnPlayer = _board.currentPlayer;
    final turnTimeLeft = currentTurnPlayer == mc
        ? _board.selfTimeLeft
        : _board.opponentTimeLeft;
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
                      lp: _board.opponentLp,
                      lpDelta: _board.opponentLpDelta,
                      lpEventId: _board.opponentLpEventId,
                      isSelf: false,
                      isActiveTurn: !isMyTurn,
                      handCount: _board.opponentHand.length,
                      deckCount: _board.oppDeck,
                      extraCount: _board.oppExtra,
                      graveCount: _board.oppGrave,
                      removedCount: _board.oppRemoved,
                      onExtraTap: () => _controller.openZoneBrowser('opp_extra'),
                      onGraveTap: () => _controller.openZoneBrowser('opp_grave'),
                      onRemovedTap: () =>
                          _controller.openZoneBrowser('opp_removed'),
                    ),
                    const SizedBox(width: 16),
                    PhaseBar(
                      turnCount: _board.turnCount,
                      isMyTurn: isMyTurn,
                      leftTimeSeconds: turnTimeLeft,
                    ),
                    const SizedBox(width: 16),
                    PlayerStatusCard(
                      name: selfName,
                      lp: _board.selfLp,
                      lpDelta: _board.selfLpDelta,
                      lpEventId: _board.selfLpEventId,
                      isSelf: true,
                      isActiveTurn: isMyTurn,
                      handCount: _board.selfHand.length,
                      deckCount: _board.selfDeck,
                      extraCount: _board.selfExtra,
                      graveCount: _board.selfGrave,
                      removedCount: _board.selfRemoved,
                      onExtraTap: () =>
                          _controller.openZoneBrowser('self_extra'),
                      onGraveTap: () =>
                          _controller.openZoneBrowser('self_grave'),
                      onRemovedTap: () =>
                          _controller.openZoneBrowser('self_removed'),
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

  /// 把 select 子状态组装成 [SelectPromptLayer] 的纯 UI props，
  /// 选择响应（respondXxx）的分发全部收口在这里。
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
        final showConfirm = select != null &&
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
    final onInspectCard = _controller.inspectCard;
    switch (select.type) {
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectCard(sequences),
          onCancel: () => _selectN.respondSelectCard([]),
          onInspectCard: onInspectCard,
        );
      case SelectType.unselect:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectUnselectCard(
            sequences.isEmpty ? null : sequences.first,
          ),
          onCancel: () => _selectN.respondSelectUnselectCard(null),
          onInspectCard: onInspectCard,
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectChain(
            sequences.isNotEmpty ? sequences.first : -1,
          ),
          onCancel: () => _selectN.respondSelectChain(-1),
          onInspectCard: onInspectCard,
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              _selectN.respondSelectPosition(position),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
          onInspectCard: onInspectCard,
          onYes: () => _selectN.respondSelectEffectYn(true),
          onNo: () => _selectN.respondSelectEffectYn(false),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
          onInspectCard: onInspectCard,
          onYes: () => _selectN.respondSelectYesNo(true),
          onNo: () => _selectN.respondSelectYesNo(false),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
          ),
          onCancel: () => _selectN.respondSelectOption(0),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceCard:
        return AnnounceCardDialog(
          onSearch: _selectN.searchAnnounceCards,
          onSelect: _selectN.respondAnnounceCard,
          onInspectCard: onInspectCard,
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectSum(sequences),
          onCancel: () => _selectN.respondSelectSum([]),
          onInspectCard: onInspectCard,
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectCounter(sequences),
          onCancel: () => _selectN.respondSelectCounter([]),
          onInspectCard: onInspectCard,
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) => _selectN.respondSortCard(sequences),
          onCancel: () => _selectN.respondSortCard([]),
          onInspectCard: onInspectCard,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 先后攻信息迟到时的兜底：值从 null 变为非 null 时弹出提示。
    ref.listen(duelRoomProvider.select((s) => s.isFirstTurn), (prev, next) {
      if (next == null) return;
      if (ref.read(duelRoomProvider).selfType == PlayerType.observer) return;
      _revealTurnOrderHint(next);
    });
    ref.listen(
      duelFieldProvider.select((s) => s.drawAnimationEvent),
      (prev, next) {
        if (next == null) return;
        if (next.id == _activeDrawEventId) {
          if (_activeDrawEvent != next) {
            setState(() => _activeDrawEvent = next);
          }
          return;
        }
        _playDrawAnimation(next);
      },
    );

    // 任一子状态变更都触发重建（等价原 ChangeNotifier 全量通知），
    // 读取经上方的 _board/_select/_confirm/_overlay getter，
    // 跨状态交互经 _controller，方法调用不依赖 watch。
    ref.watch(duelFieldProvider);
    ref.watch(selectWindowProvider);
    ref.watch(cardConfirmProvider);
    ref.watch(fieldOverlayProvider);
    final inspectedCardCode = _overlay.inspectedCardCode;
    final inspectedCardInfo = inspectedCardCode == null
        ? _overlay.inspectedCardInfo
        : _boardN.getCardInfo(inspectedCardCode) ??
            _overlay.inspectedCardInfo;
    final isMyTurn =
        _board.currentPlayer == _board.myController;
    final fieldViewData = _buildFieldViewData();
    if (_controller.needsHigherPriorityDismiss) {
      // build 期间不能改状态，推迟到帧末让本地弹层让位。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlayN.clearLocalUi();
      });
    }
    final zoneBrowserKey = _overlay.openZoneBrowserKey;
    final zoneBrowserEntries = zoneBrowserKey == null
        ? const <ZoneBrowserCardEntry>[]
        : _controller.zoneBrowserEntriesFor(zoneBrowserKey);
    final zoneBrowserActions = zoneBrowserKey == null
        ? const <ActionMenuEntry>[]
        : _controller.zoneBrowserActionsForSelection(
            zoneBrowserKey,
            zoneBrowserEntries,
          );
    final handActionEntries = _controller.buildHandActionMenuEntries();
    final phaseActionEntries = _controller.buildPhaseActionMenuEntries();
    final fieldActionEntries = _controller.buildFieldActionEntries();
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
    return Scaffold(
      backgroundColor: const Color(0xFF010308),
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildBattlefield(fieldViewData)),
          Positioned(
            top: opponentHandTop,
            left: 0,
            right: 0,
            child: HandCardsBar(
              cardsVisible: false,
              handCodes: _board.opponentHand,
              onCardRectsChanged: (rects) {
                _oppHandCardRects = rects;
              },
              highlightedSequences:
                  _confirm.confirmedHandOwner != _board.myController &&
                      _confirm.confirmedHandSequences.isNotEmpty
                  ? _confirm.confirmedHandSequences
                  : const {},
            ),
          ),

          if (hasFieldAnchors &&
              _overlay.showPhaseMenu &&
              phaseActionEntries.isNotEmpty)
            Positioned.fromRect(
              rect: phaseRect,
              child: PortalTarget(
                visible: true,
                anchor: overlayAnchor,
                portalFollower: PhaseActionMenu(actions: phaseActionEntries),
                child: const SizedBox.shrink(),
              ),
            ),
          if (fieldRect != null)
            Positioned.fromRect(
              rect: fieldRect,
              child: PortalTarget(
                visible: fieldActionEntries.isNotEmpty,
                anchor: overlayAnchor,
                portalFollower:
                    FieldActionPopover(actions: fieldActionEntries),
                child: const SizedBox.shrink(),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: HandCardsBar(
              handCodes: _board.selfHand,
              onCardRectsChanged: (rects) {
                _selfHandCardRects = rects;
              },
              selectedCardSequence: _overlay.selectedHandSequence,
              onCardTap: _controller.handleHandCardTap,
              overlayContent: handActionEntries.isEmpty
                  ? null
                  : HandActionPopover(actions: handActionEntries),
              overlayVisible: _overlay.selectedHandSequence != null &&
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
          ),
          if (_activeDrawEvent != null)
            _buildDrawAnimationLayer(
              viewport,
              opponentHandTop,
              _activeDrawEvent!,
            ),
          Positioned(
            bottom: 104,
            right: 16,
            child: Tooltip(
              message: '取消操作',
              child: IconButton.filled(
                onPressed: _controller.canCancelFieldCardSelection
                    ? _controller.cancelFieldCardSelection
                    : null,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            right: 16,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  _select.currentSelect?.player ==
                          _board.myController
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
          ),
          _buildTopHud(isMyTurn),
          if (zoneBrowserKey != null)
            ZoneBrowserModal(
              zoneBrowserKey: zoneBrowserKey,
              cards: zoneBrowserEntries,
              selectedCardSequence:
                  _overlay.selectedZoneBrowserSequence,
              onCardTap: _controller.inspectZoneBrowserCard,
              onClose: _controller.closeZoneBrowser,
              selectedActions: zoneBrowserActions,
              hiddenCount:
                  _controller.hiddenCountForZoneKey(zoneBrowserKey),
              cardNameBuilder: (code) =>
                  _boardN.getCardInfo(code)?.name ?? 'Card #$code',
            ),
          if (selectPromptMode != SelectPromptMode.none)
            Positioned.fill(
              child: _buildSelectPromptLayer(selectPromptMode),
            ),
          if (_confirm.confirmPanel != null)
            Positioned.fill(
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
                          _boardN.getCardInfo(code)?.name ??
                          'Card #$code',
                      onDismiss: () => _confirmN.dismissConfirmPanel(),
                    ),
                  ),
                ),
              ),
            ),
          if (_confirm.isFloatPreview) _buildFloatPreview(),
          if (selectPromptMode != SelectPromptMode.modal &&
              _confirm.confirmPanel == null)
            Positioned.fill(
              child: IgnorePointer(
                child: ChainStackOverlay(
                  chains: _board.chains,
                  chainSealed: _board.chainSealed,
                  cardNameBuilder: (code) =>
                      _boardN.getCardInfo(code)?.name ?? 'Card #$code',
                ),
              ),
            ),
          if (_overlay.showInspector)
            Positioned(
              left: 18,
              top: _inspectorTop,
              bottom: 160,
              child: CardDetailDrawer(
                cardInfo: inspectedCardInfo,
                cardCode: inspectedCardCode,
                onClose: _overlayN.dismissInspector,
              ),
            ),
          Positioned(
            top: _logDrawerTop,
            right: 16,
            child: DuelLogDrawer(logs: _board.duelLogs),
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
      ),
    );
  }

  Widget _buildDrawAnimationLayer(
    Size viewport,
    double opponentHandTop,
    DrawAnimationEvent event,
  ) {
    final progress = Curves.easeOutCubic.transform(_drawController.value);
    final source = _drawSourceRect(viewport, opponentHandTop, event);
    final target = _drawTargetRect(viewport, opponentHandTop, event);
    final rect = Rect.lerp(source, target, progress)!;
    final isSelf = event.player == _board.myController;
    final code = event.codes.isNotEmpty ? event.codes.first : 0;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: 1.0 - progress * 0.15,
          child: _drawCardVisual(
            code,
            isSelf,
            revealCard: event.revealCard,
          ),
        ),
      ),
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
    return Rect.fromLTWH(
      12,
      opponentHandTop + 6,
      64,
      90,
    );
  }

  Widget _drawCardVisual(
    int code,
    bool isSelf, {
    required bool revealCard,
  }) {
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
        codes: _confirm.floatPreviewCodes,
        title: _confirm.floatPreviewIsExtra ? '额外卡组顶部' : '卡组顶部',
        cardNameBuilder: (code) =>
            _boardN.getCardInfo(code)?.name ?? 'Card #$code',
        onDismiss: () => _confirmN.dismissConfirmPanel(),
        autoCloseSeconds: 0.75,
      ),
    );
  }
}
