import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/util/SnackBarUtil.dart';

import '../../../models/FieldCard.dart';
import '../../../widgets/duel_room/hud/chain_stack_overlay.dart';
import '../../../widgets/duel_room/hud/duel_log_drawer.dart';
import '../../../widgets/duel_room/field/duel_flame_game.dart';
import '../../../widgets/duel_room/menus/field_action_popover.dart';
import '../../../widgets/duel_room/field/flame_playmat_field.dart';
import '../../../widgets/duel_room/hud/phase_lamp.dart';
import '../../../widgets/duel_room/field/prototype_playmat_field.dart';
import '../../../widgets/duel_room/menus/hand_action_popover.dart';
import '../../../widgets/duel_room/hud/hand_cards_bar.dart';
import '../../../widgets/duel_room/inspector/card_detail_drawer.dart';
import '../../../widgets/duel_room/inspector/zone_browser_modal.dart';
import '../../../widgets/duel_room/hud/opponent_hand_fan.dart';
import '../../../widgets/duel_room/menus/phase_action_menu.dart';
import '../../../widgets/duel_room/hud/phase_bar.dart';
import '../../../widgets/duel_room/hud/player_status_card.dart';
import '../../../widgets/duel_room/field/playmat_anchor_data.dart';
import '../../../widgets/duel_room/field/playmat_field_view_data.dart';
import '../../../widgets/duel_room/field/playmat_render_mode.dart';
import '../../../widgets/shared/duel_room.dart';
import '../duel_room_store.dart';
import 'duel_field_store.dart';
import '../../../widgets/duel_room/hud/duel_field_background.dart';
import '../../../widgets/duel_room/menus/duel_field_popover_layout.dart';
import 'duel_field_controller.dart';
import '../../../models/SelectState.dart';
import '../../../widgets/duel_room/overlay/select_menu.dart';
import '../../../widgets/duel_room/overlay/battle_select_menu.dart';
import '../../../widgets/duel_room/overlay/card_selector.dart';
import '../../../widgets/duel_room/overlay/position_selector.dart';
import '../../../widgets/duel_room/overlay/yes_no_dialog.dart';

/// 决斗场地页：负责 store 接线、Flame 游戏生命周期与整体布局。
/// 选择/检视/菜单等交互状态全部委托给 [DuelFieldController]，
/// 弹层几何计算见 duel_field_popover_layout.dart。
class DuelFieldPage extends StatefulWidget {
  const DuelFieldPage({super.key});

