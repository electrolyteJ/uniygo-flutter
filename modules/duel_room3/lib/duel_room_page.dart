import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/duel_message_router.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:duelink/duelink.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'duel_room_exit.dart';
import 'end/duel_end_page.dart';
import 'field/duel_field_page.dart';
import 'loading/intro/intro_phases.dart';
import 'loading/duel_loading_page.dart';
import 'waiting/waiting_room_page.dart';

/// 房间的四个阶段，对应 [TabBarView] 的四个页。
///
/// 顺序即 tab 顺序，**不可重排**——[DuelRoomPage3D] 用 `.index` 驱动控制器。
enum _Tab {
  /// ① 等候页：组卡、等对手、观战列表；match 局间换备也回这里。
  waiting,

  /// ② 加载页：入场演出（Seamless Loading Screen），不持有 3D。
  loading,

  /// ③ 场地页：真正的决斗场地与 HUD。
  field,

  /// ④ 结束页：本局结算（胜/负/平 + 双方 LP + 结束原因）。
  end,
}

/// duel_room3 决斗房间入口：纯 flame_3d 3D 场地 + MDPro3 风格 HUD。
///
/// 接线方式与 duel_room2 一致：每次进房创建独立 [ProviderScope]，
/// 房间/对局/聊天状态随页面销毁自动回收；服务 provider 解析上溯到
/// 应用级容器保持单例。
///
/// **仅支持原生平台**（flame_3d 依赖 Flutter GPU）。本模块内不再做
/// `kIsWeb` 判断：「Web 走哪个页面」属于宿主的降级路由职责，放在这里
/// 只会多一层永远不会命中的分支。
class DuelRoomPage3D extends StatelessWidget {
  const DuelRoomPage3D({super.key, required this.args});

  /// 建房/匹配参数快照，经路由 extra 传入（uri / 密码 / 用户名 / 房名等）。
  final Map<String, Object?> args;

  @override
  Widget build(BuildContext context) {
    // Riverpod 3.0：ProviderScope.parent 已移除。改用
    // UncontrolledProviderScope 把应用级容器暴露到 widget 树，内层
    // ProviderScope 自动沿树向上链接它作为 parent——服务 provider
    // 保持应用级单例，房间/对局状态仍在房间 scope 内重建。
    return UncontrolledProviderScope(
      container: duelRoomServiceContainer,
      child: ProviderScope(
        overrides: [
          duelRoomProvider.overrideWith(DuelRoomNotifier.new),
          duelChatProvider.overrideWith(DuelChatNotifier.new),
          duelFieldProvider.overrideWith(DuelFieldNotifier.new),
          selectWindowProvider.overrideWith(SelectWindowNotifier.new),
          cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
          fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
          duelMessageRouterProvider.overrideWith(DuelMessageRouter.new),
          // 连接生命周期钩子必须在房间 scope 内实例化：它只 watch 应用级
          // duelServiceProvider，不 override 会解析到根容器，onDispose 只在
          // 应用退出时触发，房间 scope 销毁时断连兜底失效。
          roomConnectionLifetimeProvider.overrideWith(roomConnectionLifetime),
        ],
        child: _DuelRoomView(args: args),
      ),
    );
  }
}

class _DuelRoomView extends ConsumerStatefulWidget {
  const _DuelRoomView({required this.args});

  final Map<String, Object?> args;

  @override
  ConsumerState<_DuelRoomView> createState() => _DuelRoomViewState();
}

