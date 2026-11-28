import 'dart:async';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duelink/duelink.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bridge/duel_3d_bridge.dart';
import '../util/duel_room_exit.dart';
import 'hud/action_bar.dart';
import 'hud/card_detail_panel.dart';
import 'hud/confirm_cards_dialog.dart';
import 'hud/confirm_floating_card.dart';
import 'hud/cyber_overlay.dart';
import 'hud/duel_overlays.dart';
import 'hud/hand_bar.dart';
import '../theme/hud_theme.dart';
import 'hud/lp_bar.dart';
import 'hud/phase_rail.dart';
import 'hud/zone_count_bar.dart';
import 'scene3d/duel_3d_game.dart';
import '../theme/cyber_skin.dart';

/// 中立座位称谓：观战者没有「我方 / 对方」的立场，改用 ENG-1 / ENG-2
/// 指代引擎玩家编号。
///
/// 观战者视角下 `board.myController` 恒为 1，`selfLp` / `opponentLp`
/// 只是座位对齐的副产品——沿用「我方 / 对方」会把屏幕左侧的玩家
/// 说成「我方」，纯属误导。决斗者仍沿用「我方 / 对方」。
String _seatLabel(int enginePlayer, {required bool isDuelist}) =>
    isDuelist ? (enginePlayer == 0 ? '我方' : '对方') : 'ENG-${enginePlayer + 1}';

/// 3D 决斗场地页：flame_3d 场景 + MDPro3 风格 HUD 叠层。
///
/// **自己创建并持有 [Duel3DGame]**（见 [_DuelFieldPage3DState._ensureGame]）。
/// 页面之间不共享 3D 实例：房间页用 [TabBarView] 切「等候 → 加载 → 场地」，
/// 而 `TabBarView` 底层是不保活的 `PageView`，跨页传递实例会踩到 flame
/// 「同一 `Game` 不能被两个 `GameWidget` 同时持有」的单值约束
/// （`Game._gameRenderBox`）。让本页独占装配，链路最简单。
class DuelFieldPage3D extends ConsumerStatefulWidget {
  const DuelFieldPage3D({super.key, required this.players, this.onSceneReady});

  final List<PlayerInfo> players;

  /// 3D 场景首帧就绪（GPU 预载 + 场景装配都完成）时回调一次。
  final VoidCallback? onSceneReady;

  @override
  ConsumerState<DuelFieldPage3D> createState() => _DuelFieldPage3DState();
}

class _DuelFieldPage3DState extends ConsumerState<DuelFieldPage3D> {
  Duel3DGame? _game;
  Duel3DBridge? _bridge;
  bool _logDrawerOpen = false;

  Duel3DGame get _gameOrThrow => _game!;

  DuelFieldState get _board => ref.read(duelFieldProvider);
  DuelFieldNotifier get _boardN => ref.read(duelFieldProvider.notifier);
  SelectWindowState get _select => ref.read(selectWindowProvider);
  SelectWindowNotifier get _selectN => ref.read(selectWindowProvider.notifier);
  FieldOverlayState get _overlay => ref.read(fieldOverlayProvider);
  FieldOverlayNotifier get _overlayN => ref.read(fieldOverlayProvider.notifier);

  bool _gpuReady = false;
  Object? _gpuError;

  /// 场景首帧就绪是否已回调过（保证只回调一次）。
  bool _sceneReadyNotified = false;

  /// 就绪回调是否已经排进帧后队列（避免 loadingBuilder 每帧重复排队）。
  bool _warmingScheduled = false;