  @override
  State<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends State<DuelFieldPage> {
  late final DuelFieldStore duelStore;
  late final DuelFieldController _ui;

  DuelFlameGame? _flameGame;
  PlaymatAnchorData? _fieldAnchors;
  PlaymatRenderMode _renderMode = PlaymatRenderMode.flame;

  @override
  void initState() {
    super.initState();
    duelStore = context.read<DuelFieldStore>();
    _ui = DuelFieldController(duelStore: duelStore)..addListener(_onUiChanged);
  }

  @override
  void dispose() {
    _ui.dispose();
    super.dispose();
  }

  void _onUiChanged() {
    if (mounted) setState(() {});
  }

  // ---- Flame 渲染模式 ----

  DuelFlameGame _ensureFlameGame() {
    return _flameGame ??= DuelFlameGame(
      duelStore: duelStore,
      onCardSelect: _ui.handleFieldCardTap,
      onZoneInspect: _ui.handleZoneInspect,
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
          onFieldCardTap: _ui.handleFieldCardTap,
          onZoneTap: _ui.handleZoneInspect,
          onAnchorsChanged: _handleAnchorsChanged,
          selectedSlotId: _ui.selectedFieldCard == null
              ? null
              : fieldSlotId(_ui.selectedFieldCard!),
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
    final fallback = Offset(viewport.width * 0.79, viewport.height * 0.57);
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

  @override
  Widget build(BuildContext context) {
    final duelState = context.watch<DuelRoomStore>();
    final duelStore = context.watch<DuelFieldStore>();
    final ui = _ui;
    final inspectedCardCode = ui.inspectedCardCode;
    final inspectedCardInfo = inspectedCardCode == null
        ? ui.inspectedCardInfo
        : duelStore.getCardInfo(inspectedCardCode) ?? ui.inspectedCardInfo;
    final isMyTurn = duelStore.currentPlayer == duelStore.myController;
    final fieldViewData = _buildFieldViewData();
    if (ui.needsHigherPriorityDismiss) {
      // build 期间不能改状态，推迟到帧末让本地弹层让位。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ui.clearLocalUi();
      });
    }
    final zoneBrowserKey = ui.openZoneBrowserKey;
    final zoneBrowserEntries = zoneBrowserKey == null
        ? const <ZoneBrowserCardEntry>[]
        : ui.zoneBrowserEntriesFor(zoneBrowserKey);
    final zoneBrowserActions = zoneBrowserKey == null
        ? const <ZoneBrowserActionEntry>[]
        : ui.zoneBrowserActionsForSelection(zoneBrowserKey, zoneBrowserEntries);
    final handActionEntries = ui.buildHandActionMenuEntries();
    final phaseActionEntries = ui.buildPhaseActionMenuEntries();
    final fieldActionEntries = ui.buildFieldActionEntries();

    return SafeArea(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFF010308),
            body: Stack(
              children: [
                const Positioned.fill(child: DuelFieldBackground()),

                // 内容层
                Column(
                  children: [
                    // 顶部阶段栏 (matches .header-bar)
                    PhaseBar(
                      renderMode: _renderMode,
                      onRenderModeChanged: _handleRenderModeChanged,
                    ),

                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final viewport = constraints.biggest;
                          final hasFieldAnchors = _fieldAnchors != null;
                          final phaseRect = _phaseLampRect(viewport);

                          final selectedHandSequence = ui.selectedHandSequence;
                          final handAnchor = selectedHandSequence == null
                              ? null
                              : handPopoverAnchor(
                                  viewport,
                                  duelStore.selfHand.length,
                                  selectedHandSequence,
                                  ui.selectedHandCardRect,
                                );
                          final handPlacement = handAnchor == null
                              ? null
                              : placePopoverAbove(
                                  viewport,
                                  anchorCenterX: handAnchor.dx,
                                  anchorTopY: handAnchor.dy,
                                );
                          final phasePlacement = placePopoverAbove(
                            viewport,
                            anchorCenterX: phaseRect.center.dx,
                            anchorTopY: phaseRect.top - 8,
                            horizontalOffset: 96,
                            showArrow: false,
                          );
                          final fieldCard = ui.selectedFieldCard;
                          final fieldRect = fieldCard == null
                              ? null
                              : _fieldCardRect(viewport, fieldCard);
                          final fieldPlacement = fieldRect == null
                              ? null
                              : placePopoverAbove(
                                  viewport,
                                  anchorCenterX: fieldRect.center.dx,
                                  anchorTopY: fieldRect.top - 8,
                                );

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                // v10: .field { margin-left:128px } —— 场地整体右移，
                                // 为左侧大卡图检视面板留出视觉平衡。
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 120),
                                  child: _buildBattlefield(fieldViewData),
                                ),
                              ),
                              if (ui.showInspector)
                                Positioned(
                                  left: 18,
                                  top: 0,
                                  bottom: 108,
                                  child: Center(
                                    child: CardDetailDrawer(
                                      cardInfo: inspectedCardInfo,
                                      cardCode: inspectedCardCode,
                                      onClose: ui.dismissInspector,
                                    ),
                                  ),
                                ),
                              // 给页面级返回按钮（top:8, left:8, 约 40px）让位
                              Positioned(
                                top: 14,
                                left: 60,
                                child: PlayerStatusCard(
                                  name: '海马濑人',
                                  lp: duelStore.opponentLp,
                                  isSelf: false,
                                  isActiveTurn: !isMyTurn,
                                  handCount: duelStore.opponentHand.length,
                                  deckCount: duelStore.oppDeck,
                                  extraCount: duelStore.oppExtra,
                                  graveCount: duelStore.oppGrave,
                                  removedCount: duelStore.oppRemoved,
                                  onExtraTap: () =>
                                      ui.openZoneBrowser('opp_extra'),
                                  onGraveTap: () =>
                                      ui.openZoneBrowser('opp_grave'),
                                  onRemovedTap: () =>
                                      ui.openZoneBrowser('opp_removed'),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                right: 16,
                                child: DuelLogDrawer(logs: duelState.duelLogs),
                              ),
                              Positioned(
                                top: 78,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: OpponentHandFan(
                                    count: duelStore.opponentHand.length,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ChainStackOverlay(
                                    chains: duelStore.chains,
                                  ),
                                ),
                              ),
                              // 渲染器 anchors 就绪前不显示 lamp，避免首帧/切换模式时位置跳变
                              if (hasFieldAnchors)
                                Positioned(
                                  left: phaseRect.left,
                                  top: phaseRect.top,
                                  child: PhaseLamp(
                                    phase: duelStore.phase,
                                    enabled: phaseActionEntries.isNotEmpty,
                                    onTap: ui.togglePhaseMenu,
                                  ),
                                ),
                              if (hasFieldAnchors &&
                                  ui.showPhaseMenu &&
                                  phaseActionEntries.isNotEmpty)
                                Positioned(
                                  left: phasePlacement.left,
                                  bottom: phasePlacement.bottom,
                                  child: PhaseActionMenu(
                                    actions: phaseActionEntries,
                                  ),
                                ),
                              if (fieldPlacement != null &&
                                  fieldActionEntries.isNotEmpty)
                                Positioned(
                                  left: fieldPlacement.left,
                                  bottom: fieldPlacement.bottom,
                                  child: FieldActionPopover(
                                    actions: fieldActionEntries,
                                    arrowDx: fieldPlacement.arrowDx,
                                  ),
                                ),
                              Positioned(
                                bottom: 100,
                                left: 16,
                                child: PlayerStatusCard(
                                  name: '武藤游戏',
                                  lp: duelStore.selfLp,
                                  isSelf: true,
                                  isActiveTurn: isMyTurn,
                                  handCount: duelStore.selfHand.length,
                                  deckCount: duelStore.selfDeck,
                                  extraCount: duelStore.selfExtra,
                                  graveCount: duelStore.selfGrave,
                                  removedCount: duelStore.selfRemoved,
                                  onExtraTap: () =>
                                      ui.openZoneBrowser('self_extra'),
                                  onGraveTap: () =>
                                      ui.openZoneBrowser('self_grave'),
                                  onRemovedTap: () =>
                                      ui.openZoneBrowser('self_removed'),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: HandCardsBar(
                                  handCodes: duelStore.selfHand,
                                  selectedCardSequence: ui.selectedHandSequence,
                                  onCardTap: ui.handleHandCardTap,
                                  onCardDoubleTap: ui.handleHandCardDoubleTap,
                                  onSelectedCardRectChanged:
                                      ui.handleHandCardRectChanged,
                                ),
                              ),
                              if (handPlacement != null &&
                                  handActionEntries.isNotEmpty)
                                Positioned(
                                  left: handPlacement.left,
                                  bottom: handPlacement.bottom,
                                  child: HandActionPopover(
                                    actions: handActionEntries,
                                    arrowDx: handPlacement.arrowDx,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      duelStore.currentSelect?.player ==
                                              duelStore.myController
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
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                if (zoneBrowserKey != null)
                  ZoneBrowserModal(
                    zoneBrowserKey: zoneBrowserKey,
                    cards: zoneBrowserEntries,
                    selectedCardSequence: ui.selectedZoneBrowserSequence,
                    onCardTap: ui.inspectZoneBrowserCard,
                    onClose: ui.closeZoneBrowser,
                    selectedActions: zoneBrowserActions,
                    hiddenCount: ui.hiddenCountForZoneKey(zoneBrowserKey),
                    cardNameBuilder: (code) =>
                        duelStore.getCardInfo(code)?.name ?? 'Card #$code',
                  ),
              ],
            ),
          ),
          if (duelStore.isWaitingForInput &&
              !duelStore.hasPhaseCommandWindow)
            _buildDuelOverlay(context, duelStore),
          Positioned(top: 8, left: 8, child: buildBackButton(context)),
        ],
      ),
    );
  }