class _DuelRoomViewState extends ConsumerState<_DuelRoomView>
    with SingleTickerProviderStateMixin {
  /// 断连提醒弹窗是否展示中：弹窗弹出后若 MSG_WIN 才从节奏泵
  /// 消费到（服务端在关连接前的最后一个 TCP 段里发了结果），
  /// 需要关掉断连弹窗让结算 overlay 展示。
  bool _disconnectDialogOpen = false;

  /// 入场动画是否已播完（每局只播一次；换备/重开不重播）。
  ///
  /// 放在页面 state 而非页面内部：加载页卸载后重新挂载不应重播，
  /// 且 [RoomInDuel] 在多局之间会来回切换（DuelEnded → SideDecking →
  /// InDuel），必须由页面侧记住「本局的入场已经给过」。
  bool _introDone = false;

  /// 三页的 tab 控制器：索引完全由状态驱动，用户不可滑动。
  late final TabController _tabController = TabController(
    length: _Tab.values.length,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 入场演出播完：标记完成，tab 切到场地页。
  void _onIntroFinished() {
    if (!mounted || _introDone) return;
    setState(() => _introDone = true);
  }

  Future<void> _connect() async {
    final args = widget.args;
    final uri = args['uri'] as Uri?;
    final username = args['username'] as String? ?? 'Unknown';
    final password = args['serverPassword'] as String? ?? '';
    if (uri == null) {
      _reportConnectError('房间参数缺失：未提供服务器地址');
      return;
    }

    final duelService = ref.read(duelServiceProvider);
    final roomName = args['roomName'] as String?;
    final roomId = args['roomId'] as String?;
    console.log('roomId=$roomId');
    // connect() 必须在流订阅之前调用（同 duel_room2）。
    try {
      await duelService.connect(uri);
    } catch (e) {
      if (!mounted) return;
      _reportConnectError('连接房间失败：$e');
      return;
    }
    if (!mounted) return;

    ref.read(duelRoomProvider.notifier).start();
    ref.read(duelRoomProvider.notifier).setRoomName(roomName);
    // 房间邀码：建房/进房链路带入（没有的房间类型为 null）。
    ref.read(duelRoomProvider.notifier).setRoomId(roomId);
    ref.read(duelChatProvider.notifier).start();
    ref
        .read(duelMessageRouterProvider.notifier)
        .start(phaseLabel: (phase) => getDuelPhaseText(phase));

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
  }

  void _reportConnectError(String message) {
    ref.read(duelRoomProvider.notifier).setErrorText(message);
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
                // 进房是 context.go 替换式导航，房间页即栈底，
                // maybePop 无处可退（人会留在断连死房间）。
                context.go('/');
              },
              child: const Text('返回'),
            ),
          ],
        ),
      );
    });
  }

  /// 组装入场动画的双方席位数据（名字 / 先攻 / 观战）。
  ///
  /// 名字与座位直接取 [duelFieldProvider] 的已解析结果（与场地页 HUD
  /// 同一数据源，避免入场写的名字和落地后不一致）。
  DuelIntroSceneData _buildIntroData(WidgetRef ref, DuelRoomState room) {
    final board = ref.read(duelFieldProvider);
    final isSpectator = room.selfType == PlayerType.observer;

    final myName = board.playerNameOf(board.myController);
    final oppName = board.playerNameOf(1 - board.myController);
    // isFirstTurn 由服务器随 MSG_START 下发；未到时按后攻兜底
    // （入场只是呈现，真实先后攻以场地 HUD 为准）。
    final iGoFirst = room.isFirstTurn ?? false;

    return DuelIntroSceneData(
      myName: myName.isEmpty ? (isSpectator ? '观战者' : '你') : myName,
      opponentName: oppName.isEmpty ? '对手' : oppName,
      iGoFirst: iGoFirst,
      isSpectator: isSpectator,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(roomConnectionLifetimeProvider);
    ref.listen(duelRoomProvider.select((s) => s.players), (prev, next) {
      ref.read(duelFieldProvider.notifier).syncPlayers(next);
    });
    ref.listen(duelRoomProvider.select((s) => s.errorMessage), (prev, next) {
      if (next == null || next.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), backgroundColor: Colors.red.shade700),
      );
      ref.read(duelRoomProvider.notifier).clearError();
    });
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
        // 关连接）：停留展示结算 overlay，导航由其「返回首页」按钮触发。
        if (shouldHoldForDuelResult(
          prev: prev,
          next: next,
          hasDuelResult: hasResult,
        )) {
          // 同步静音排空泵积压：duelResult 立即落位，结算 overlay
          // 直接展示终局，不再播断连后的「鬼魂动画」。
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
    // 关掉断连弹窗，结算页按既有 duelResult 自动展示。
    ref.listen(duelFieldProvider.select((s) => s.duelResult), (prev, next) {
      if (next != null && _disconnectDialogOpen) {
        _disconnectDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    final room = ref.watch(duelRoomProvider);
    final isInDuel = room.stage is RoomInDuel;
    // 结果非空即进入谢幕阶段（第 ④ 页）。换备阶段（RoomSideDecking）同样
    // 归这里：此时 stage 已不是 RoomInDuel，但玩家要看的是本局结果 +
    // 「进入换备阶段」按钮，交给结算页自己决定按钮文案。
    final hasResult = ref.watch(
      duelFieldProvider.select((s) => s.duelResult != null),
    );
    final isEnded = hasResult && !isInDuel;

    // 四页解耦：等候 / 加载 / 场地 / 结束 各自是独立的 Widget 子树，
    // 各自管理自己的资源，页面之间**不共享任何实例**。
    //
    // 索引完全由状态驱动，禁止用户滑动（入场动画不能被滑回去）。
    final tabIndex = isEnded
        ? _Tab.end
        : !isInDuel
        ? _Tab.waiting
        : (_introDone ? _Tab.field : _Tab.loading);

    // 状态驱动 tab：索引变了才切（避免每帧 animateTo 打断动画）。
    if (_tabController.index != tabIndex.index) {
      // 不能在 build 中直接改 controller：排到帧后执行。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tabController.index != tabIndex.index) {
          _tabController.animateTo(tabIndex.index);
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 对局中若正有模态选择窗口，返回键由模态自己处理（取消选择），
        // 这里不再叠加房间退出确认（对齐 room2）。
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
      child: Scaffold(
        key: const ValueKey('duel-room3-page'),
        backgroundColor: const Color(0xFF05070F),
        // 聊天是盖在房间上的弹层：键盘弹起时房间本身不跟着压缩，只让弹层上移。
        resizeToAvoidBottomInset: false,
        // 无 AppBar：等待室/对局 HUD 自带沉浸式顶栏，退出入口在等待室顶栏的返回箭头。
        appBar: null,
        // 四个阶段是平级的 tab 页，没有叠层：结算不再盖在场地之上，
        // 而是独立的第 ④ 页。
        body: TabBarView(
          controller: _tabController,
          // 禁止滑动：tab 只能由状态驱动切换。
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // ① 等候页
            WaitingRoomPage3D(
              roomId: widget.args['roomId'] as String?,
              roomName: widget.args['roomName'] as String?,
              isAiRoom: widget.args['aiRoom'] == true,
              // 邀请二维码带上服务器地址，扫码方据此推断环境。
              serverHost: (widget.args['uri'] as Uri?)?.host,
              serverPort: (widget.args['uri'] as Uri?)?.port,
            ),

            // ② 加载页：纯入场演出（Seamless Loading Screen）。
            //
            // 演完才切 ③；_introDone 为真后本页立刻换成
            // SizedBox.shrink()，TabBarView（底层 PageView）随即销毁
            // 它的子树——所以它不能持有任何要交接给 ③ 的东西。
            if (_introDone)
              const SizedBox.shrink()
            else
              DuelLoadingPage(
                data: _buildIntroData(ref, room),
                onFinished: _onIntroFinished,
              ),

            // ③ 场地页：加载页演完才露出。
            //
            // 3D 实例由本页**自己创建**（见 DuelFieldPage3D 的
            // `_ensureGame`）：页面之间不共享任何实例，也就不存在
            // 「同一 Game 被两个 GameWidget 同时持有」的约束（flame 的
            // `_gameRenderBox` 是单值，同时持有会互相覆盖）。代价是切页
            // 这次要真建场景，这段开销由 ② 的入场演出遮住。
            if (_introDone)
              DuelFieldPage3D(players: room.players)
            else
              const SizedBox.shrink(),

            // ④ 结束页：可见性由它自己按 duelResult 判断——房间页只负责
            // 「该切过来了」，去重（换备阶段点过「进入换备阶段」后不再
            // 展示同一局结果）留在页面内部，避免两处各写一遍。
            const DuelEndPage(),
          ],
        ),
      ),
    );
  }
}
