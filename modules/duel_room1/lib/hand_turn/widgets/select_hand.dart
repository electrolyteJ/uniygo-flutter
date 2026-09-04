import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'stage_selection_panel_host.dart';

class HandSelect extends StatelessWidget {
  final void Function(HandType) onSendHand;
  final bool enabled;

  const HandSelect({super.key, required this.onSendHand, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      // 标题由宿主面板（HandSelectPanel）提供，这里只保留出拳按钮。
      // Column/Row 均包容内容（min）：宿主面板居中展示，不撑满屏幕。
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _handButton(HandType.scissors, '✌️', '剪刀', onSendHand),
          _handButton(HandType.rock, '✊', '石头', onSendHand),
          _handButton(HandType.paper, '🖐️', '布', onSendHand),
        ],
      ),
    );
  }

  Widget _handButton(
    HandType hand,
    String emoji,
    String label,
    void Function(HandType) onTap,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InteractionIsolation(
          active: enabled,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('hand-select-${hand.name}'),
              onTap: enabled ? () => onTap(hand) : null,
              canRequestFocus: enabled,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.blueGrey.shade300,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
