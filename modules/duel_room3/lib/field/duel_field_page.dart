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

import '../bridge/duel_3d_bridge.dart';
import '../duel_room_exit.dart';
import '../hud/action_bar.dart';
import '../hud/card_detail_panel.dart';
import '../hud/confirm_cards_dialog.dart';
import '../hud/confirm_floating_card.dart';
import '../hud/duel_overlays.dart';
import '../hud/hand_bar.dart';
import '../hud/hud_theme.dart';
import '../hud/lp_bar.dart';
import '../hud/phase_rail.dart';
import '../hud/turn_order_hint.dart';
import '../hud/zone_count_bar.dart';
import '../scene3d/duel_3d_game.dart';

/// 3D 决斗场地页：flame_3d 场景 + MDPro3 风格 HUD 叠层。
class DuelFieldPage3D extends ConsumerStatefulWidget {
  const DuelFieldPage3D({super.key, required this.players});

  final List<PlayerInfo> players;

  @override
  ConsumerState<DuelFieldPage3D> createState() => _DuelFieldPage3DState();
}

class _DuelFieldPage3DState extends ConsumerState<DuelFieldPage3D> {
  Duel3DGame? _game;
  Duel3DBridge? _bridge;
  bool _logDrawerOpen = false;
  bool _showTurnOrderHint = false;
  bool _isFirstTurn = false;

  DuelFieldState get _board => ref.read(duelFieldProvider);
  DuelFieldNotifier get _boardN => ref.read(duelFieldProvider.notifier);
  SelectWindowState get _select => ref.read(selectWindowProvider);
  SelectWindowNotifier get _selectN => ref.read(selectWindowProvider.notifier);
  FieldOverlayState get _overlay => ref.read(fieldOverlayProvider);
  FieldOverlayNotifier get _overlayN => ref.read(fieldOverlayProvider.notifier);

  @override
  void dispose() {
    _bridge?.detach();
    super.dispose();
  }

  bool _gpuReady = false;
  Object? _gpuError;

