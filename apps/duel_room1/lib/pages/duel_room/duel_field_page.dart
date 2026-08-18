import 'dart:async';
import 'dart:developer' as console;
import 'dart:ui';

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/duel_menu.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:biz/duel/models/idle_action.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:cardlive/cardlive.dart' show Summon3DOverlay;
import 'package:duelink/duelink.dart' show PlayerInfo, PlayerType;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/duel_room/field/duel_flame_game.dart';
import '../../widgets/duel_room/field/flame_field_snapshot.dart';
import '../../widgets/duel_room/field/flame_playmat_field.dart';
import '../../widgets/duel_room/hud/hand_cards_bar.dart';
import '../../widgets/duel_room/hud/phase_bar.dart';
import '../../widgets/duel_room/hud/player_status_card.dart';
import '../../widgets/duel_room/inspector/card_detail_drawer.dart';
import '../../widgets/duel_room/inspector/duel_log_drawer.dart';
import '../../widgets/duel_room/inspector/zone_browser_modal.dart';
import '../../widgets/duel_room/menus/duel_field_popover_layout.dart';
import '../../widgets/duel_room/menus/field_action_popover.dart';
import '../../widgets/duel_room/menus/hand_action_popover.dart';
import '../../widgets/duel_room/menus/phase_action_menu.dart';
import '../../widgets/duel_room/overlay/announce_card_dialog.dart';
import '../../widgets/duel_room/overlay/card_selector.dart';
import '../../widgets/duel_room/overlay/chain_stack_overlay.dart';
import '../../widgets/duel_room/overlay/confirm_cards_dialog.dart';
import '../../widgets/duel_room/overlay/confirm_floating_card.dart';
import '../../widgets/duel_room/overlay/position_selector.dart';
import '../../widgets/duel_room/overlay/select_prompt_layer.dart';
import '../../widgets/duel_room/overlay/turn_order_hint.dart';
import '../../widgets/duel_room/overlay/yes_no_dialog.dart';
import 'duel_room_exit.dart';

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
///   widget 层 watch Provider 后把 [FlameFieldSnapshot] 推入
///   [DuelFlameGame]，Flame component 不直接 watch，渲染循环与
///   Riverpod 解耦。
///
/// 选择/检视/菜单等交互状态由四个子状态持有；弹层几何计算见
/// duel_field_popover_layout.dart。
class DuelFieldPage extends ConsumerStatefulWidget {
  final List<PlayerInfo> players;
  const DuelFieldPage(this.players, {super.key});

  @override
  ConsumerState<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends ConsumerState<DuelFieldPage> {
  static const double _topHudBodyHeight = 112.0;
  static const double _opponentHandGap = 10.0;
  static const double _inspectorTop = 124.0;
  static const double _logDrawerTop = 126.0;

  DuelFlameGame? _flameGame;
  PlaymatAnchorData? _fieldAnchors;

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
    _scheduleTurnOrderHint();
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
    return _flameGame ??= DuelFlameGame(
      onCardSelect: handleFieldCardTap,
      onZoneInspect: handleZoneInspect,
      onPhaseLampTap: togglePhaseMenu,
      isPhaseLampEnabled: _canTapPhaseLamp,
      onPlaceSlotTap: (key) => _selectN.respondSelectPlaceKey(key),
      onAnchorsChanged: _handleAnchorsChanged,
      onCyberDragonSummon: _handleCyberDragonSummon,
    );
  }

  /// 3D 召唤演出的目标点（overlay 局部坐标）；null 表示无演出。
  Offset? _summonTarget;

