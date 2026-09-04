import 'package:flutter/material.dart';

class TpSelect extends StatelessWidget {
  final void Function(bool) onSendTp;
  final bool enabled;

  const TpSelect({super.key, required this.onSendTp, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      // 标题由宿主面板（TurnSelectPanel）提供，这里只保留先攻/后攻按钮。
      // Column/Row 均包容内容（min）：宿主面板居中展示，不撑满屏幕。
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          FilledButton(
            key: const ValueKey('tp-select-first'),
            onPressed: enabled ? () => onSendTp(true) : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              minimumSize: const Size(64, 44),
            ),
            child: const Text('先攻'),
          ),
          FilledButton(
            key: const ValueKey('tp-select-second'),
            onPressed: enabled ? () => onSendTp(false) : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              minimumSize: const Size(64, 44),
            ),
            child: const Text('后攻'),
          ),
        ],
      ),
    );
  }
}
