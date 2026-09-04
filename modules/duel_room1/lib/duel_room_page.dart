import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/duel_message_router.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/duel_log_drawer.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:duel_room1/constants.dart';
import 'package:duel_room1/field/duel_field_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/platform/duel_immersive_mode.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';
import 'package:duel_room1/platform/duel_shortcuts.dart';
import 'duel_result_page.dart';
import 'duel_room_exit.dart';
import 'package:duel_room1/waiting/waiting_room_page.dart';
import 'package:duel_room1/hand_turn/hand_select_panel.dart';
import 'package:duel_room1/hand_turn/widgets/stage_selection_panel_host.dart';
import 'package:duel_room1/hand_turn/turn_select_panel.dart';

class DuelResultDismissal {
  Object? _dismissedResult;

  Map<String, Object?>? effective(Map<String, Object?>? result) =>
      identical(result, _dismissedResult) ? null : result;

  void dismiss(Map<String, Object?> result) => _dismissedResult = result;
}

bool shouldShowDuelRoomBackButton({
  required bool isInDuel,
  required bool hasResult,
}) => !isInDuel && !hasResult;

class DuelRoomScaffold extends StatelessWidget {
  const DuelRoomScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('duel-room-page'),
    backgroundColor: Colors.brown.shade900,
    body: body,
  );
}

class DuelRoomShell extends StatelessWidget {
  const DuelRoomShell({
    super.key,
    required this.content,
    required this.isInDuel,
    required this.hasResult,
    required this.onBack,
    this.platform,
    this.controller,
  });

  final Widget content;
  final bool isInDuel;
  final bool hasResult;
  final VoidCallback onBack;
  final DuelPlatform? platform;
  final DuelSystemUiController? controller;

  @override
  Widget build(BuildContext context) {
    return DuelImmersiveMode(
      platform: platform,
      controller: controller,
      child: DuelRoomScaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: content),
            if (shouldShowDuelRoomBackButton(
              isInDuel: isInDuel,
              hasResult: hasResult,
            ))
              DuelRoomBackButton(onPressed: onBack),
          ],
        ),
      ),
    );
  }
}

class DuelRoomBackButton extends StatelessWidget {
  const DuelRoomBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final layout = DuelRoomLayout.of(context);
    return Positioned(
      left: layout.safePadding.left + layout.panelGap,
      top: layout.safePadding.top + layout.panelGap,
      child: Semantics(
        button: true,
        label: '退出房间',
        child: Tooltip(
          message: '退出房间',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: SizedBox.square(
                key: const ValueKey('duel-room-back-button'),
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xE6080E18),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x4D00F0FF)),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF00F0FF),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 决斗房间入口：每次进房创建独立的 [ProviderScope]，
/// 房间/对局/聊天状态随页面销毁自动回收（替代旧版的全局单例 +
/// 手动 reset）。宿主路由无需任何 Provider 装配。
///
/// scope 以 [duelRoomServiceContainer] 为 parent：服务 provider
/// （duelService/dataService/ygoSoundService）未在本 scope override，
/// 解析上溯到应用级容器，保持单例；下列房间级 provider 在此 override，
/// 保证每次进房都是全新状态、随 scope 销毁自动 dispose。
class DuelRoomPage extends StatelessWidget {
  const DuelRoomPage({super.key, required this.args});

  /// 建房/匹配参数快照（由 MatchStore.toDuelRoomParams 生成），经路由 extra 传入。
  final Map<String, Object?> args;

  @override
  Widget build(BuildContext context) {
    // Riverpod 3.0：ProviderScope.parent 已移除。改用
    // UncontrolledProviderScope 把应用级容器暴露到 widget 树，内层
    // ProviderScope 自动沿树向上链接它作为 parent——服务 provider
    // 保持应用级单例，房间/对局状态仍在房间 scope 内重建。
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final viewport = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : mediaQuery.size.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaQuery.size.height,
        );
        final spec = DuelRoomLayoutSpec.resolve(
          viewport,
          safePadding: mediaQuery.viewPadding,
        );
        return DuelRoomLayout(
          spec: spec,
          child: UncontrolledProviderScope(
            container: duelRoomServiceContainer,
            child: ProviderScope(
              overrides: [
                duelRoomProvider.overrideWith(DuelRoomNotifier.new),
                duelChatProvider.overrideWith(DuelChatNotifier.new),
                // 四个子状态在房间 scope 内重建（不 override 会解析到 parent
                // 容器变成跨房间单例）；协调器读取子状态并负责流订阅回收。
                duelFieldProvider.overrideWith(DuelFieldNotifier.new),
                selectWindowProvider.overrideWith(SelectWindowNotifier.new),
                cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
                fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
                duelMessageRouterProvider.overrideWith(DuelMessageRouter.new),
                // 连接生命周期钩子必须在房间 scope 内实例化：它只 watch 应用级
                // duelServiceProvider，不 override 会解析到根容器，onDispose 只在
                // 应用退出时触发，房间 scope 销毁时断连兜底失效。
                roomConnectionLifetimeProvider.overrideWith(
                  roomConnectionLifetime,
                ),
              ],
              child: _DuelRoomView(args: args),
            ),
          ),
        );
      },
    );
  }
}

