import 'dart:async';
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
import 'package:duel_room1/field/models/duel_field_layout.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/flame_playmat_field.dart';
import 'package:duel_room1/field/widgets/hud/hand_cards_bar.dart';
import 'package:duel_room1/field/widgets/hud/phase_bar.dart';
import 'package:duel_room1/field/widgets/hud/player_status_card.dart';
import 'package:duel_room1/field/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room1/field/widgets/inspector/zone_browser_modal.dart';
import 'package:duel_room1/field/widgets/menus/duel_field_popover_layout.dart';
import 'package:duel_room1/field/widgets/menus/field_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/phase_action_menu.dart';
import 'package:duel_room1/field/widgets/overlay/announce_card_dialog.dart';
import 'package:duel_room1/field/widgets/overlay/announce_choice_dialog.dart';
import 'package:duel_room1/field/widgets/overlay/card_selector.dart';
import 'package:duel_room1/field/widgets/overlay/chain_stack_overlay.dart';
import 'package:duel_room1/field/widgets/overlay/confirm_cards_dialog.dart';
import 'package:duel_room1/field/widgets/overlay/confirm_floating_card.dart';
import 'package:duel_room1/field/widgets/overlay/position_selector.dart';
import 'package:duel_room1/field/widgets/overlay/select_prompt_layer.dart';
import 'package:duel_room1/field/widgets/overlay/turn_order_hint.dart';
import 'package:duel_room1/field/widgets/overlay/yes_no_dialog.dart';
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

  // 快照推送订阅：只有场地/选择窗口状态变化才推入 Flame，
  // 替代原先 build 路径上的 applySnapshot 副作用。
  ProviderSubscription<DuelFieldState>? _boardSub;
  ProviderSubscription<SelectWindowState>? _selectSub;

  // 先后攻提示：进入场地页时居中短暂展示一次。
  bool _showTurnOrderHint = false;
  bool _isFirstTurn = false;

  // 四个子状态 + 跨状态控制器的便捷访问；读取经 ref.read，
  // 重建由 build 里的四个 ref.watch 驱动。
  DuelFieldState get _board => ref.read(duelFieldProvider);
  SelectWindowState get _select => ref.read(selectWindowProvider);
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
    _boardSub = ref.listenManual(duelFieldProvider, (_, _) => _pushSnapshot());
    _selectSub = ref.listenManual(
      selectWindowProvider,
      (_, _) => _pushSnapshot(),
    );
  }

  @override
  void dispose() {
    _boardSub?.close();
    _selectSub?.close();
    super.dispose();
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
      onAnchorsChanged: _handleAnchorsChanged,
    );
    _flameGame = game;
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
    // anchors 未就绪时的兜底：与 DuelFieldLayout.phaseLampFallbackRatio 对齐。
    // x=0.88 对应 self_grave（我方墓地，棋盘右区 colX[6] Monster 行）；y=0.53 对应 Monster 行上沿附近。
    final fallback = Offset(
      viewport.width * DuelFieldLayout.phaseLampFallbackRatio.dx,
      viewport.height * DuelFieldLayout.phaseLampFallbackRatio.dy,
    );
    return Rect.fromLTWH(
      fallback.dx,
      fallback.dy,
      DuelFieldLayout.phaseLampSize.width,
      DuelFieldLayout.phaseLampSize.height,
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
    final selfName = teamDisplayName(mc, effectivePlayers, fallback: '我方');
    final oppName = teamDisplayName(1 - mc, effectivePlayers, fallback: '对方');
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
    // 弹层几何（viewport/phaseRect/overlayAnchor 等）已随 HUD 层移至
    // _buildHudOverlay。
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
    final topInset = MediaQuery.of(context).padding.top;
    final opponentHandTop = topInset + _topHudBodyHeight + _opponentHandGap;
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
        Positioned(
          top: opponentHandTop,
          left: 0,
          right: 0,
          child: Consumer(
            builder: (context, ref, _) {
              final opp = ref.watch(
                duelFieldProvider.select(selectOppHandSlice),
              );
              final confirmedOwner = ref.watch(
                cardConfirmProvider.select((s) => s.confirmedHandOwner),
              );
              final confirmedSeqs = ref.watch(
                cardConfirmProvider.select((s) => s.confirmedHandSequences),
              );
              return HandCardsBar(
                cardsVisible: false,
                handCodes: opp.opponentHand,
                highlightedSequences:
                    confirmedOwner != opp.myController &&
                        confirmedSeqs.isNotEmpty
                    ? confirmedSeqs
                    : const {},
              );
            },
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
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer(
            builder: (context, ref, _) {
              final hand = ref.watch(
                duelFieldProvider.select(selectSelfHandSlice),
              );
              final selectedSeq = ref.watch(
                fieldOverlayProvider.select((s) => s.selectedHandSequence),
              );
              final confirmedOwner = ref.watch(
                cardConfirmProvider.select((s) => s.confirmedHandOwner),
              );
              final confirmedSeqs = ref.watch(
                cardConfirmProvider.select((s) => s.confirmedHandSequences),
              );
              final mode = ref.watch(selectPromptModeProvider);
              // 就地选择高亮/勾选依赖窗口与勾选下标：订阅驱动重建，
              // 序列集在 build 时经 notifier 派生读取。
              ref.watch(
                selectWindowProvider.select(
                  (s) => (s.currentSelect, s.inlineSelectedOptionIndices),
                ),
              );
              final selectN = ref.read(selectWindowProvider.notifier);
              final inlineActive = mode == SelectPromptMode.inline;
              final entries = ref.watch(handActionMenuProvider);
              return HandCardsBar(
                handCodes: hand.selfHand,
                selectedCardSequence: selectedSeq,
                onCardTap: handleHandCardTap,
                overlayContent: entries.isEmpty
                    ? null
                    : HandActionPopover(actions: entries),
                overlayVisible: selectedSeq != null && entries.isNotEmpty,
                highlightedSequences:
                    confirmedOwner == hand.myController &&
                        confirmedSeqs.isNotEmpty
                    ? confirmedSeqs
                    : inlineActive
                    ? selectN.inlineSelectableHandSequences
                    : const {},
                checkedSequences: inlineActive
                    ? selectN.inlineSelectedHandSequences
                    : const {},
              );
            },
          ),
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
            final mode = ref.watch(selectPromptModeProvider);
            final hasPanel = ref.watch(
              cardConfirmProvider.select((s) => s.confirmPanel != null),
            );
            if (mode == SelectPromptMode.modal || hasPanel) {
              return const SizedBox.shrink();
            }
            final chain = ref.watch(duelFieldProvider.select(selectChainSlice));
            ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
            return Positioned.fill(
              child: IgnorePointer(
                child: ChainStackOverlay(
                  chains: chain.chains,
                  chainSealed: chain.chainSealed,
                  cardNameBuilder: (code) =>
                      _boardN.getCardInfo(code)?.name ?? 'Card #$code',
                ),
              ),
            );
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