  /// 手势容器坐标基准（取它自己的 RenderBox，而非外层页面容器——
  /// 树结构变化时后者会静默错位）。
  final GlobalKey _gameAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initGpu();
    // 赛博演出开关是全局持久化偏好；恢复后 3D 组件每帧读取，
    // 不需要重建 GameWidget。
    unawaited(CyberSkin.restore());
  }

  @override
  void dispose() {
    _bridge?.detach();
    super.dispose();
  }

  /// 先预载 shader（GpuBackend）再挂载 GameWidget，避免首帧
  /// 材质初始化竞态（Failed to initialize ShaderLibrary）。
  /// 失败进错误态（可重试；ensureGpuBackend 失败后会复位缓存）。
  ///
  /// 预载完只算「GPU 能用」；要等 GameWidget 真正上屏出过一帧
  /// （[_markSceneReady]）才算场景就绪。
  void _initGpu() {
    Duel3DGame.ensureGpuBackend()
        .then((_) {
          if (!mounted) return;
          setState(() => _gpuReady = true);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _gpuError = e);
        });
  }

  /// 创建 3D 实例并接上状态桥（幂等：`build` 每帧调用）。
  ///
  /// 场地页挂载时已 `RoomInDuel`，`myController` 由 `MSG_START` 的
  /// `playerType` 确定——`selfType` 锚定的是 `mySeat` 而非 controller，
  /// 这里不做二次推断，直接用 board 已解析的结果。
  void _ensureGame() {
    if (_game != null) return;
    final board = _board;
    final game = Duel3DGame(myController: board.myController);
    game.onSlotTap = _handleSlotTap;
    game.onStandeeTap = _handleStandeeTap;
    _game = game;
    _bridge = Duel3DBridge(game: game)..attach(ref);
  }

  /// 场景首帧已上屏：通知外部（可为 null）。
  void _markSceneReady() {
    if (_sceneReadyNotified) return;
    _sceneReadyNotified = true;
    widget.onSceneReady?.call();
  }

  /// GameWidget 首帧装配中的探针（见 [GameWidget.loadingBuilder]）。
  ///
  /// 第一次被调用说明「已经挂上树、开始装配」，本帧之后场景就是可看的，
  /// 于是在帧后回调 [_markSceneReady]。用标志位保证只排一次队。
  void _onWarming() {
    if (_warmingScheduled || _sceneReadyNotified) return;
    _warmingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markSceneReady();
    });
  }

  // ───────────────────────── 交互 ─────────────────────────

  /// 立牌点击 → 就地选择优先，否则检视 + 动作条。
  void _handleStandeeTap(String zoneKey) {
    final fieldCard = _board.fieldCards[zoneKey];
    if (fieldCard != null && _selectN.inlineSelectActive) {
      final index = _selectN.inlineOptionIndexForField(fieldCard);
      if (index == null) {
        _inspectCardMut(fieldCard.code);
        return;
      }
      _applyInlineOptionTap(index, fieldCard.code);
      return;
    }
    if (fieldCard == null) return;
    _inspectCardMut(fieldCard.code);
    final actions = resolveFieldActions(fieldCard, _select, _board);
    _overlayN.applyFieldCardSelection(actions.isEmpty ? null : fieldCard);
  }

  /// 地砖点击 → 放置选择 / 区域检视。
  void _handleSlotTap(String slotId) {
    // 放置选择窗口：点击可放置槽位直接回包
    if (_select.placeTargetFieldKeys.contains(slotId)) {
      _selectN.respondSelectPlaceKey(slotId);
      return;
    }
    // 可浏览区域（墓地/额外/除外）
    if (_isBrowsableZone(slotId)) {
      _overlayN.openZoneBrowser(slotId);
    }
  }

  static bool _isBrowsableZone(String slotId) => switch (slotId) {
    'self_grave' ||
    'opp_grave' ||
    'self_removed' ||
    'opp_removed' ||
    'self_extra' ||
    'opp_extra' => true,
    _ => false,
  };

  void _handleHandCardTap(int sequence, int code) {
    if (_selectN.inlineSelectActive) {
      final index = _selectN.inlineOptionIndexForHand(sequence);
      if (index != null) {
        _applyInlineOptionTap(index, code);
        return;
      }
      _inspectCardMut(code);
      return;
    }
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyHandCardTap(sequence, code, _boardN.getCardInfo(code));
  }

  void _applyInlineOptionTap(int index, int code) {
    final select = _select.currentSelect;
    if (select == null) return;
    _inspectCardMut(code);
    switch (select.type) {
      case SelectType.chain:
        _selectN.respondSelectChain(index);
        return;
      case SelectType.unselect:
        _selectN.respondSelectUnselectCard(index);
        return;
      default:
        break;
    }
    if (select.min == 1 && select.max == 1) {
      _selectN.respondInlineMulti([index]);
      return;
    }
    _selectN.toggleInlineOption(index);
  }

  void _inspectCardMut(int code) {
    if (code <= 0) return;
    unawaited(_boardN.ensureCardInfo(code));
    _overlayN.applyInspect(code, _boardN.getCardInfo(code));
  }

  void _cancelOperation() {
    if (_select.inlineSelectedCount > 0) {
      _selectN.clearInlineSelection();
      return;
    }
    _overlayN.clearLocalUi();
    if (_overlay.showInspector) _overlayN.dismissInspector();
  }

  /// 顶部浮动确认卡的定位：owner == myController 时视为己方（底部手牌上方），
  /// 否则视为对方（顶部）。room3 无 room1 的 fieldAnchors 锚点，这里用固定
  /// 偏移贴近对应半场（右 150 避开右侧 LP 条 / 阶段轨道）。
  Widget _buildFloatPreview(
    WidgetRef ref, {
    required int owner,
    required bool isExtra,
    required List<int> codes,
    required int index,
  }) {
    // 下标越界（codes 变短等瞬态）时不渲染，避免 RangeError。
    if (index >= codes.length) return const SizedBox.shrink();
    final myController = ref.read(duelFieldProvider).myController;
    final isSelf = owner == myController;
    final boardN = ref.read(duelFieldProvider.notifier);
    final confirmN = ref.read(cardConfirmProvider.notifier);
    return Positioned(
      top: isSelf ? null : 120,
      bottom: isSelf ? 180 : null,
      right: 150,
      child: ConfirmFloatingCard(
        codes: codes,
        currentIndex: index,
        title: isExtra ? '额外卡组顶部' : '卡组顶部',
        cardNameBuilder: (code) =>
            boardN.getCardInfo(code)?.name ?? 'Card #$code',
        onDismiss: confirmN.dismissConfirmPanel,
      ),
    );
  }

  // ───────────────────────── 构建 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    _ensureGame();
    final game = _gameOrThrow;
    final board = ref.watch(duelFieldProvider);
    final overlay = ref.watch(fieldOverlayProvider);
    final select = ref.watch(selectWindowProvider);
    final fieldActions = ref.watch(fieldActionMenuProvider);
    final handActions = ref.watch(handActionMenuProvider);
    final phaseActions = ref.watch(phaseActionMenuProvider);
    // match 比分：房间状态累计的跨局战绩。观战者不计分，第 1 局（0:0）也不显示。
    final room = ref.watch(duelRoomProvider);
    // 观战者没有立场：比分不显示，「我方 / 对方」也要换成中性称谓。
    final isDuelist = room.selfType.isDuelist;
    final showMatchScore = isDuelist && room.matchGamesPlayed > 0;

    final isMyTurn = board.currentPlayer == board.myController;
    // 观战者的 isMyTurn 没有「轮到我」的含义，只表示「当前行动方是否
    // 那个座位对齐出来的 myController」；提示语必须中性化。
    final mySeatLabel = _seatLabel(board.myController, isDuelist: isDuelist);
    final oppSeatLabel = _seatLabel(
      1 - board.myController,
      isDuelist: isDuelist,
    );
    final selectN = ref.read(selectWindowProvider.notifier);
    final selfName = board.playerNameOf(board.myController);
    final oppName = board.playerNameOf(1 - board.myController);
    final canCancel =
        overlay.hasAnyOverlayOpen ||
        overlay.showInspector ||
        select.inlineSelectedCount > 0;

    return ColoredBox(
      color: HudTheme.bgDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 3D 场景（含手势）；GPU 未就绪时显示加载，初始化失败给重试。
          if (_gpuError != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: HudTheme.danger,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '3D 渲染初始化失败',
                    style: HudTheme.body.copyWith(color: HudTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text('$_gpuError', style: HudTheme.caption),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: HudTheme.cyanDim,
                    ),
                    onPressed: () {
                      setState(() => _gpuError = null);
                      _initGpu();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else if (!_gpuReady)
            const Center(child: CircularProgressIndicator(color: HudTheme.cyan))
          else
            Positioned.fill(
              child: GestureDetector(
                key: _gameAreaKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final box =
                      _gameAreaKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (box == null) return;
                  game.handleTap(details.localPosition, box.size);
                },
                child: GameWidget(
                  game: game,
                  // 场景装配完成（Game.load + mount 都跑完）即认为可交接。
                  // 用 loadingBuilder 当探针而不是另加 `onLoad`——flame 的
                  // GameWidget 没有这个回调；loadingBuilder 只在装配中的
                  // 那些帧被调用，装配完就换成正式画面，正好是就绪信号。
                  loadingBuilder: (context) {
                    // 首帧装配期间的占位。这里不能直接 setState：本回调
                    // 运行在 build 内部。交给 `_warming` 队列在帧后置位。
                    _onWarming();
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),

          // 赛博 HUD 后处理：只覆盖 3D 场景层，HUD 文字保持清晰。
          // IgnorePointer 内置于 CyberOverlay，不影响射线拾取。
          ValueListenableBuilder<bool>(
            valueListenable: CyberSkin.enabled,
            builder: (context, cyberOn, _) => cyberOn
                ? const Positioned.fill(child: CyberOverlay())
                : const SizedBox.shrink(),
          ),

          // 选择窗口（横幅 + 模态 + 确认）
          const DuelSelectOverlay(),

          // 左：己方 LP
          Positioned(
            left: 12,
            bottom: 150,
            child: LpBar(
              playerName: selfName,
              lp: board.selfLp,
              maxLp: board.startLp, // MSG_START 初始 LP（match/tag 16000）
              alignLeft: true,
              isSelf: true,
            ),
          ),
          // 右：对方 LP
          Positioned(
            right: 12,
            top: 60,
            child: LpBar(
              playerName: oppName,
              lp: board.opponentLp,
              maxLp: board.startLp,
              alignLeft: false,
            ),
          ),

          // 上中：match 比分（BO3）。只在决斗者且已打过至少一局时显示；
          // 第 1 局（0:0）画出来只是噪音，还会和回合信息抢视线。
          if (showMatchScore)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(child: _MatchScoreBadge(room: room)),
              ),
            ),

          // 右侧阶段轨道
          Positioned(
            right: 12,
            bottom: 150,
            child: PhaseRail(
              current: board.phase,
              isMyTurn: isMyTurn,
              // 阶段动作会直接回包给服务端；观战者 myController 是座位
              // 对齐出来的，一旦误判成「轮到我」就会弹出「阶段操作」菜单
              // 并替决斗者发出操作。轨道仍显示（只读观赏），只摘掉动作。
              phaseActions: isDuelist ? phaseActions : const [],
              onActionTap: (entry) => entry.onTap(),
            ),
          ),

          // 左上：回合/连锁信息 + 菜单按钮
          Positioned(
            left: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: HudTheme.panel(radius: 16),
                  child: Text(
                    '回合 ${board.turnCount} · '
                    '${isMyTurn ? mySeatLabel : oppSeatLabel}',
                    style: HudTheme.caption.copyWith(
                      color: isMyTurn ? HudTheme.cyan : HudTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (board.chains.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: HudTheme.glowPanel(
                        glow: HudTheme.gold,
                        radius: 16,
                      ),
                      child: Text(
                        '连锁 ${board.chains.length}',
                        style: HudTheme.caption.copyWith(
                          color: HudTheme.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // 双方剩余秒数（B3）：0 表示无限制/未计时则不显示，≤30 秒变红。
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TurnTimerBadge(
                        label: mySeatLabel,
                        seconds: board.selfTimeLeft,
                        accent: HudTheme.cyan,
                      ),
                      const SizedBox(width: 6),
                      _TurnTimerBadge(
                        label: oppSeatLabel,
                        seconds: board.opponentTimeLeft,
                        accent: HudTheme.gold,
                      ),
                    ],
                  ),
                ),
                // 对方区域计数条（B2）：挂在左上信息簇下方，与回合/连锁徽章对齐。
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ZoneCountBar(
                    handCount: board.opponentHand.length,
                    deckCount: board.oppDeck,
                    extraCount: board.oppExtra,
                    graveCount: board.oppGrave,
                    removedCount: board.oppRemoved,
                    onExtraTap: () => _overlayN.openZoneBrowser('opp_extra'),
                    onGraveTap: () => _overlayN.openZoneBrowser('opp_grave'),
                    onRemovedTap: () =>
                        _overlayN.openZoneBrowser('opp_removed'),
                  ),
                ),
              ],
            ),
          ),

          // 右上：赛博演出开关 + 菜单按钮组
          Positioned(
            right: 12,
            top: 12,
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: CyberSkin.enabled,
                  builder: (context, on, _) => _HudIconButton(
                    icon: on ? Icons.flash_on : Icons.flash_off,
                    tooltip: on ? '赛博演出：开（点击关闭）' : '赛博演出：关（点击开启）',
                    accent: on ? CyberPalette.magenta : HudTheme.textSecondary,
                    onTap: () => unawaited(CyberSkin.toggle()),
                  ),
                ),
                const SizedBox(width: 8),
                _HudIconButton(
                  icon: Icons.article_outlined,
                  tooltip: '决斗日志',
                  onTap: () => setState(() => _logDrawerOpen = true),
                ),
                // 「投降」是决斗者的动作。观战者点了会真的向服务端发
                // CTOS_SURRENDER，把别人的对局结束掉——必须整颗隐藏。
                if (isDuelist) ...[
                  const SizedBox(width: 8),
                  _HudIconButton(
                    icon: Icons.flag_outlined,
                    tooltip: '投降',
                    onTap: () => surrenderDialog(context: context, ref: ref),
                  ),
                ],
              ],
            ),
          ),

          // 左侧卡片详情
          if (overlay.showInspector && overlay.inspectedCardCode != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: CardDetailPanel(
                  code: overlay.inspectedCardCode,
                  info: overlay.inspectedCardInfo,
                  onClose: _overlayN.dismissInspector,
                ),
              ),
            ),

          // 底部：手牌 + 操作条
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 己方区域计数条（B2）：置于手牌条/操作条上方，随底部堆叠自然上移，
                // 避免与居中的操作条重叠（用 Positioned 固定底边会互相遮挡）。
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Center(
                    child: ZoneCountBar(
                      handCount: board.selfHand.length,
                      deckCount: board.selfDeck,
                      extraCount: board.selfExtra,
                      graveCount: board.selfGrave,
                      removedCount: board.selfRemoved,
                      onExtraTap: () => _overlayN.openZoneBrowser('self_extra'),
                      onGraveTap: () => _overlayN.openZoneBrowser('self_grave'),
                      onRemovedTap: () =>
                          _overlayN.openZoneBrowser('self_removed'),
                    ),
                  ),
                ),
                if (fieldActions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ActionBar(
                      entries: fieldActions,
                      onClose: _cancelOperation,
                    ),
                  )
                else if (handActions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ActionBar(
                      entries: handActions,
                      onClose: _cancelOperation,
                    ),
                  ),
                HandBar(
                  cards: board.selfHand,
                  selectedSequence: overlay.selectedHandSequence,
                  selectableSequences: selectN.inlineSelectableHandSequences,
                  checkedSequences: selectN.inlineSelectedHandSequences,
                  onCardTap: _handleHandCardTap,
                ),
              ],
            ),
          ),

          // 取消按钮
          if (canCancel)
            Positioned(
              right: 12,
              bottom: 130,
              child: _HudIconButton(
                icon: Icons.close,
                tooltip: '取消',
                onTap: _cancelOperation,
              ),
            ),

          // 等待提示
          if (!isMyTurn && !select.isWaitingForInput)
            Positioned(
              top: 44,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: HudTheme.panel(radius: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HudTheme.cyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 观战者不是「在等对方」，只是在旁观当前行动方。
                      Text('$oppSeatLabel 行动中…', style: HudTheme.caption),
                    ],
                  ),
                ),
              ),
            ),

          // 顶部浮动确认卡（A2b）：只读渲染 notifier 计时的当前下标，
          // 己方显示在底部手牌上方、对方显示在顶部（owner 与 myController 比较）。
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
              return _buildFloatPreview(
                ref,
                owner: preview.owner,
                isExtra: preview.isExtra,
                codes: preview.codes,
                index: preview.index,
              );
            },
          ),

          // 确认多卡弹窗（A2a）：confirmPanel 非空时模态展示，点击任意处关闭。
          Consumer(
            builder: (context, ref, _) {
              final panel = ref.watch(
                cardConfirmProvider.select((s) => s.confirmPanel),
              );
              if (panel == null) return const SizedBox.shrink();
              // 卡名缓存批次完成时刷新弹窗里的卡名（getCardInfo 惰性加载）。
              ref.watch(duelFieldProvider.select((s) => s.cardInfoVersion));
              final confirmN = ref.read(cardConfirmProvider.notifier);
              final boardN = ref.read(duelFieldProvider.notifier);
              return Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: ConfirmCardsDialog(
                    title: panel.title,
                    codes: panel.codes,
                    cardNameBuilder: (code) =>
                        boardN.getCardInfo(code)?.name ?? 'Card #$code',
                    onDismiss: confirmN.dismissConfirmPanel,
                  ),
                ),
              );
            },
          ),

          // 日志/聊天抽屉
          if (_logDrawerOpen)
            Positioned.fill(
              child: _LogDrawer(
                onClose: () => setState(() => _logDrawerOpen = false),
              ),
            ),

          // 区域浏览器
          if (overlay.openZoneBrowserKey != null)
            Positioned.fill(
              child: _ZoneBrowser(zoneKey: overlay.openZoneBrowserKey!),
            ),
        ],
      ),
    );
  }
}

