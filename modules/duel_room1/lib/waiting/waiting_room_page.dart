import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/widgets/automation_switch.dart';
import 'package:duel_room1/waiting/widgets/room_button.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resource_data/lf_table.dart';

import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/waiting/widgets/overlay_panel.dart';
import 'package:duel_room1/waiting/widgets/player_panel.dart';
import 'package:duel_room1/waiting/widgets/room_info_panel.dart';
import 'package:duel_room1/waiting/widgets/side_decking_panel.dart';

/// 等待室弹窗（Riverpod 版）：只占屏幕中央的一块半透明圆角面板，
/// 弹窗之外完全透明、不拦截指针，背后的决斗场地直接可见可交互
/// （对齐 godot RoomOverlay 根节点 MOUSE_FILTER_IGNORE 的穿透行为）。
///
/// 面板内容：PlayerPanel + RoomInfoPanel + ControlBar。
/// 日志/聊天与猜拳/选先攻不在本页：它们由 DuelRoomPage 直接挂载
/// （日志/聊天合并为 DuelLogDrawer 抽屉，AppBar actions 的按钮开合；
/// 猜拳/选先攻为中央阶段面板）。
class WaitingRoomPage extends ConsumerStatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  ConsumerState<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends ConsumerState<WaitingRoomPage> {
  /// 卡组列表首载是否已结束（区分「加载中」与「真空」）。
  bool _deckListLoadFinished = false;

  @override
  void initState() {
    super.initState();
    // biz 侧没有暴露卡组列表加载状态：notifier 构建时自发 loadDecks，
    // 这里复跑同一公开入口，以其返回作为「首载结束」信号
    // （幂等重读；成功/失败都会返回，失败另有 errorMessage 渠道提示）。
    unawaited(() async {
      try {
        await ref.read(duelRoomProvider.notifier).loadDecks();
      } catch (_) {
        // loadDecks 内部已兜底（失败走 errorMessage），这里仅防御。
      }
      if (mounted) {
        setState(() => _deckListLoadFinished = true);
      }
    }());
  }

  /// 自动化开关切换：先等 notifier 裁决，被接受才播放提示音。
  ///
  /// 已准备状态下 notifier 会拒绝变更（返回 false），旧实现先响音后
  /// 调用 action，被拒绝的切换也会发出声音；同时持久化失败已在
  /// notifier 内走 errorMessage 渠道，这里兜底 catch，避免未处理异常。
  Future<void> _onToggleAutomation(
    WidgetRef ref,
    bool value,
    Future<bool> Function(bool) action,
  ) async {
    // await（SharedPreferences 往返）之前先捕获声音服务：
    // 等待期间房间页可能销毁，事后再 ref.read 会抛异常。
    final sound = ref.read(ygoSoundServiceProvider);
    bool accepted;
    try {
      accepted = await action(value);
    } catch (_) {
      accepted = false;
    }
    if (!accepted) return;
    if (value) {
      sound.playToggleOn();
    } else {
      sound.playToggleOff();
    }
  }

  /// 编辑当前所选卡组：打开卡组编辑器，保存后刷新卡组校验。
  ///
  /// 路由参数用通用 Map 传递（不依赖卡组编辑器的类型）：
  /// `initialDeckName` / `noCheckDeck` / `lfTableHash` /
  /// `lockDeckSelection` / `lockDeckName`；返回值同为 Map，
  /// 含 `saved`（bool）。
  Future<void> _onEditDeck(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(duelRoomProvider.notifier);
    final roomState = ref.read(duelRoomProvider);
    final opts = roomState.roomOptions;
    final result = await context.push<Map<String, Object?>>(
      '/deck-editor',
      extra: <String, Object?>{
        'initialDeckName': roomState.selectedDeckName,
        if (opts != null) 'noCheckDeck': opts.noCheckDeck,
        if (opts != null) 'lfTableHash': opts.lfTableHash,
        'lockDeckSelection': true,
        'lockDeckName': true,
      },
    );
    // 跨页 await 之后 context 可能已卸载。
    if (!context.mounted) return;
    if (result?['saved'] == true) {
      await controller.refreshSelectedDeckValidation();
    }
  }