class _DuelRoomView extends ConsumerStatefulWidget {
  const _DuelRoomView({required this.args});

  final Map<String, Object?> args;

  @override
  ConsumerState<_DuelRoomView> createState() => _DuelRoomViewState();
}

class _DuelRoomViewState extends ConsumerState<_DuelRoomView> {
  final DuelResultDismissal _resultDismissal = DuelResultDismissal();

  /// 已读聊天消息计数：打开/关闭抽屉时对齐到最新；关闭期间的新消息
  /// 在抽屉开关按钮上显示未读角标（弥补旧常驻聊天面板的可见性）。
  int _seenChatCount = 0;

  /// 日志/聊天抽屉是否展开（非模态常驻面板，见 build 的 Stack）。
  bool _logDrawerOpen = false;

  /// 断连提醒弹窗是否展示中：弹窗弹出后若 MSG_WIN 才从节奏泵
  /// 消费到（服务端在关连接前的最后一个 TCP 段里发了结果），
  /// 需要关掉断连弹窗让结算弹窗展示。
  bool _disconnectDialogOpen = false;

  /// 开合日志/聊天抽屉：非模态——无遮罩、不阻断场地交互、点外部
  /// 不关闭，只能由右下角按钮（再次点击）或抽屉内的关闭按钮收起。
  /// 面板常驻页面 Stack（不经路由），开合走 AnimatedSlide 滑入滑出。
  void _toggleLogDrawer() {
    setState(() {
      _logDrawerOpen = !_logDrawerOpen;
      if (!_logDrawerOpen) {
        // 抽屉内已读到最新：关闭时对齐已读基线，清掉角标。
        _seenChatCount = ref.read(duelChatProvider).messages.length;
      }
    });
  }

  /// 抽屉开关按钮（带未读角标，打开时角标隐藏）：所有阶段统一
  /// 浮动在右下角（旧常驻聊天面板的位置）。
  Widget _buildLogDrawerButton() {
    final chatCount = ref.watch(
      duelChatProvider.select((s) => s.messages.length),
    );
    final unread = _logDrawerOpen
        ? 0
        : (chatCount - _seenChatCount).clamp(0, 999);
    return _DuelRoomLogButton(
      open: _logDrawerOpen,
      unread: unread,
      onTap: _toggleLogDrawer,
    );
  }

  @override
  void initState() {
    super.initState();
    // 全应用已横屏（main.dart lockAppLandscape），房间无需单独锁方向。
    _connect();
  }

  Future<void> _connect() async {
    final args = widget.args;
    final uri = args['uri'] as Uri?;
    final username = args['username'] as String? ?? 'Guest';
    final password = args['serverPassword'] as String? ?? '';
    if (uri == null) {
      // 参数缺失：给用户可见的错误与退出路径，而不是静默返回卡在空房间页。
      _reportConnectError('房间参数缺失：未提供服务器地址');
      return;
    }

    final duelService = ref.read(duelServiceProvider);

    // connect() 必须在流订阅之前调用，否则 DuelService 门面会把订阅
    // 路由到默认的 WebSocket 服务（而不是 AI/TCP 等目标协议）。
    try {
      await duelService.connect(uri);
    } catch (e) {
      if (!mounted) return;
      _reportConnectError('连接房间失败：$e');
      return;
    }
    if (!mounted) return;

    ref.read(duelRoomProvider.notifier).start();
    ref.read(duelChatProvider.notifier).start();
    ref
        .read(duelMessageRouterProvider.notifier)
        .start(
          // l10n 依赖 BuildContext，以闭包形式注入给 router。
          phaseLabel: (phase) => getDuelPhaseText(context, phase),
        );

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
  }

