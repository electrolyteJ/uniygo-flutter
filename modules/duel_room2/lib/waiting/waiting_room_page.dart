import 'dart:async';

import 'package:biz/service_providers.dart';
// hide ConnectionState：与 Flutter 的 FutureBuilder ConnectionState 同名冲突。
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resource_data/lf_table.dart';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'widgets/chat_panel.dart';
import 'widgets/control_bar.dart';
import 'widgets/deck_selector.dart';
import 'widgets/playerslot.dart';
import 'widgets/room_info_panel.dart';
import 'widgets/select_hand.dart';
import 'widgets/select_turn.dart';
import 'widgets/side_decking_panel.dart';

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

  Future<void> _onToggleReady(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(duelRoomProvider.notifier);
    final stage = ref.read(duelRoomProvider).stage;
    // 换备阶段「准备」即确认换备：避免误提交换备前的卡组。
    final error = stage is RoomSideDecking
        ? await notifier.confirmSiding()
        : await notifier.toggleReady();
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final roomCtl = ref.read(duelRoomProvider.notifier);
    final chatMessages = ref.watch(
      duelChatProvider.select((s) => s.messages),
    );
    final chatCtl = ref.read(duelChatProvider.notifier);
    final opts = room.roomOptions;
    final mySlotVal = room.selfType.slot;
    final stage = room.stage;
    final showHandResults = stage is RoomSelectingHand ||
        stage is RoomHandResult ||
        stage is RoomSelectingTurn;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  alignment: Alignment.topCenter,
                  color: Colors.blueGrey.shade800,
                  padding: const EdgeInsets.all(12),
                  // 短屏下 4 座位 + 卡组/猜拳面板会超出可用高度，改为可滚动。
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '玩家',
                          style: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 13,
                          ),
                        ),
                        ...room.players.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: PlayerSlot(
                              player: item,
                              placeholder: '玩家 ${item.pos + 1}',
                              handResult: item.pos == mySlotVal
                                  ? room.myHandResult
                                  : room.opponentHandResult,
                              showResult: showHandResults,
                              isHostSlot: _isHostSlot(
                                item,
                                mySlotVal,
                                room.isHost,
                              ),
                              isMe: item.pos == mySlotVal,
                              // 只有房主能踢人，且不能踢自己、不能踢观战位。
                              canKick: room.isHost &&
                                  item.pos != mySlotVal &&
                                  _isPlayerSlot(item),
                              onKick: () => roomCtl.kickPlayer(item.pos),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (stage is RoomSideDecking)
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
                          )
                        else
                          DeckSelector(
                            enabled: !room.isSelfReady,
                            decks: room.availableDecks,
                            selectedDeckName: room.selectedDeckName,
                            mySlot: mySlotVal,
                            onSelectDeck: (value) {
                              if (value != null) {
                                roomCtl.selectDeck(value);
                              }
                            },
                            onEditDeck: room.selectedDeckName == null
                                ? null
                                : () => _onEditDeck(context, ref),
                            invalidationResult: room.invalidationDeckResult,
                          ),
                        const SizedBox(height: 12),
                        if (stage is RoomSelectingHand)
                          HandSelect(
                            enabled: !room.autoHandEnabled,
                            onSendHand: roomCtl.sendHand,
                          ),
                        if (stage is RoomSelectingTurn)
                          TpSelect(
                            enabled: !room.autoTurnOrderEnabled,
                            onSendTp: roomCtl.sendTp,
                          ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.blueGrey.shade600, height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 16,
                              color: Colors.blueGrey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '观战: ${room.observerCount}人',
                              style: TextStyle(
                                color: Colors.blueGrey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    if (opts != null)
                      FutureBuilder<LfTable?>(
                        // future 已按 hash 在 notifier 内记忆化，
                        // build 重建不会重跑请求。
                        future: roomCtl.getLfTable(opts.lfTableHash),
                        builder: (context, snapshot) {
                          return RoomInfoPanel(
                            opts: opts,
                            lfTable: snapshot.data,
                            // 禁限表加载失败（如未 preload）时显式提示，
                            // 不再把错误吞掉后误显示「不限制」。
                            banlistLoading:
                                snapshot.connectionState !=
                                ConnectionState.done,
                            banlistError: snapshot.hasError,
                            cardLoader: ref.read(dataServiceProvider).getCard,
                          );
                        },
                      ),
                    Expanded(
                      child: ChatPanel(
                        messages: chatMessages,
                        onSend: chatCtl.sendChat,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ControlBar(
          isHost: room.isHost,
          selfType: room.selfType,
          isSelfReady: room.isSelfReady,
          isAllReady: room.isAllReady,
          autoHandEnabled: room.autoHandEnabled,
          autoTurnOrderEnabled: room.autoTurnOrderEnabled,
          autoDuelEnabled: room.autoDuelEnabled,
          toggleReady: (ctx) => _onToggleReady(ctx, ref),
          // setAuto* 的 Future 在此有意不 await（开关回调是同步签名）：
          // 错误已在 notifier/`_onToggleAutomation` 内处理，用 unawaited 表明意图。
          onToggleAutoHand: (v) => unawaited(
            _onToggleAutomation(ref, v, roomCtl.setAutoHandEnabled),
          ),
          onToggleAutoTurnOrder: (v) => unawaited(
            _onToggleAutomation(ref, v, roomCtl.setAutoTurnOrderEnabled),
          ),
          onToggleAutoDuel: (v) => unawaited(
            _onToggleAutomation(ref, v, roomCtl.setAutoDuelEnabled),
          ),
          onStartDuel: roomCtl.startDuel,
          onBecomeDuelist: roomCtl.becomeDuelist,
          onBecomeObserver: roomCtl.becomeObserver,
        ),
      ],
    );
  }
}

/// 该座位是否为房主位。
///
/// 优先使用房间流填充的 [PlayerInfo.host]（目前 base_duel_service 尚未填充，
/// 恒为 false）；未填充时回退约定：自己是房主则房主位即自己的座位，
/// 否则房主固定在 pos==0。修复了观战/双打模式下给所有座位挂房主徽章的问题。
bool _isHostSlot(PlayerInfo item, int mySlot, bool isHost) {
  if (item.host) return true;
  return isHost ? item.pos == mySlot : item.pos == 0;
}

/// 决斗者座位（pos 0..3）；观战位（pos==7）不可被踢。
bool _isPlayerSlot(PlayerInfo item) =>
    item.pos != PlayerType.observer.slot;