  /// 换备确认：提交换备后的卡组并 ready，失败原因走 SnackBar。
  Future<void> _onConfirmSiding(BuildContext context, WidgetRef ref) async {
    // 兜住一切异常：确认是 match 局间唯一推进通道，未处理异常会让
    // 换备永远卡住（第二局不开局）且无任何提示。
    String? error;
    try {
      error = await ref.read(duelRoomProvider.notifier).confirmSiding();
    } catch (e) {
      error = '换备提交失败: $e';
    }
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _onToggleReady(BuildContext context, WidgetRef ref) async {
    final error = await ref.read(duelRoomProvider.notifier).toggleReady();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(duelRoomProvider);
    final roomCtl = ref.read(duelRoomProvider.notifier);
    final dataService = ref.watch(dataServiceProvider);
    final opts = room.roomOptions;
    final mySlotVal = room.selfType.slot;
    final stage = room.stage;
    final isSideDecking = stage is RoomSideDecking;
    final spec = DuelRoomLayout.of(context);
    return _WaitingRoomPanelFrame(
      child: Padding(
        padding: EdgeInsets.all(spec.pagePadding),
        child: _WaitingRoomPanelLayout(
          compact: spec.isCompact,
          content: _buildRoomContent(
            room: room,
            roomCtl: roomCtl,
            dataService: dataService,
            opts: opts,
            mySlotVal: mySlotVal,
            isSideDecking: isSideDecking,
          ),
          controlBar: isSideDecking
              ? null
              : KeyedSubtree(
                  key: const ValueKey('waiting-room-controls'),
                  child: _buildControlBar(
                    isHost: room.isHost,
                    selfType: room.selfType,
                    isSelfReady: room.isSelfReady,
                    isAllReady: room.isAllReady,
                    autoHandEnabled: room.autoHandEnabled,
                    autoTurnOrderEnabled: room.autoTurnOrderEnabled,
                    autoDuelEnabled: room.autoDuelEnabled,
                    toggleReady: (context) => _onToggleReady(context, ref),
                    onToggleAutoHand: (v) =>
                        unawaited(_onToggleAutomation(ref, v, roomCtl.setAutoHandEnabled)),
                    onToggleAutoTurnOrder: (v) => unawaited(
                      _onToggleAutomation(ref, v, roomCtl.setAutoTurnOrderEnabled),
                    ),
                    onToggleAutoDuel: (v) =>
                        unawaited(_onToggleAutomation(ref, v, roomCtl.setAutoDuelEnabled)),
                    onStartDuel: roomCtl.startDuel,
                    onBecomeDuelist: roomCtl.becomeDuelist,
                    onBecomeObserver: roomCtl.becomeObserver,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRoomContent({
    required DuelRoomState room,
    required DuelRoomNotifier roomCtl,
    required dynamic dataService,
    required RoomOptions? opts,
    required int mySlotVal,
    required bool isSideDecking,
  }) {
    return Column(
      key: const ValueKey('waiting-room-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerPanel(
          mySlot: mySlotVal,
          selfType: room.selfType,
          players: room.players,
          isHost: room.isHost,
          onKick: roomCtl.kickPlayer,
          // 换备阶段隐藏卡组选择（换备走专用面板）。
          deckSelectionEnabled: !room.isSelfReady && !isSideDecking,
          decks: room.availableDecks,
          deckListLoading: !_deckListLoadFinished,
          selectedDeckName: room.selectedDeckName,
          onSelectDeck: (value) {
            if (value == null) return;
            // selectDeck 的失败（卡组加载失败/不存在）
            // 不回写 invalidationDeckResult，不经
            // errorMessage 渠道就会静默丢弃。
            unawaited(() async {
              final r = await roomCtl.selectDeck(value);
              final error = r.error;
              if (error != null) {
                roomCtl.setErrorText(error);
              }
            }());
          },
          onEditDeck: room.selectedDeckName == null
              ? null
              : () => _onEditDeck(context, ref),
          deckInvalidationResult: room.invalidationDeckResult,
          observerCount: room.observerCount,
        ),
        // match 模式局间换备面板（提交后自动 ready）。
        if (isSideDecking)
          SideDeckingPanel(
            // tag 模式座位 2/3（player3/player4）
            // 同样是决斗者，需要参与换备。
            isDuelist: room.selfType.isDuelist,
            sidingMain: room.sidingMain,
            sidingExtra: room.sidingExtra,
            sidingSide: room.sidingSide,
            sidingInitFailed: room.sidingInitFailed,
            onRetryInit: roomCtl.retrySidingInit,
            baselineMainCount: room.sidingBaseline?.main.length ?? 0,
            baselineExtraCount: room.sidingBaseline?.extra.length ?? 0,
            baselineSideCount: room.sidingBaseline?.side.length ?? 0,
            onMoveCard: roomCtl.moveSidingCard,
            onReset: roomCtl.resetSiding,
            onConfirm: () => _onConfirmSiding(context, ref),
          ),
        if (opts != null)
          FutureBuilder<LfTable?>(
            future: roomCtl.getLfTable(opts.lfTableHash),
            builder: (context, snapshot) {
              // 三态区分：加载中 / 失败 / 数据
              // （数据为 null 才是「不限制」），避免
              // 加载失败被渲染成误导性的「不限制」。
              return RoomInfoPanel(
                opts: opts,
                lfTable: snapshot.data,
                lfTableLoading:
                    snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasError,
                lfTableFailed: snapshot.hasError,
                cardLoader: dataService.getCard,
              );
            },
          ),
      ],
    );
  }
  Widget _buildControlBar({
    required bool isHost,
    required PlayerType selfType,
    required bool isSelfReady,
    required bool isAllReady,
    required bool autoHandEnabled,
    required bool autoTurnOrderEnabled,
    required bool autoDuelEnabled,
    required ValueChanged<BuildContext> toggleReady,
    required ValueChanged<bool> onToggleAutoHand,
    required ValueChanged<bool> onToggleAutoTurnOrder,
    required ValueChanged<bool> onToggleAutoDuel,
    required VoidCallback onStartDuel,
    required VoidCallback onBecomeDuelist,
    required VoidCallback onBecomeObserver,
  }) {
    /// godot RoomOverlay 按钮的强调色。
    const _accentReady = Color(0xFF1A8C4C); // 准备：绿
    const _accentStart = Color(0xFF996600); // 开始决斗：橙
    // tag 模式 2/3 号位（player3/player4）同样是决斗者。
    final isPlayer = selfType.isDuelist;
    // 不设底色：等待室已改为半透明弹窗，面板背景由弹窗容器提供。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.blueGrey.shade700)),
      ),
      child: SafeArea(
        top: false,
        // 两行布局：第一行自动化开关，第二行操作按钮。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                if (isHost)
                  AutomationSwitch(
                    label: '自动加入决斗',
                    value: autoDuelEnabled,
                    enabled: !isSelfReady,
                    onChanged: (value) => onToggleAutoDuel(value),
                  ),
                AutomationSwitch(
                  label: '自动猜拳',
                  value: autoHandEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) => onToggleAutoHand(value),
                ),
                AutomationSwitch(
                  label: '自动随机先后手',
                  value: autoTurnOrderEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) => onToggleAutoTurnOrder(value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (isPlayer)
                    RoomButton(
                      key: const ValueKey('waiting-room-ready'),
                      maxWidth: constraints.maxWidth,
                      // 自动开局只在房主端生效（notifier 内按 isHost
                      // 门控），非房主即使开过偏好也不会自动开始，
                      // 标签同步隐藏避免误导。
                      label: isSelfReady
                          ? '取消准备'
                          : (isHost && autoDuelEnabled ? '准备&决斗' : '准备'),
                      icon: isSelfReady ? Icons.cancel : Icons.check_circle,
                      accent: _accentReady,
                      active: isSelfReady,
                      onPressed: () => toggleReady(context),
                    ),
                  if (isPlayer)
                    RoomButton(
                      maxWidth: constraints.maxWidth,
                      label: '观战',
                      icon: Icons.visibility,
                      accent: const Color(0xFF8CA6C4),
                      onPressed: onBecomeObserver,
                    ),
                  if (selfType == PlayerType.observer)
                    RoomButton(
                      maxWidth: constraints.maxWidth,
                      label: '加入对战',
                      icon: Icons.person_add,
                      accent: Colors.amber,
                      onPressed: onBecomeDuelist,
                    ),
                  if (isHost && !autoDuelEnabled)
                    RoomButton(
                      maxWidth: constraints.maxWidth,
                      label: '开始决斗',
                      icon: Icons.play_arrow,
                      accent: _accentStart,
                      onPressed: isAllReady ? onStartDuel : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingRoomPanelLayout extends StatelessWidget {
  const _WaitingRoomPanelLayout({
    required this.compact,
    required this.content,
    this.controlBar,
  });

  final bool compact;
  final Widget content;
  final Widget? controlBar;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [content, ?controlBar],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: SingleChildScrollView(child: content)),
        ?controlBar,
      ],
    );
  }
}

class _WaitingRoomPanelFrame extends StatelessWidget {
  const _WaitingRoomPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    final double width = spec.isCompact
        ? spec.safeRect.width - spec.pagePadding * 2
        : spec.safeRect.width.clamp(0.0, 560.0);
    final height = spec.safeRect.height - spec.pagePadding * 2;
    final legacyMaxWidth = (spec.viewport.width - 32).clamp(0.0, 560.0);
    final legacyMaxHeight = (spec.viewport.height - 32).clamp(
      0.0,
      double.infinity,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spec.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: legacyMaxWidth,
              maxHeight: legacyMaxHeight,
            ),
            child: OverflowBox(
              maxWidth: width.clamp(0.0, double.infinity),
              maxHeight: height.clamp(0.0, double.infinity),
              child: SizedBox(
                width: width.clamp(0.0, double.infinity),
                height: height.clamp(0.0, double.infinity),
                child: OverlayPanel(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