  /// 连接失败/参数缺失的统一处理：
  /// 1) 经房间 provider 的 errorMessage 渠道提示（复用现有 SnackBar 展示）；
  /// 2) 弹一个「回首页」对话框给用户退出路径，避免卡死在无连接的房间页。
  void _reportConnectError(String message) {
    ref.read(duelRoomProvider.notifier).setErrorText(message);
    // uri 缺失时本方法在 initState 同步触发，路由尚未就绪；
    // 对话框统一延后到帧之后再弹。错误本身已由 errorMessage 渠道提示。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('进入房间失败'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/');
              },
              child: const Text('回首页'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 连接生命周期钩子：无论以何种方式离开（系统返回、导航、被踢），
    // 房间 scope 销毁时兜底断开单例 duelService 的 socket，
    // 与 backHome 里的显式 disconnect 幂等共存。
    ref.watch(roomConnectionLifetimeProvider);
    // 房间玩家列表（日志文案中的玩家名）同步到对局状态。
    ref.listen(duelRoomProvider.select((s) => s.players), (prev, next) {
      ref.read(duelFieldProvider.notifier).syncPlayers(next);
    });
    // 服务器错误 → SnackBar。
    ref.listen(duelRoomProvider.select((s) => s.errorMessage), (prev, next) {
      if (next == null || next.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), backgroundColor: Colors.red.shade700),
      );
      ref.read(duelRoomProvider.notifier).clearError();
    });
    // 离开房间（RoomNotJoined）→ 回首页。
    // 统一走 leaveRoomAfterNotJoined：主动退出（backHome）触发断连时
    // 这里补做导航兜底（若主动退出方在断开期间被销毁，保证仍能离房）；
    // 服务器踢人/断连（未走 backHome）时负责完整离房流程。
    ref.listen(duelRoomProvider.select((s) => s.stage), (prev, next) {
      if (prev is! RoomNotJoined && next is RoomNotJoined) {
        // MSG_WIN 可能还排在节奏泵队列里（观战/爆发积压，服务器在关
        // 连接前的最后一个 TCP 段才发结果）：hasPendingWin 把它算作
        // 已有结果，否则正常结算会被误判成意外断连。
        final router = ref.read(duelMessageRouterProvider.notifier);
        final hasResult =
            ref.read(duelFieldProvider).duelResult != null ||
            router.hasPendingWin;
        // 决斗刚结束就被断开（AI 对决的本地服务端在 MSG_WIN 后立即
        // 关连接）：停留展示结算弹窗，导航由其「返回首页」按钮触发。
        if (shouldHoldForDuelResult(
          prev: prev,
          next: next,
          hasDuelResult: hasResult,
        )) {
          // 同步静音排空泵积压：duelResult 立即落位，结算弹窗直接
          // 展示终局，不再播断连后的「鬼魂动画」。
          router.flushPendingMessages();
          return;
        }
        // 意外断连（对局中被服务器断开/网络重置）：停留并弹窗提醒，
        // 不再静默丢回首页；主动退出（isLeaving）维持直接导航。
        if (shouldPromptDisconnect(
          prev: prev,
          next: next,
          isLeaving: ref.read(duelRoomProvider.notifier).isLeaving,
          hasDuelResult: hasResult,
        )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || _disconnectDialogOpen) return;
            _disconnectDialogOpen = true;
            showDisconnectDialog(context: context, ref: ref).whenComplete(() {
              _disconnectDialogOpen = false;
            });
          });
          return;
        }
        unawaited(leaveRoomAfterNotJoined(context, ref));
      }
    });
    // 断连弹窗弹出期间 MSG_WIN 才消费到（结果曾排在节奏泵队列里）：
    // 关掉断连弹窗，结算弹窗随之按既有 roundResult 逻辑挂载。
    ref.listen(duelFieldProvider.select((s) => s.duelResult), (prev, next) {
      if (next != null && _disconnectDialogOpen) {
        _disconnectDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
    final room = ref.watch(duelRoomProvider);
    final roomCtl = ref.read(duelRoomProvider.notifier);
    // 本局结果（MSG_WIN 设置；下一局 MSG_START 时 handleStart 清空）。
    final roundResult = ref.watch(
      duelFieldProvider.select((s) => s.duelResult),
    );
    final effectiveRoundResult = _resultDismissal.effective(roundResult);

    final stage = room.stage;
    final isInDuel = stage is RoomInDuel;
    final isSelectingHand = stage is RoomSelectingHand;
    final isHandResult = stage is RoomHandResult;
    final isSelectingTurn = stage is RoomSelectingTurn;
    // 场地页自进房起常驻挂载作为全屏背景（对齐 godot：3D 场地始终在
    // 场景中，RoomOverlay 只是盖在上面的半透明层）；等待室改为半透明
    // 弹窗浮在场地上（弹窗之外全透明），非对局阶段场地页隐藏 HUD
    // （hudVisible）。不再做“等待页 ↔ 场地页”整页切换，
    // 开局/局间等待的闪跳也随之消除。
    final content = Stack(
      fit: StackFit.expand,
      children: [
        DuelFieldPage(room.players, isInDuel: isInDuel),
        if (stage is RoomInLobby || stage is RoomSideDecking)const WaitingRoomPage(),
        // 猜拳（含结果展示）：直接挂在页面层，不经等待室弹窗。
        // 面板包容内容、屏幕居中，不为右侧聊天浮窗让位。
        if (isSelectingHand || isHandResult)
          HandSelectPanel(
            isResult: isHandResult,
            myHand: room.myHandResult,
            opponentHand: room.opponentHandResult,
            enabled: !room.autoHandEnabled,
            onSendHand: roomCtl.sendHand,
          ),
        // 选先后攻（仅猜拳胜者进入该阶段）。
        if (isSelectingTurn)
          TurnSelectPanel(
            enabled: !room.autoTurnOrderEnabled,
            onSendTp: roomCtl.sendTp,
          ),
        // 日志/聊天合并抽屉：非模态常驻面板（右侧贴边、全高），
        // 无遮罩、不拦截面板外点击（场地/等待室照常可交互）、
        // 点外部不关闭；AnimatedSlide 滑入滑出，常驻挂载保住
        // 输入框与滚动状态。置于开关按钮之下（按钮保持可点）。
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: InteractionIsolation(
            active: _logDrawerOpen && effectiveRoundResult == null,
            excludeSemantics: true,
            child: AnimatedSlide(
              offset: _logDrawerOpen ? Offset.zero : const Offset(1, 0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: DuelLogDrawer(onClose: _toggleLogDrawer),
            ),
          ),
        ),
        // 日志/聊天合并抽屉开关：所有阶段统一浮动在右下角
        //（旧常驻聊天面板的位置；等待室不再占用 AppBar actions）。
        // 抽屉展开时按钮随动左移，让出面板（不遮挡抽屉底部输入区）。
        if (effectiveRoundResult == null)
          AnimatedPositioned(
            right: _logDrawerOpen ? DuelLogDrawer.widthFor(context) + 8 : 16,
            bottom: 16,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: SafeArea(child: _buildLogDrawerButton()),
          ),
        // 结算必须是 Stack 最上层，完整拦截场地及阶段面板交互。
        if (effectiveRoundResult != null)
          Positioned.fill(
            child: DuelResultPage(
              result: effectiveRoundResult,
              onDismissed: () => setState(
                () => _resultDismissal.dismiss(effectiveRoundResult),
              ),
            ),
          ),
      ],
    );
    return DuelRoomShell(
      isInDuel: isInDuel,
      hasResult: effectiveRoundResult != null,
      onBack: () => backHomeDialog(
        context: context,
        ref: ref,
        title: '退出房间',
        content: '是否确认退出当前房间？',
      ),
      content: DuelShortcuts(
        child: PopScope(
          // 系统返回不直接弹出房间路由：先弹确认框，避免误触返回
          // 直接离房（服务器仍占座）。确认退出走 backHomeDialog → backHome。
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (effectiveRoundResult != null) return;
            // 对局中若正有模态选择窗口，返回键由模态自己处理（取消选择），
            // 这里不再叠加房间退出确认。
            final modalActive =
                ref.read(selectWindowProvider.notifier).selectPromptMode ==
                SelectPromptMode.modal;
            if (modalActive) return;
            backHomeDialog(
              context: context,
              ref: ref,
              title: '退出房间',
              content: '是否确认退出当前房间？',
            );
          },
          child: content,
        ),
      ),
    );
  }
}

class _DuelRoomLogButton extends StatelessWidget {
  const _DuelRoomLogButton({
    required this.open,
    required this.unread,
    required this.onTap,
  });

  final bool open;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? '收起日志 / 聊天' : '日志 / 聊天',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('duel-log-button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                key: const ValueKey('duel-log-button-visual'),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xE6080E18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x4D00F0FF)),
                ),
                child: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: Color(0xFF00F0FF),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