  /// 手势容器坐标基准（取它自己的 RenderBox，而非外层页面容器——
  /// 树结构变化时后者会静默错位）。
  final GlobalKey _gameAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initGpu();
  }

  /// 先预载 shader（GpuBackend）再挂载 GameWidget，避免首帧
  /// 材质初始化竞态（Failed to initialize ShaderLibrary）。
  /// 失败进错误态（可重试；ensureGpuBackend 失败后会复位缓存）。
  void _initGpu() {
    Duel3DGame.ensureGpuBackend()
        .then((_) {
          if (mounted) setState(() => _gpuReady = true);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _gpuError = e);
        });
  }

  /// 等待 myController 就绪后创建 Game（场地页挂载时已 RoomInDuel，
  /// myController 已由 MSG_START 的 playerType 确定——selfType 锚定
  /// 的是 mySeat 而非 controller；防御性再等一帧）。
  void _ensureGame() {
    if (_game != null) return;
    final board = _board;
    final game = Duel3DGame(myController: board.myController);
    game.onSlotTap = _handleSlotTap;
    game.onStandeeTap = _handleStandeeTap;
    _game = game;
    _bridge = Duel3DBridge(game: game)..attach(ref);
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

  /// 挂载先后攻提示浮层。观战者由 build 里的 ref.listen 过滤，
  /// 这里只做去重与状态记录；提示自身负责淡入 → 停留 → 淡出，
  /// 并在 onDismiss 回调里复位显示状态。
  void _revealTurnOrderHint(bool isFirst) {
    if (!mounted || _showTurnOrderHint) return;
    _isFirstTurn = isFirst;
    setState(() => _showTurnOrderHint = true);
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
    // 先后攻提示：随房间 stage 进入 RoomInDuel 触发（isFirstTurn 与 stage
    // 由服务器同帧下发）。match 多局之间 isFirstTurn 可能同值、select 不触发，
    // 故监听 stage 变迁而非 isFirstTurn 值本身（对照 room1 的做法）。
    ref.listen(duelRoomProvider.select((s) => s.stage), (prev, next) {
      if (next is! RoomInDuel || prev is RoomInDuel) return;
      final room = ref.read(duelRoomProvider);
      final isFirst = room.isFirstTurn;
      if (isFirst == null || room.selfType == PlayerType.observer) return;
      _revealTurnOrderHint(isFirst);
    });

    _ensureGame();
    final game = _game!;
    final board = ref.watch(duelFieldProvider);
    final overlay = ref.watch(fieldOverlayProvider);
    final select = ref.watch(selectWindowProvider);
    final fieldActions = ref.watch(fieldActionMenuProvider);
    final handActions = ref.watch(handActionMenuProvider);
    final phaseActions = ref.watch(phaseActionMenuProvider);

    final isMyTurn = board.currentPlayer == board.myController;
    final selectN = ref.read(selectWindowProvider.notifier);
    final selfName = board.playerNameOf(board.myController);
    final oppName = board.playerNameOf(1 - board.myController);
    final canCancel = overlay.hasAnyOverlayOpen ||
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
                  const Icon(Icons.error_outline, color: HudTheme.danger, size: 40),
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
            const Center(
              child: CircularProgressIndicator(color: HudTheme.cyan),
            )
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
                child: GameWidget(game: game),
              ),
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

          // 右侧阶段轨道
          Positioned(
            right: 12,
            bottom: 150,
            child: PhaseRail(
              current: board.phase,
              isMyTurn: isMyTurn,
              phaseActions: phaseActions,
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
                    '回合 ${board.turnCount} · ${isMyTurn ? "我方" : "对方"}',
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
                        label: '我方',
                        seconds: board.selfTimeLeft,
                        accent: HudTheme.cyan,
                      ),
                      const SizedBox(width: 6),
                      _TurnTimerBadge(
                        label: '对方',
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
                    onRemovedTap: () => _overlayN.openZoneBrowser('opp_removed'),
                  ),
                ),
              ],
            ),
          ),

          // 右上：菜单按钮组
          Positioned(
            right: 12,
            top: 12,
            child: Row(
              children: [
                _HudIconButton(
                  icon: Icons.article_outlined,
                  tooltip: '决斗日志',
                  onTap: () => setState(() => _logDrawerOpen = true),
                ),
                const SizedBox(width: 8),
                _HudIconButton(
                  icon: Icons.flag_outlined,
                  tooltip: '投降',
                  onTap: () => surrenderDialog(context: context, ref: ref),
                ),
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
                      onRemovedTap: () => _overlayN.openZoneBrowser('self_removed'),
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
                  selectableSequences:
                      selectN.inlineSelectableHandSequences,
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HudTheme.cyan,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('对方行动中…', style: HudTheme.caption),
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
              child: _LogDrawer(onClose: () => setState(() => _logDrawerOpen = false)),
            ),

          // 区域浏览器
          if (overlay.openZoneBrowserKey != null)
            Positioned.fill(
              child: _ZoneBrowser(zoneKey: overlay.openZoneBrowserKey!),
            ),

          // 先后攻提示（B4）：居中短暂展示，IgnorePointer 不拦截手势；
          // TurnOrderHint 自身负责淡入 → 停留 → 淡出 → onDismiss。
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
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
          child: Icon(icon, color: HudTheme.textPrimary, size: 18),
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
    final overlayN = ref.read(fieldOverlayProvider.notifier);
    final boardN = ref.read(duelFieldProvider.notifier);
    final title = switch (zoneKey) {
      'self_grave' => '己方墓地',
      'opp_grave' => '对方墓地',
      'self_removed' => '己方除外',
      'opp_removed' => '对方除外',
      'self_extra' => '己方额外卡组',
      'opp_extra' => '对方额外卡组',
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
                      Text(
                        '$title（${entries.length}）',
                        style: HudTheme.title,
                      ),
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
                                    child: CardImage(
                                      code: entry.code,
                                      width: 82,
                                      height: 120,
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
