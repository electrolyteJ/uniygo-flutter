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
import 'package:duel_room3/tab.dart';
import 'package:duelink/duelink.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'util/duel_room_exit.dart';
import 'end/duel_end_page.dart';
import 'field/duel_field_page.dart';
import 'loading/duel_field_loading_page.dart';
import 'loading/models/duel_intro_audio.dart';
import 'loading/widgets/intro_phases.dart';
import 'lobby/lobby_page.dart';
import 'side_decking/side_decking_page.dart';
import 'hand/hand_page.dart';
import 'turn/turn_page.dart';

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

  /// 是否已从结算页点「进入换备阶段」切到换备页。
  bool _sideDeckingOpen = false;

  /// 入场演出的硬超时兜底（见 [_armIntroFallback] 里的说明）。
  Timer? _resumeFallbackTimer;

  /// 入场演出 / 对局开场的音乐编排。
  ///
  /// 由房间页持有而非加载页自建：音乐要跨到场地页去（入场曲 4.2 秒，
  /// 演出只有 2.7 秒），生命周期比加载页长（见 DuelIntroAudio 的注释）。
  DuelIntroAudio? _introAudio;

  /// 三页的 tab 控制器：索引完全由状态驱动，用户不可滑动。
  late final TabController _tabController = TabController(
    length: DuelRoomTab.values.length,
    vsync: this,
    // 状态驱动的阶段切换不需要滑动动画：直接跳页，避免入场/猜拳切换时
    // 两页短暂共存，也避免动画期间重复构建。
    animationDuration: Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _resumeFallbackTimer?.cancel();
    _introAudio?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 入场演出播完：标记完成，tab 切到场地页。
  ///
  /// 同时放开决斗消息消费：演出期间积压的召唤/发动等消息从这里开始
  /// 按节奏补上（见 `_connect` 里的 pauseMessageConsumption）。
  ///
  /// 幂等：重复调用（演出回调抖一下）不会重复 resume，但**不能**因为
  /// `_introDone` 已为真就跳过 resume——否则第二次进入对局（match 局间）
  /// 时，第一局设的 _introDone 会让新一局的暂停永远解不开。
  void _onIntroFinished() {
    if (!mounted) return;
    _resumeFallbackTimer?.cancel();
    _resumeFallbackTimer = null;
    // 先把闸门放开再做别的：上场的是场地页，画面上已经有怪兽了，
    // 此刻起音效才对得上。resume 幂等，match 局间重复触发只清标志。
    ref.read(duelMessageRouterProvider.notifier).resumeMessageConsumption();
    if (_introDone) return;
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
    // 入场演出还没开始放，先压住决斗消息：否则玩家会在加载页就听到
    // 对方召唤怪兽、发动卡片的音效（服务器在 MSG_START 后立刻推消息）。
    // 消息只入队不消费，演出结束由 _onIntroFinished 放开。
    //
    // ⚠️ 必须紧跟 start()：pause 放在任何 await 之后都会被那段空隙里
    // 到达的消息钻过去（泵空闲时首条同步直通，不会等下一拍）。
    ref.read(duelMessageRouterProvider.notifier).pauseMessageConsumption();

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
  }

  /// 入场演出的硬超时兜底：**加载页真正上场**后才起算。
  ///
  /// 计时锚点必须是「演出开始」，不能是「连上服务器」。随机对战里玩家
  /// 可能在大厅等十几秒（服务器一直在推 Tip 广告），从 `_connect` 起算的
  /// 8 秒 Timer 会在人还在大厅时就把消息闸门打开；随后 MSG_START /
  /// MSG_SUMMONING / MSG_CHAINING 走空闲泵同步直通，音效在加载页刚开播
  /// 时就响了 —— 这正是「加载页还没结束就听到召唤/发动」的根因。
  ///
  /// 只起算一次：stage 会在对局期间反复重发同类型实例，不能每次重置。
  void _armIntroFallback() {
    if (_resumeFallbackTimer != null) return;
    _resumeFallbackTimer = Timer(const Duration(seconds: 8), () {
      _resumeFallbackTimer = null;
      if (!mounted) return;
      final stage = ref.read(duelRoomProvider).stage;
      if (stage is! RoomInDuel || _introDone) return;
      // 回调链路断了（演出组件被重建 / 热重载 / 没 start）：把**画面一起**
      // 推进到场地页，再放开消息。只 resume 不切页，声音会留在加载页上响，
      // 比卡死好一点但仍然是音画错位。
      console.log('intro fallback: forcing field page after 8s');
      // 正常路径由加载页的 _finish() 淡出入场曲；兜底路径绕过了它，
      // 这里补一次（finish 幂等），避免入场 BGM 压在场地页上。
      _introAudio?.finish();
      _onIntroFinished();
    });
  }

  /// 取（或惰性建）入场音乐编排器。
  ///
  /// 懒建而不是在 initState 里挂：`ref.read` 必须等 providerScope 就绪，
  /// 而 initState 阶段读 service 是安全的，但音乐只在真正要进加载页时
  /// 才需要——房间在大厅停留很久（等人、换卡组）时不该有对局音乐。
  DuelIntroAudio _ensureIntroAudio() {
    return _introAudio ??= DuelIntroAudio(ref.read(ygoSoundServiceProvider));
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
    // 用 !isDuelist 而不是 == observer：unknown（刚进房还没收到
    // TYPE_CHANGE）也不该被当成决斗者显示「YOU / 你」。
    final isSpectator = !room.selfType.isDuelist;

    final myName = board.playerNameOf(board.myController);
    final oppName = board.playerNameOf(1 - board.myController);
    // isFirstTurn 由服务器随 MSG_START 下发；未到时按后攻兜底
    // （入场只是呈现，真实先后攻以场地 HUD 为准）。
    final iGoFirst = room.isFirstTurn ?? false;

    // 这两个字段是**两个决斗方**的名字（入场页会拿它们标「先攻 / 后攻」），
    // 不是「当前用户 / 他的对手」。观战者自己不是决斗方，所以名字缺失时
    // 不能兜底成「观战者」，否则会显示成「先攻：观战者」；也不能用「对手」，
    // 观战者没有对手。一律退回中性的引擎玩家编号。
    return DuelIntroSceneData(
      myName: myName.isNotEmpty ? myName : (isSpectator ? '玩家 1' : '你'),
      opponentName: oppName.isNotEmpty
          ? oppName
          : (isSpectator ? '玩家 2' : '对手'),
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
      // 加载页上场 = 入场演出开始，此刻才起算硬超时兜底（见 _armIntroFallback）。
      // 放在 stage 监听里而不是 _connect 里，计时锚点才是「演出」而非「连接」。
      if (next is RoomInDuel && !_introDone) _armIntroFallback();
      if (next is RoomSideDecking && prev is! RoomSideDecking) {
        _sideDeckingOpen = false;
      }
      if (next is! RoomSideDecking && _sideDeckingOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _sideDeckingOpen = false);
        });
      }
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
    // 每局结果首次出现时累计 match 比分（换备页 / 场地页 / 结算页共用）。
    //
    // 放在房间页而不是各处 UI：duelResult 是全局单例数据，如果三个页面
    // 各自「看到结果就 +1」，换备往返一次就会重复计数。这里以 result
    // 实例为幂等键（DuelRoomNotifier.recordMatchResult），同一局只记一次。
    ref.listen(duelFieldProvider.select((s) => s.duelResult), (prev, next) {
      if (next == null) return;
      // 观战者没有胜负立场（myController 恒为 1，didWin 只是座位对齐的
      // 副产品），不参与计分，避免观战把比分算歪。
      if (!ref.read(duelRoomProvider).selfType.isDuelist) return;
      final winPlayer = next['winPlayer'] as int?;
      final isDraw = winPlayer != null && winPlayer != 0 && winPlayer != 1;
      // recordMatchResult 内部按 result 实例幂等，重复触发不会多记。
      ref
          .read(duelRoomProvider.notifier)
          .recordMatchResult(
            didWin: next['didWin'] as bool? ?? false,
            isDraw: isDraw,
            result: next,
          );
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
    final stage = room.stage;
    final isInDuel = stage is RoomInDuel;
    // 结果非空即进入谢幕阶段（第 ④ 页）。换备阶段（RoomSideDecking）同样
    // 归这里：此时 stage 已不是 RoomInDuel，但玩家要看的是本局结果 +
    // 「进入换备阶段」按钮，交给结算页自己决定按钮文案。
    final hasResult = ref.watch(
      duelFieldProvider.select((s) => s.duelResult != null),
    );
    // 下一局已经进入开赛/猜拳/选攻/场地时，上一局的 duelResult 可能
    // 仍留在 field 状态里；不能把它当成「本局结束」，否则换备确认后
    // 会被 stale result 拉回结算页。
    final inNextDuel =
        stage is RoomStartDuel ||
        stage is RoomSelectingHand ||
        stage is RoomHandResult ||
        stage is RoomSelectingTurn ||
        isInDuel;
    final isEnded = hasResult && !inNextDuel;

    // 六页解耦：大厅 / 猜拳 / 选攻 / 加载 / 场地 / 结束 各自独立，
    // 页面之间**不共享任何实例**。
    //
    // 索引完全由状态驱动，禁止用户滑动（入场动画不能被滑回去）。
    // 结算优先：进入换备阶段后先展示本局结算，玩家点「进入换备阶段」
    // 才切到换备页；不能因为没有 result 就抢跳到换备。
    final sideDeckingVisible = stage is RoomSideDecking && _sideDeckingOpen;
    final roomIdArg = widget.args['roomId'] as String?;
    final roomNameArg = widget.args['roomName'] as String?;
    final isAiArg = widget.args['aiRoom'] == true;
    final serverHostArg = (widget.args['uri'] as Uri?)?.host;
    final serverPortArg = (widget.args['uri'] as Uri?)?.port;
    final tabIndex = sideDeckingVisible
        ? DuelRoomTab.sideDecking
        : stage is RoomSideDecking
        ? DuelRoomTab.end
        : isEnded
        ? DuelRoomTab.end
        : (stage is RoomSelectingHand || stage is RoomHandResult)
        ? DuelRoomTab.hand
        : stage is RoomSelectingTurn
        ? DuelRoomTab.turn
        : !isInDuel
        ? DuelRoomTab.lobby
        : (_introDone ? DuelRoomTab.field : DuelRoomTab.loading);

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

    // 兜底：闸门还压着、但加载页已经不在台上 → 放开消息消费。
    //
    // 正常路径是 _onIntroFinished 解闸。它万一没到达（演出组件被重建、
    // 热重载、或帧后回调被吞），消息会永久卡在泵里，表现为「进了场地页
    // 但对面完全不动」。
    //
    // 两条边界都不能破：
    // ① 加载页还在台上（`_introDone` 为 false）时绝不 resume —— 这是
    //    「加载页听到召唤/发动音效」的直接成因，曾经这里每一帧都把闸门
    //    打开一次，入场期间积压的消息立刻倒出来，音效早于画面。
    // ② 回调没到达导致 `_introDone` 永不为真的死局，不靠这里硬闯，而是
    //    由 [_armIntroFallback] 的 8 秒超时调 _onIntroFinished 把**画面和
    //    闸门一起**推进；只解闸不切页，声音仍会留在加载页上响。
    if (isInDuel) {
      final router = ref.read(duelMessageRouterProvider.notifier);
      if (router.isConsumptionGated() && _introDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          router.resumeMessageConsumption();
        });
      }
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
        // 六个阶段是平级的 tab 页，没有叠层：结算不再盖在场地之上，
        // 而是独立的第 ⑥ 页。
        body: TabBarView(
          controller: _tabController,
          // 禁止滑动：tab 只能由状态驱动切换。
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // ① 等待大厅
            LobbyPage3D(
              key: const PageStorageKey('duel-room3-waiting-lobby'),
              roomId: roomIdArg,
              roomName: roomNameArg,
              isAiRoom: isAiArg,
              serverHost: serverHostArg,
              serverPort: serverPortArg,
            ),

            // ② 猜拳（含出拳结果）
            const HandPage3D(key: PageStorageKey('duel-room3-waiting-hand')),

            // ③ 选择先后攻
            const TurnPage3D(key: PageStorageKey('duel-room3-waiting-turn')),

            // ④ 加载页：入场演出（Seamless Loading Screen）。
            //
            // 演完才切 ⑤；_introDone 为真后本页立刻换成
            // SizedBox.shrink()（无 Key → 换成一棵新子树，旧的连同动画
            // controller 一起销毁）。
            if (_introDone)
              const SizedBox.shrink()
            else
              DuelFieldLoadingPage(
                data: _buildIntroData(ref, room),
                bgm: _ensureIntroAudio(),
                onFinished: _onIntroFinished,
              ),

            // ⑤ 场地页：加载页演完才露出。
            //
            // 3D 实例由本页**自己创建**（见 DuelFieldPage3D 的
            // `_ensureGame`）：页面之间不共享任何实例，也就不存在
            // 「同一 Game 被两个 GameWidget 同时持有」的约束（flame 的
            // `_gameRenderBox` 是单值，同时持有会互相覆盖）。
            if (_introDone)
              DuelFieldPage3D(players: room.players)
            else
              const SizedBox.shrink(),

            // ⑥ 结束页：可见性由它自己按 duelResult 判断——房间页只负责
            // 「该切过来了」，去重（换备阶段点过「进入换备阶段」后不再
            // 展示同一局结果）留在页面内部，避免两处各写一遍。
            const SideDeckingPage3D(),

            DuelEndPage(
              onEnterSideDecking: () {
                if (mounted) setState(() => _sideDeckingOpen = true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
