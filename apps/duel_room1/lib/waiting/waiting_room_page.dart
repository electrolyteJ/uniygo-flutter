import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ygo_data/lf_table.dart';

import 'package:duel_room1/waiting/widgets/control_bar.dart';
import 'package:duel_room1/waiting/widgets/overlay_panel.dart';
import 'package:duel_room1/waiting/widgets/player_panel.dart';
import 'package:duel_room1/waiting/widgets/room_info_panel.dart';
import 'package:duel_room1/waiting/widgets/side_decking_panel.dart';

/// 等待室弹窗（Riverpod 版）：只占屏幕中央的一块半透明圆角面板，
/// 弹窗之外完全透明、不拦截指针，背后的决斗场地直接可见可交互
/// （对齐 godot RoomOverlay 根节点 MOUSE_FILTER_IGNORE 的穿透行为）。
///
/// 面板内容：PlayerPanel + RoomInfoPanel + ControlBar。
/// 聊天室与猜拳/选先攻不在本页：它们由 DuelRoomPage 直接挂载
/// （聊天室停靠右侧，与 DuelLogDrawer 同位；猜拳/选先攻为中央阶段面板）。
class WaitingRoomPage extends ConsumerWidget {
  const WaitingRoomPage({super.key});

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
    bool accepted;
    try {
      accepted = await action(value);
    } catch (_) {
      accepted = false;
    }
    if (!accepted) return;
    final sound = ref.read(ygoSoundServiceProvider);
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
    final error = await ref.read(duelRoomProvider.notifier).confirmSiding();
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
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final roomCtl = ref.read(duelRoomProvider.notifier);
    final dataService = ref.watch(dataServiceProvider);
    final opts = room.roomOptions;
    final mySlotVal = room.selfType.slot;
    final stage = room.stage;
    final isSideDecking = stage is RoomSideDecking;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 屏幕居中，不为右侧聊天浮窗让位。
        final dialogMaxWidth = (constraints.maxWidth - 32).clamp(280.0, 640.0);
        // 弹窗之外不绘制任何东西（透明、不挡指针），场地直接透出。
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              // 极小窗口兜底：约束不允许负值。
              maxHeight: (constraints.maxHeight - 24).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: OverlayPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PlayerPanel(
                            mySlot: mySlotVal,
                            players: room.players,
                            isHost: room.isHost,
                            onKick: roomCtl.kickPlayer,
                            // 换备阶段隐藏卡组选择（换备走专用面板）。
                            deckSelectionEnabled:
                                !room.isSelfReady && !isSideDecking,
                            decks: room.availableDecks,
                            selectedDeckName: room.selectedDeckName,
                            onSelectDeck: (value) {
                              if (value != null) {
                                unawaited(roomCtl.selectDeck(value));
                              }
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
                              isDuelist: mySlotVal >= 0 && mySlotVal <= 1,
                              sidingMain: room.sidingMain,
                              sidingExtra: room.sidingExtra,
                              sidingSide: room.sidingSide,
                              baselineMainCount:
                                  room.sidingBaseline?.main.length ?? 0,
                              baselineExtraCount:
                                  room.sidingBaseline?.extra.length ?? 0,
                              baselineSideCount:
                                  room.sidingBaseline?.side.length ?? 0,
                              onMoveCard: roomCtl.moveSidingCard,
                              onReset: roomCtl.resetSiding,
                              onConfirm: () => _onConfirmSiding(context, ref),
                            ),
                          if (opts != null)
                            FutureBuilder<LfTable?>(
                              future: roomCtl.getLfTable(opts.lfTableHash),
                              builder: (context, snapshot) {
                                return RoomInfoPanel(
                                  opts: opts,
                                  lfTable: snapshot.data,
                                  cardLoader: dataService.getCard,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 换备阶段隐藏底部控制条：其「准备」按钮走 toggleReady，
                  // 会重新提交原始卡组（而非换备后的构成），与换备面板的
                  // 「确认换备」冲突、导致按原卡组开局或提交混乱；换备提交
                  // 统一走 SideDeckingPanel 的 confirmSiding。
                  if (!isSideDecking)
                  ControlBar(
                    isHost: room.isHost,
                    selfType: room.selfType,
                    isSelfReady: room.isSelfReady,
                    isAllReady: room.isAllReady,
                    autoHandEnabled: room.autoHandEnabled,
                    autoTurnOrderEnabled: room.autoTurnOrderEnabled,
                    autoDuelEnabled: room.autoDuelEnabled,
                    toggleReady: (context) => _onToggleReady(context, ref),
                    onToggleAutoHand: (v) => unawaited(
                      _onToggleAutomation(ref, v, roomCtl.setAutoHandEnabled),
                    ),
                    onToggleAutoTurnOrder: (v) => unawaited(
                      _onToggleAutomation(
                        ref,
                        v,
                        roomCtl.setAutoTurnOrderEnabled,
                      ),
                    ),
                    onToggleAutoDuel: (v) => unawaited(
                      _onToggleAutomation(ref, v, roomCtl.setAutoDuelEnabled),
                    ),
                    onStartDuel: roomCtl.startDuel,
                    onBecomeDuelist: roomCtl.becomeDuelist,
                    onBecomeObserver: roomCtl.becomeObserver,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
