import 'dart:ui';

import 'package:duelink/duelink.dart' show PlayerType, PlayerInfo;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:provider/provider.dart';

import '../../../models/FieldCard.dart';
import '../../../models/duel_menu.dart';
import '../../../service_singleton.dart';
import '../../../widgets/duel_room/overlay/chain_stack_overlay.dart';
import '../../../widgets/duel_room/inspector/duel_log_drawer.dart';
import '../../../widgets/duel_room/field/duel_flame_game.dart';
import '../../../widgets/duel_room/menus/field_action_popover.dart';
import '../../../widgets/duel_room/menus/hand_action_popover.dart';
import '../../../widgets/duel_room/field/flame_playmat_field.dart';
import '../../../widgets/duel_room/field/prototype_playmat_field.dart';
import '../../../widgets/duel_room/hud/hand_cards_bar.dart';
import '../../../widgets/duel_room/inspector/card_detail_drawer.dart';
import '../../../widgets/duel_room/inspector/zone_browser_modal.dart';
import '../../../widgets/duel_room/menus/phase_action_menu.dart';
import '../../../widgets/duel_room/hud/phase_bar.dart';
import '../../../widgets/duel_room/hud/player_status_card.dart';
import '../../../widgets/duel_room/hud/render_mode_toggle.dart';
import '../../../widgets/duel_room/field/playmat_anchor_data.dart';
import '../../../widgets/duel_room/field/playmat_field_view_data.dart';
import '../../../widgets/duel_room/overlay/select_prompt_layer.dart';
import '../duel_room_exit.dart';
import '../duel_room_store.dart';
import 'duel_field_store.dart';
import '../../../widgets/duel_room/menus/duel_field_popover_layout.dart';
import '../../../models/SelectState.dart';
import '../../../widgets/duel_room/overlay/card_selector.dart';
import '../../../widgets/duel_room/overlay/confirm_cards_dialog.dart';
import '../../../widgets/duel_room/overlay/announce_card_dialog.dart';
import '../../../widgets/duel_room/overlay/position_selector.dart';
import '../../../widgets/duel_room/overlay/turn_order_hint.dart';
import '../../../widgets/duel_room/overlay/yes_no_dialog.dart';

/// 决斗场地页：负责 store 接线、Flame 游戏生命周期与整体布局。
/// 选择/检视/菜单等交互状态由 [DuelFieldStore] 直接持有，
/// 弹层几何计算见 duel_field_popover_layout.dart。
class DuelFieldPage extends StatefulWidget {
  final List<PlayerInfo> players;
  const DuelFieldPage(this.players, {super.key});