  Widget _buildDuelOverlay(BuildContext context, DuelFieldStore duelStore) {
    final select = duelStore.currentSelect;

    // showSnackBar(context,"对方选中类型 ${select?.type.name}");
    if (select == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSelectWidget(select, duelStore),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectWidget(SelectState select, DuelFieldStore duelStore) {
    switch (select.type) {
      case SelectType.idleCmd:
        return SelectMenu(
          actions: duelStore.selectedIdleActions,
          onSelect: (action) => duelStore.respondIdleCmd(action.sequence),
        );
      case SelectType.battleCmd:
        return BattleSelectMenu(
          actions: duelStore.selectedBattleActions,
          onSelect: (action) =>
              duelStore.respondBattleCmd(action.sequence),
        );
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSelectCard(sequences),
          onCancel: () => duelStore.respondSelectCard([]),
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSelectChain(
            sequences.isNotEmpty ? sequences.first : -1,
          ),
          onCancel: () => duelStore.respondSelectChain(-1),
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              duelStore.respondSelectPosition(position),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          onYes: () => duelStore.respondSelectEffectYn(true),
          onNo: () => duelStore.respondSelectEffectYn(false),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          onYes: () => duelStore.respondSelectYesNo(true),
          onNo: () => duelStore.respondSelectYesNo(false),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
          ),
          onCancel: () => duelStore.respondSelectOption(0),
        );
      case SelectType.place:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSelectCard(sequences),
          onCancel: () => duelStore.respondSelectCard([]),
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSelectSum(sequences),
          onCancel: () => duelStore.respondSelectSum([]),
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              duelStore.respondSelectCounter(sequences),
          onCancel: () => duelStore.respondSelectCounter([]),
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) => duelStore.respondSortCard(sequences),
          onCancel: () => duelStore.respondSortCard([]),
        );
    }
  }
}
