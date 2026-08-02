import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import '../../stores/waiting_room_store.dart';
import '../shared/waiting_room.dart';
import 'hand_result_display.dart' show DisplayStyle;

export 'hand_result_display.dart' show DisplayStyle;

class ControlBar extends StatelessWidget {
  final WaitingRoomStore waitingRoomStore;
  final int mySlot;
  final bool isPlayer;
  final bool isReady;
  final VoidCallback onToggleReady;
  final VoidCallback onSwitchToObserver;
  final VoidCallback onSwitchToDuelist;
  final VoidCallback onStart;
  final VoidCallback onToggleDisplay;
  final DisplayStyle displayStyle;
  final ValueChanged<bool> onToggleAutoHand;
  final ValueChanged<bool> onToggleAutoTurnOrder;

  const ControlBar({
    super.key,
    required this.waitingRoomStore,
    required this.mySlot,
    required this.isPlayer,
    required this.isReady,
    required this.onToggleReady,
    required this.onSwitchToObserver,
    required this.onSwitchToDuelist,
    required this.onStart,
    required this.onToggleDisplay,
    required this.displayStyle,
    required this.onToggleAutoHand,
    required this.onToggleAutoTurnOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        border: Border(top: BorderSide(color: Colors.blueGrey.shade700)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                buildAutomationSwitch(
                  label: '自动猜拳',
                  value: waitingRoomStore.autoHandEnabled,
                  enabled: !waitingRoomStore.isSelfReady,
                  onChanged: onToggleAutoHand,
                ),
                buildAutomationSwitch(
                  label: '自动随机先后手',
                  value: waitingRoomStore.autoTurnOrderEnabled,
                  enabled: !waitingRoomStore.isSelfReady,
                  onChanged: onToggleAutoTurnOrder,
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                displayStyle == DisplayStyle.card
                    ? Icons.view_list
                    : Icons.view_module,
                size: 20,
              ),
              color: Colors.blueGrey.shade400,
              onPressed: onToggleDisplay,
              tooltip: displayStyle == DisplayStyle.card
                  ? '切换到状态栏显示'
                  : '切换到卡片显示',
            ),
            const SizedBox(width: 8),
            if (isPlayer)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggleReady,
                  icon: Icon(
                    isReady ? Icons.cancel : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(isReady ? '取消准备' : '准备'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isReady
                        ? Colors.blueGrey.shade600
                        : Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (isPlayer) const SizedBox(width: 8),
            if (isPlayer)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSwitchToObserver,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('观战'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade300,
                    side: BorderSide(color: Colors.blueGrey.shade600),
                  ),
                ),
              ),
            if (!isPlayer && waitingRoomStore.selfType == SelfType.observer)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSwitchToDuelist,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('加入对战'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.shade700),
                  ),
                ),
              ),
            if (!isPlayer && waitingRoomStore.selfType == SelfType.observer)
              const SizedBox(width: 8),
            if (waitingRoomStore.isHost)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始决斗'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