  /// 电子龙进入怪兽区：以目标卡槽为中心播放 flame_3d 召唤演出。
  /// Web/无 Flutter GPU 平台跳过（overlay 自身也不会被创建）。
  void _handleCyberDragonSummon(String slotKey) {
    if (kIsWeb || _summonTarget != null) return;
    // applySnapshot 发生在 build 路径上，setState 推迟到帧末
    // （与 _handleAnchorsChanged 同理）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _summonTarget != null) return;
      final rect = _fieldAnchors?.slotRects[slotKey];
      final size = MediaQuery.sizeOf(context);
      setState(() {
        _summonTarget = rect?.center ?? Offset(size.width / 2, size.height / 2);
      });
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

  /// 从 biz/duel Provider 组装推入 Flame 的状态快照。
  FlameFieldSnapshot _buildFlameSnapshot() {
    return FlameFieldSnapshot(
      fieldCards: Map<String, FieldCard>.from(_board.fieldCards),
      myController: _board.myController,
      phase: _board.phase,
      inDamageStep: _board.inDamageStep,
      battlePresentation: _board.battlePresentation,
      deckShuffleTick: _board.deckShuffleTick,
      deckShufflePlayer: _board.deckShufflePlayer,
      summonEffectTick: _board.summonEffectTick,
      summonEffectEvent: _board.summonEffectEvent,
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
    );
  }

  Widget _buildBattlefield() {
    final game = _ensureFlameGame();
    // 每次 build（任一子状态变更）把最新快照推入游戏，
    // 驱动 Flame 侧重建；Flame component 不 watch Provider。
    game.applySnapshot(_buildFlameSnapshot());
    return FlamePlaymatField(
      game: game,
      onAnchorsChanged: _handleAnchorsChanged,
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
        .firstOrNull ?? '我方';
    final oppName = widget.players
        .where((p) => p.pos == 1 - mc)
        .map((p) => p.name)
        .firstOrNull ?? '对方';
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
                      onExtraTap: () => openZoneBrowser('opp_extra'),
                      onGraveTap: () => openZoneBrowser('opp_grave'),
                      onRemovedTap: () => openZoneBrowser('opp_removed'),
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
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
          onInspectCard: onInspectCard,
          onYes: () =>
              _selectN.respondSelectEffectYn(true, generation: generation),
          onNo: () =>
              _selectN.respondSelectEffectYn(false, generation: generation),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          cardCode:
              select.options.isNotEmpty ? select.options.first.code : null,
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
          onSearch: _selectN.searchAnnounceCards,
          onSelect: (code) =>
              _selectN.respondAnnounceCard(code, generation: generation),
          onInspectCard: onInspectCard,
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              _selectN.respondSelectSum(sequences, generation: generation),
          onCancel: () =>
              _selectN.respondSelectSum([], generation: generation),
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
          onCancel: () =>
              _selectN.respondSortCard([], generation: generation),
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

    // 任一子状态变更都触发重建（等价原 ChangeNotifier 全量通知），
    // 读取经上方的 _board/_select/_confirm/_overlay getter。
    ref.watch(duelFieldProvider);
    ref.watch(selectWindowProvider);
    ref.watch(cardConfirmProvider);
    ref.watch(fieldOverlayProvider);
    final isMyTurn = _board.currentPlayer == _board.myController;
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
    // 模态弹窗）由选择子状态判定，页面只区分 none 与 modal
    // （modal 期间隐藏连锁叠层）。
    final selectPromptMode = _selectN.selectPromptMode;
    final topInset = MediaQuery.of(context).padding.top;
    final opponentHandTop = topInset + _topHudBodyHeight + _opponentHandGap;
    // viewport 仅用于 anchors 缺失时的 fallback 比例估算；
    // 弹层定位与避让统一由 Portal 的 Aligned 锚点负责。
    final viewport = MediaQuery.sizeOf(context);
    final hasFieldAnchors = _fieldAnchors != null;
    final phaseRect = _phaseLampRect(viewport);
    final selectedFieldCard = _overlay.selectedFieldCard;
    final fieldRect = selectedFieldCard == null
        ? null
        : _fieldCardRect(viewport, selectedFieldCard);
    // 弹层统一通过 Portal 渲染：底边对齐锚点矩形顶部，
    // 由 flutter_portal 自动避让屏幕边界。
    const overlayAnchor = Aligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      shiftToWithinBound: AxisFlag(x: true, y: true),
    );
    // 页面自带 Portal：内部的 PortalTarget（阶段菜单/场上操作/手牌菜单）
    // 不再依赖宿主 App 提供全局 Portal；宿主已有 Portal 时嵌套安全。
    return Portal(
      child: Scaffold(
        backgroundColor: const Color(0xFF010308),
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _buildBattlefield()),
            // 电子龙 3D 召唤演出（透明 overlay，不拦截指针；演完自移除）。
            if (_summonTarget != null)
              Positioned.fill(
                child: Summon3DOverlay(
                  targetCenter: _summonTarget!,
                  onDone: () => setState(() => _summonTarget = null),
                ),
              ),
            // debug 入口：手动触发一次召唤演出验证 3D 管线。
            if (kDebugMode && !kIsWeb && _summonTarget == null)
              Positioned(
                right: 8,
                bottom: 128,
                child: IconButton(
                  key: const ValueKey('debug-summon-cyber-dragon'),
                  iconSize: 20,
                  tooltip: '测试电子龙召唤',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white12,
                  ),
                  icon: const Icon(Icons.smart_toy_outlined),
                  onPressed: () => _handleCyberDragonSummon(''),
                ),
              ),
            // debug 入口：手动触发通用层几何召唤阵特效。
            if (kDebugMode)
              Positioned(
                right: 8,
                bottom: 168,
                child: IconButton(
                  key: const ValueKey('debug-summon-effect'),
                  iconSize: 20,
                  tooltip: '测试召唤特效（几何阵）',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white12,
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: () => _ensureFlameGame().debugPlaySummonEffect(),
                ),
              ),
            Positioned(
              top: opponentHandTop,
              left: 0,
              right: 0,
              child: HandCardsBar(
                cardsVisible: false,
                handCodes: _board.opponentHand,
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
            ),
            _buildTopHud(isMyTurn),
            if (zoneBrowserKey != null)
              ZoneBrowserModal(
                zoneBrowserKey: zoneBrowserKey,
                cards: zoneBrowserEntries,
                selectedCardSequence: _overlay.selectedZoneBrowserSequence,
                onCardTap: inspectZoneBrowserCard,
                onClose: closeZoneBrowser,
                selectedActions: zoneBrowserActions,
                hiddenCount: ref.watch(zoneHiddenCountProvider(zoneBrowserKey)),
                cardNameBuilder: (code) =>
                    _boardN.getCardInfo(code)?.name ?? 'Card #$code',
              ),
            if (selectPromptMode != SelectPromptMode.none)
              Positioned.fill(child: _buildSelectPromptLayer(selectPromptMode)),
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
                        _boardN.getCardInfo(code)?.name ??
                        'Card #$code',
                  ),
                ),
              ),
            if (_overlay.showInspector) _buildInspector(),
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
    console.log(
      'handleFieldCardTap: card='
      '${fieldCard == null ? 'null' : 'code=${fieldCard.code} c=${fieldCard.controller} z=${fieldCard.zone} s=${fieldCard.sequence} pos=${fieldCard.position}'} '
      'actions=[${actions.map((action) => '${action.kind.name}:${action.response}:c=${action.controller}:z=${action.location}:s=${action.sequence}:code=${action.code}').join(', ')}]',
    );
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
