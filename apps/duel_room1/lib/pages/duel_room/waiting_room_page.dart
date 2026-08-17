import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
// hide ConnectionState：与 Flutter 的 FutureBuilder ConnectionState 同名冲突。
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ygo_data/lf_table.dart';

import '../../widgets/waiting_room/chat_panel.dart';
import '../../widgets/waiting_room/control_bar.dart';
import '../../widgets/waiting_room/player_panel.dart';
import '../../widgets/waiting_room/room_info_panel.dart';

/// 等待室页（Riverpod 版）：保留 room1 原有视觉结构
/// （PlayerPanel + RoomInfoPanel/ChatPanel + ControlBar），
/// 数据源从旧 Store 换成 biz/duel 的 duelRoomProvider/duelChatProvider。
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
    final chat = ref.watch(duelChatProvider);
    final chatCtl = ref.read(duelChatProvider.notifier);
    final dataService = ref.watch(dataServiceProvider);
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
                child: PlayerPanel(
                  mySlot: mySlotVal,
                  players: room.players,
                  showHandResults: showHandResults,
                  isSelectingHand: stage is RoomSelectingHand,
                  isSelectingTurn: stage is RoomSelectingTurn,
                  myHandResult: room.myHandResult,
                  opponentHandResult: room.opponentHandResult,
                  isHost: room.isHost,
                  onKick: roomCtl.kickPlayer,
                  deckSelectionEnabled: !room.isSelfReady,
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
                  handSelectEnabled: !room.autoHandEnabled,
                  onSendHand: roomCtl.sendHand,
                  turnSelectEnabled: !room.autoTurnOrderEnabled,
                  onSendTp: roomCtl.sendTp,
                  observerCount: room.observerCount,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
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
                    Expanded(
                      child: ChatPanel(
                        messages: chat.messages,
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
          toggleReady: (context) => _onToggleReady(context, ref),
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