/// 场地页顶部的 match 比分徽标：`1 : 0` + 局号。
///
/// 刻意做得小且半透明：场地页的信息主体是牌面与 LP，比分只是「这场打到
/// 第几局、谁领先」的参考。领先方用金色，落后方用次级灰。
class _MatchScoreBadge extends StatelessWidget {
  const _MatchScoreBadge({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context) {
    final myLead = room.myMatchWins > room.opponentMatchWins;
    final oppLead = room.opponentMatchWins > room.myMatchWins;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: HudTheme.panel(radius: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${room.myMatchWins}',
            style: TextStyle(
              color: myLead ? HudTheme.gold : HudTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: HudTheme.caption.copyWith(
                color: HudTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${room.opponentMatchWins}',
            style: TextStyle(
              color: oppLead ? HudTheme.gold : HudTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 12, color: HudTheme.panelBorder),
          const SizedBox(width: 10),
          Text(
            '第 ${room.matchGameNumber} 局',
            style: HudTheme.caption.copyWith(color: HudTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: HudTheme.panel(radius: 18),
          child: Icon(icon, color: accent ?? HudTheme.textPrimary, size: 18),
        ),
      ),
    );
  }
}

/// 回合剩余秒数徽章（B3）：0 表示无限制/未计时则不显示；≤30 秒变红。
class _TurnTimerBadge extends StatelessWidget {
  const _TurnTimerBadge({
    required this.label,
    required this.seconds,
    required this.accent,
  });

  final String label;
  final int seconds;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (seconds <= 0) return const SizedBox.shrink();
    final urgent = seconds <= 30;
    final color = urgent ? HudTheme.danger : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: HudTheme.panel(radius: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: HudTheme.caption),
          const SizedBox(width: 6),
          Text(
            _format(seconds),
            style: HudTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 决斗日志 + 聊天抽屉（右侧滑入）。
class _LogDrawer extends ConsumerStatefulWidget {
  const _LogDrawer({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_LogDrawer> createState() => _LogDrawerState();
}

class _LogDrawerState extends ConsumerState<_LogDrawer> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(duelFieldProvider).duelLogs;
    final chat = ref.watch(duelChatProvider).messages;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onClose,
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        Container(
          width: 320,
          color: HudTheme.bgDeep,
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('决斗日志', style: HudTheme.title),
                    const Spacer(),
                    InkWell(
                      onTap: widget.onClose,
                      child: const Icon(
                        Icons.close,
                        color: HudTheme.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const Divider(color: HudTheme.panelBorder),
                Expanded(
                  child: ListView(
                    reverse: true,
                    children: [
                      for (final log in logs.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(log, style: HudTheme.caption),
                        ),
                      if (chat.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('—— 聊天 ——', style: HudTheme.caption),
                        ),
                      for (final msg in chat.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${msg.name}: ${msg.message}',
                            style: HudTheme.caption.copyWith(
                              color: HudTheme.cyan,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: HudTheme.body,
                        decoration: const InputDecoration(
                          hintText: '发送聊天…',
                          hintStyle: HudTheme.caption,
                          isDense: true,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: HudTheme.panelBorder),
                          ),
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      color: HudTheme.cyan,
                      onPressed: () => _send(_input.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(duelChatProvider.notifier).sendChat(trimmed);
    _input.clear();
  }
}

/// 区域浏览器（墓地/额外/除外）底部弹层。
///
/// 数据与动作全部走 biz derived provider（对照 room2 zone_browser_modal
/// 的接线）：zoneBrowserEntriesProvider 在选择窗口激活时会把可发动的
/// 区域内卡合并进列表，zoneBrowserActionsProvider 把「发动/特殊召唤」
/// 等动作译成选择窗口应答——旧实现纯检视，墓地诱发发动类操作在 3D 房
/// 无法完成（死锁）。
class _ZoneBrowser extends ConsumerWidget {
  const _ZoneBrowser({required this.zoneKey});

  final String zoneKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(zoneBrowserEntriesProvider(zoneKey));
    final overlay = ref.watch(fieldOverlayProvider);
    final actions = ref.watch(zoneBrowserActionsProvider(zoneKey));
    final activatable = ref.watch(
      zoneBrowserActivatableSequencesProvider(zoneKey),
    );
    final overlayN = ref.read(fieldOverlayProvider.notifier);
    final boardN = ref.read(duelFieldProvider.notifier);
    // 观战者没有「己方 / 对方」，用引擎编号代替。
    final isDuelist = ref.watch(
      duelRoomProvider.select((s) => s.selfType.isDuelist),
    );
    final title = switch (zoneKey) {
      'self_grave' => '${_seatLabel(0, isDuelist: isDuelist)}墓地',
      'opp_grave' => '${_seatLabel(1, isDuelist: isDuelist)}墓地',
      'self_removed' => '${_seatLabel(0, isDuelist: isDuelist)}除外',
      'opp_removed' => '${_seatLabel(1, isDuelist: isDuelist)}除外',
      'self_extra' => '${_seatLabel(0, isDuelist: isDuelist)}额外卡组',
      'opp_extra' => '${_seatLabel(1, isDuelist: isDuelist)}额外卡组',
      _ => zoneKey,
    };
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: overlayN.closeZoneBrowser,
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        Expanded(
          child: Container(
            color: HudTheme.bgDeep,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$title（${entries.length}）', style: HudTheme.title),
                      const Spacer(),
                      InkWell(
                        onTap: overlayN.closeZoneBrowser,
                        child: const Icon(
                          Icons.close,
                          color: HudTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: HudTheme.panelBorder),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text('（空）', style: HudTheme.caption),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 82,
                                  childAspectRatio: 59 / 86,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final selected =
                                  overlay.selectedZoneBrowserSequence ==
                                  entry.sequence;
                              // 当前窗口下可发动/可召唤的卡：右上角
                              // 「可发动」角标（与选中描边区分）。
                              final canActivate = activatable.contains(
                                entry.sequence,
                              );
                              return GestureDetector(
                                onTap: () {
                                  final code = entry.code;
                                  unawaited(boardN.ensureCardInfo(code));
                                  // 点卡 = 选中（驱动动作菜单）+ 检视；
                                  // 可执行动作经下方动作栏回包应答。
                                  overlayN.applyZoneBrowserCardInspect(
                                    entry.sequence,
                                    code,
                                    boardN.getCardInfo(code),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: selected
                                        ? Border.all(
                                            color: HudTheme.cyan,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CardImage(
                                          code: entry.code,
                                          width: 82,
                                          height: 120,
                                        ),
                                        if (canActivate)
                                          Positioned(
                                            left: 2,
                                            top: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: HudTheme.cyan,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: const Text(
                                                '可发动',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // 可执行动作（发动/特殊召唤等，biz 已译成选择窗口应答）
                  if (actions.isNotEmpty) ...[
                    const Divider(color: HudTheme.panelBorder),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final action in actions)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: HudTheme.cyanDim,
                            ),
                            onPressed: action.onTap,
                            child: Text(action.label),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