  @override
  State<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends State<DuelFieldPage> {
  static const double _topHudBodyHeight = 112.0;
  static const double _opponentHandGap = 10.0;
  static const double _inspectorTop = 124.0;
  static const double _logDrawerTop = 126.0;

  late final DuelFieldStore duelStore;

  DuelFlameGame? _flameGame;
  PlaymatAnchorData? _fieldAnchors;
  PlaymatRenderMode _renderMode = PlaymatRenderMode.flame;

  // 先后攻提示：进入场地页时居中短暂展示一次。
  bool _showTurnOrderHint = false;
  bool _isFirstTurn = false;

  @override
  void initState() {
    super.initState();
    duelStore = context.read<DuelFieldStore>();
    _scheduleTurnOrderHint();
  }

  /// 进入场地页后读取先后攻信息，居中弹出一次提示。
  /// 观战者不提示；信息尚未到达时挂一次监听兜底。
  void _scheduleTurnOrderHint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final roomStore = context.read<DuelRoomStore>();
      if (roomStore.selfType == PlayerType.observer) return;
      final isFirst = roomStore.isFirstTurn;
      if (isFirst != null) {
        _revealTurnOrderHint(isFirst);
        return;
      }
      void onChanged() {
        if (!mounted) return;
        final v = roomStore.isFirstTurn;
        if (v != null) {
          roomStore.removeListener(onChanged);
          _revealTurnOrderHint(v);
        }
      }

      roomStore.addListener(onChanged);
    });
  }

  void _revealTurnOrderHint(bool isFirst) {
    if (!mounted || _showTurnOrderHint) return;
    _isFirstTurn = isFirst;
    ServiceSingleton.instance.uiSoundService.playTurnHint();
    setState(() => _showTurnOrderHint = true);
  }

  // ---- Flame 渲染模式 ----

  /// PhaseLamp 可点击的完整条件：
  /// 1. 当前是己方回合（对方回合不能点）
  /// 2. 当前窗口下有可用阶段动作
  bool _canTapPhaseLamp() =>
      duelStore.currentPlayer == duelStore.myController &&
      duelStore.phaseActionsForCurrentWindow().isNotEmpty;

  DuelFlameGame _ensureFlameGame() {
    return _flameGame ??= DuelFlameGame(
      duelStore: duelStore,
      onCardSelect: duelStore.handleFieldCardTap,
      onZoneInspect: duelStore.handleZoneInspect,
      onPhaseLampTap: duelStore.togglePhaseMenu,
      isPhaseLampEnabled: _canTapPhaseLamp,
      onAnchorsChanged: _handleAnchorsChanged,
    );
  }

  void _handleRenderModeChanged(PlaymatRenderMode mode) {
    if (_renderMode == mode) return;
    setState(() {
      _fieldAnchors = null;
      _flameGame = mode == PlaymatRenderMode.flame ? null : _flameGame;
      _renderMode = mode;
    });
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

  PlaymatFieldViewData _buildFieldViewData() {
    return PlaymatFieldViewData(
      fieldCards: Map<String, FieldCard>.from(duelStore.fieldCards),
      selfController: duelStore.myController,
      opponentController: 1 - duelStore.myController,
      selfDeckCount: duelStore.selfDeck,
      selfExtraCount: duelStore.selfExtra,
      selfGraveCount: duelStore.selfGrave,
      selfRemovedCount: duelStore.selfRemoved,
      oppDeckCount: duelStore.oppDeck,
      oppExtraCount: duelStore.oppExtra,
      oppGraveCount: duelStore.oppGrave,
      oppRemovedCount: duelStore.oppRemoved,
    );
  }

  Widget _buildBattlefield(PlaymatFieldViewData fieldViewData) {
    switch (_renderMode) {
      case PlaymatRenderMode.prototype:
        return PrototypePlaymatField(
          data: fieldViewData,
          phase: duelStore.phase,
          phaseLampEnabled: _canTapPhaseLamp(),
          onPhaseLampTap: duelStore.togglePhaseMenu,
          onFieldCardTap: duelStore.handleFieldCardTap,
          onZoneTap: duelStore.handleZoneInspect,
          onAnchorsChanged: _handleAnchorsChanged,
          selectedSlotId: duelStore.selectedFieldCard == null
              ? null
              : fieldSlotId(duelStore.selectedFieldCard!),
          selectableSlotIds: duelStore.inlineSelectableFieldKeys,
          checkedSlotIds: duelStore.inlineSelectedFieldKeys,
          placeTargetSlotIds: duelStore.placeTargetFieldKeys,
          onPlaceSlotTap: duelStore.respondSelectPlaceKey,
        );
      case PlaymatRenderMode.flame:
        return FlamePlaymatField(
          game: _ensureFlameGame(),
          onAnchorsChanged: _handleAnchorsChanged,
        );
    }
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
      duelStore.myController,
    );
    return Rect.fromCenter(center: fallback, width: 68, height: 96);
  }

  Widget _buildTopHud(bool isMyTurn) {
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
                    name: '海马濑人',
                    lp: duelStore.opponentLp,
                    lpDelta: duelStore.opponentLpDelta,
                    lpEventId: duelStore.opponentLpEventId,
                    isSelf: false,
                    isActiveTurn: !isMyTurn,
                    handCount: duelStore.opponentHand.length,
                    deckCount: duelStore.oppDeck,
                    extraCount: duelStore.oppExtra,
                    graveCount: duelStore.oppGrave,
                    removedCount: duelStore.oppRemoved,
                    onExtraTap: () => duelStore.openZoneBrowser('opp_extra'),
                    onGraveTap: () => duelStore.openZoneBrowser('opp_grave'),
                    onRemovedTap: () =>
                        duelStore.openZoneBrowser('opp_removed'),
                  ),
                  const SizedBox(width: 16),
                  PhaseBar(
                    turnCount: duelStore.turnCount,
                    isMyTurn: isMyTurn,
                  ),
                  const SizedBox(width: 16),
                  PlayerStatusCard(
                    name: '武藤游戏',
                    lp: duelStore.selfLp,
                    lpDelta: duelStore.selfLpDelta,
                    lpEventId: duelStore.selfLpEventId,
                    isSelf: true,
                    isActiveTurn: isMyTurn,
                    handCount: duelStore.selfHand.length,
                    deckCount: duelStore.selfDeck,
                    extraCount: duelStore.selfExtra,
                    graveCount: duelStore.selfGrave,
                    removedCount: duelStore.selfRemoved,
                    onExtraTap: () => duelStore.openZoneBrowser('self_extra'),
                    onGraveTap: () => duelStore.openZoneBrowser('self_grave'),
                    onRemovedTap: () =>
                        duelStore.openZoneBrowser('self_removed'),
                  ),
                  ],
                ),
              ),
            ),
            RenderModeToggle(
              mode: _renderMode,
              onChanged: _handleRenderModeChanged,
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

  /// 把 store 的选择态组装成 [SelectPromptLayer] 的纯 UI props，
  /// 选择响应（respondXxx）的分发全部收口在这里。
  Widget _buildSelectPromptLayer(
    DuelFieldStore duelFieldStore,
    SelectPromptMode mode,
  ) {
    final select = duelFieldStore.currentSelect;
    switch (mode) {
      case SelectPromptMode.none:
        return const SizedBox.shrink();
      case SelectPromptMode.place:
        return SelectPromptLayer(
          mode: mode,
          placeTargetCount: duelFieldStore.placeTargetFieldKeys.length,
        );
      case SelectPromptMode.inline:
        // 多选（非单张、非连锁、非解除选择）才需要本地确认按钮。
        final showConfirm = select != null &&
            select.type != SelectType.chain &&
            select.type != SelectType.unselect &&
            !(select.min == 1 && select.max == 1);
        return SelectPromptLayer(
          mode: mode,
          inlineHint: duelFieldStore.inlineSelectHint,
          inlineCancelLabel: select?.cancelable == true
              ? (select!.type == SelectType.chain ? '不连锁' : '取消')
              : null,
          inlineShowFinish:
              select?.type == SelectType.unselect && select!.finishable,
          inlineShowConfirm: showConfirm,
          inlineCanConfirm: duelFieldStore.inlineSelectCanConfirm,
          onInlineCancel: duelFieldStore.cancelInlineSelect,
          onInlineFinish: duelFieldStore.finishInlineUnselect,
          onInlineConfirm: duelFieldStore.confirmInlineSelect,
        );
      case SelectPromptMode.modal:
        return SelectPromptLayer(
          mode: mode,
          modalChild:
              select == null ? null : _buildSelectModal(duelFieldStore, select),
        );
    }
  }

  /// 模态选择弹窗：选项落在不可直接点击的区域的回退，
  /// 以及排序/计数器/效果选项等复杂交互。
  Widget _buildSelectModal(DuelFieldStore duelFieldStore, SelectState select) {
    final onInspectCard = duelFieldStore.inspectCard;
    switch (select.type) {
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              duelFieldStore.respondSelectPosition(position),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
          onInspectCard: onInspectCard,
          onYes: () => duelFieldStore.respondSelectEffectYn(true),
          onNo: () => duelFieldStore.respondSelectEffectYn(false),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
          onInspectCard: onInspectCard,
          onYes: () => duelFieldStore.respondSelectYesNo(true),
          onNo: () => duelFieldStore.respondSelectYesNo(false),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelFieldStore.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
          ),
          onCancel: () => duelFieldStore.respondSelectOption(0),
          onInspectCard: onInspectCard,
        );
      case SelectType.announceCard:
        return AnnounceCardDialog(
          onSearch: duelFieldStore.searchAnnounceCards,
          onSelect: duelFieldStore.respondAnnounceCard,
          onInspectCard: onInspectCard,
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              duelFieldStore.respondSelectCounter(sequences),
          onCancel: () => duelFieldStore.respondSelectCounter([]),
          onInspectCard: onInspectCard,
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelFieldStore.respondSortCard(sequences),
          onCancel: () => duelFieldStore.respondSortCard([]),
          onInspectCard: onInspectCard,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duelFieldStore = context.watch<DuelFieldStore>();
    final inspectedCardCode = duelFieldStore.inspectedCardCode;
    final inspectedCardInfo = inspectedCardCode == null
        ? duelFieldStore.inspectedCardInfo
        : duelFieldStore.getCardInfo(inspectedCardCode) ??
              duelFieldStore.inspectedCardInfo;
    final isMyTurn =
        duelFieldStore.currentPlayer == duelFieldStore.myController;
    final fieldViewData = _buildFieldViewData();
    if (duelFieldStore.needsHigherPriorityDismiss) {
      // build 期间不能改状态，推迟到帧末让本地弹层让位。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) duelFieldStore.clearLocalUi();
      });
    }
    final zoneBrowserKey = duelFieldStore.openZoneBrowserKey;
    final zoneBrowserEntries = zoneBrowserKey == null
        ? const <ZoneBrowserCardEntry>[]
        : duelFieldStore.zoneBrowserEntriesFor(zoneBrowserKey);
    final zoneBrowserActions = zoneBrowserKey == null
        ? const <ActionMenuEntry>[]
        : duelFieldStore.zoneBrowserActionsForSelection(
            zoneBrowserKey,
            zoneBrowserEntries,
          );
    final handActionEntries = duelFieldStore.buildHandActionMenuEntries();
    final phaseActionEntries = duelFieldStore.buildPhaseActionMenuEntries();
    final fieldActionEntries = duelFieldStore.buildFieldActionEntries();
    // 选择提示统一由 SelectPromptLayer 收口：呈现方式（放置横幅/就地操作栏/
    // 模态弹窗）由 store 判定，页面只区分 none 与 modal（modal 期间隐藏连锁叠层）。
    final selectPromptMode = duelFieldStore.selectPromptMode;
    final topInset = MediaQuery.of(context).padding.top;
    final opponentHandTop = topInset + _topHudBodyHeight + _opponentHandGap;
    // viewport 仅用于 anchors 缺失时的 fallback 比例估算；
    // 弹层定位与避让统一由全局 Portal 的 Aligned 锚点负责。
    final viewport = MediaQuery.sizeOf(context);
    final hasFieldAnchors = _fieldAnchors != null;
    final phaseRect = _phaseLampRect(viewport);
    final selectedFieldCard = duelFieldStore.selectedFieldCard;
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
              handCodes: duelFieldStore.opponentHand,
            ),
          ),

          if (hasFieldAnchors &&
              duelFieldStore.showPhaseMenu &&
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
                portalFollower: FieldActionPopover(actions: fieldActionEntries),
                child: const SizedBox.shrink(),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: HandCardsBar(
              handCodes: duelFieldStore.selfHand,
              selectedCardSequence: duelFieldStore.selectedHandSequence,
              onCardTap: duelFieldStore.handleHandCardTap,
              overlayContent: handActionEntries.isEmpty
                  ? null
                  : HandActionPopover(actions: handActionEntries),
              overlayVisible:
                  duelFieldStore.selectedHandSequence != null &&
                  handActionEntries.isNotEmpty,
              highlightedSequences:
                  selectPromptMode == SelectPromptMode.inline
                  ? duelFieldStore.inlineSelectableHandSequences
                  : const {},
              checkedSequences: selectPromptMode == SelectPromptMode.inline
                  ? duelFieldStore.inlineSelectedHandSequences
                  : const {},
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
                  duelFieldStore.currentSelect?.player ==
                          duelFieldStore.myController
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
              selectedCardSequence: duelFieldStore.selectedZoneBrowserSequence,
              onCardTap: duelFieldStore.inspectZoneBrowserCard,
              onClose: duelFieldStore.closeZoneBrowser,
              selectedActions: zoneBrowserActions,
              hiddenCount: duelFieldStore.hiddenCountForZoneKey(zoneBrowserKey),
              cardNameBuilder: (code) =>
                  duelFieldStore.getCardInfo(code)?.name ?? 'Card #$code',
            ),
          if (selectPromptMode != SelectPromptMode.none)
            Positioned.fill(
              child: _buildSelectPromptLayer(
                duelFieldStore,
                selectPromptMode,
              ),
            ),
          if (duelFieldStore.confirmCards != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ConfirmCardsDialog(
                    title: duelFieldStore.confirmCards!.title,
                    codes: duelFieldStore.confirmCards!.codes,
                    cardNameBuilder: (code) =>
                        duelFieldStore.getCardInfo(code)?.name ?? 'Card #$code',
                  ),
                ),
              ),
            ),
          if (selectPromptMode != SelectPromptMode.modal &&
              duelFieldStore.confirmCards == null)
            Positioned.fill(
              child: IgnorePointer(
                child: ChainStackOverlay(
                  chains: duelFieldStore.chains,
                  chainSealed: duelFieldStore.chainSealed,
                  cardNameBuilder: (code) =>
                      duelFieldStore.getCardInfo(code)?.name ?? 'Card #$code',
                ),
              ),
            ),
          if (duelFieldStore.showInspector)
            Positioned(
              left: 18,
              top: _inspectorTop,
              bottom: 160,
              child: CardDetailDrawer(
                cardInfo: inspectedCardInfo,
                cardCode: inspectedCardCode,
                onClose: duelFieldStore.dismissInspector,
              ),
            ),
          Positioned(
            top: _logDrawerTop,
            right: 16,
            child: DuelLogDrawer(logs: duelFieldStore.duelLogs),
          ),

          if (_showTurnOrderHint)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TurnOrderHint(
                    isFirst: _isFirstTurn,
                    onDismiss: () {
                      if (mounted) setState(() => _showTurnOrderHint = false);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
