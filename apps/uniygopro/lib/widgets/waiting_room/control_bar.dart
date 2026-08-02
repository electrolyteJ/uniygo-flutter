import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'package:provider/provider.dart';
import '../../stores/waiting_room_store.dart';
import '../shared/waiting_room.dart';
import 'hand_result_display.dart' show DisplayStyle;

export 'hand_result_display.dart' show DisplayStyle;

class ControlBar extends StatelessWidget {
  final int mySlot;
  final bool isPlayer;
  final bool isReady;
  final VoidCallback onToggleDisplay;
  final DisplayStyle displayStyle;

  const ControlBar({
    super.key,
    required this.mySlot,
    required this.isPlayer,
    required this.isReady,
    required this.onToggleDisplay,
    required this.displayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final waitingRoomStore = context.watch<WaitingRoomStore>();
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
                  onChanged: (value) =>
                      waitingRoomStore.setAutoHandEnabled(value),
                ),

                buildAutomationSwitch(
                  label: '自动随机先后手',
                  value: waitingRoomStore.autoTurnOrderEnabled,
                  enabled: !waitingRoomStore.isSelfReady,
                  onChanged: (value) =>
                      waitingRoomStore.setAutoTurnOrderEnabled(value),
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
                  onPressed: () => waitingRoomStore.toggleReady(context),
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
                  onPressed: () => waitingRoomStore.becomeObserver(),
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
                  onPressed: () => waitingRoomStore.becomeDuelist(),
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
                  onPressed: () => waitingRoomStore.startDuel(),
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
