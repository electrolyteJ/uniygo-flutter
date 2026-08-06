import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import '../shared/waiting_room.dart';
class ControlBar extends StatelessWidget {
  final bool isHost;
  final PlayerType selfType;
  final bool isSelfReady;
  final bool isAllReady;
  final bool autoHandEnabled;
  final bool autoTurnOrderEnabled;
  final bool autoDuelEnabled;
  final ValueChanged<BuildContext> toggleReady;
  final ValueChanged<bool> onToggleAutoHand;
  final ValueChanged<bool> onToggleAutoTurnOrder;
  final ValueChanged<bool> onToggleAutoDuel;
  final VoidCallback onStartDuel;
  final VoidCallback onBecomeDuelist;
  final VoidCallback onBecomeObserver;


  const ControlBar({
    super.key,
    required this.isHost,
    required this.selfType,
    required this.isSelfReady,
    required this.isAllReady,
    required this.autoHandEnabled,
    required this.autoTurnOrderEnabled,
    required this.autoDuelEnabled,
    required this.toggleReady,
    required this.onToggleAutoHand,
    required this.onToggleAutoTurnOrder,
    required this.onToggleAutoDuel,
    required this.onStartDuel,
    required this.onBecomeDuelist,
    required this.onBecomeObserver,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayer =
        selfType == PlayerType.player1 || selfType == PlayerType.player2;
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
                if (isHost)
                  buildAutomationSwitch(
                    label: '自动加入决斗',
                    value: autoDuelEnabled,
                    enabled: !isSelfReady,
                    onChanged: (value) => onToggleAutoDuel(value),
                  ),
                buildAutomationSwitch(
                  label: '自动猜拳',
                  value: autoHandEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) => onToggleAutoHand(value),
                ),

                buildAutomationSwitch(
                  label: '自动随机先后手',
                  value: autoTurnOrderEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) =>
                      onToggleAutoTurnOrder(value),
                ),
              ],
            ),
            const SizedBox(width: 8),
            if (isPlayer)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => toggleReady(context),
                  icon: Icon(
                    isSelfReady ? Icons.cancel : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(isSelfReady ? '取消准备' : (autoDuelEnabled ? '准备&决斗' : '准备')),
                  style: FilledButton.styleFrom(
                    backgroundColor: isSelfReady
                        ? Colors.blueGrey.shade600
                        : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueGrey.shade700,
                    disabledForegroundColor: Colors.blueGrey.shade500,
                  ),
                ),
              ),
            if (isPlayer) const SizedBox(width: 8),
            if (isPlayer)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBecomeObserver,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('观战'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade300,
                    side: BorderSide(color: Colors.blueGrey.shade600),
                  ),
                ),
              ),
            if (selfType == PlayerType.observer)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBecomeDuelist,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('加入对战'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.shade700),
                  ),
                ),
              ),
            if (selfType == PlayerType.observer) const SizedBox(width: 8),
            if (isHost && !autoDuelEnabled)
              Expanded(
                child: FilledButton.icon(
                  onPressed: isAllReady ? onStartDuel : null,
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
