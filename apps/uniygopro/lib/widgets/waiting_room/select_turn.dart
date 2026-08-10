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
      child: Column(
        children: [
          Text(
            '选择先后',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                key: const ValueKey('tp-select-first'),
                onPressed: enabled ? () => onSendTp(true) : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('先攻'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                key: const ValueKey('tp-select-second'),
                onPressed: enabled ? () => onSendTp(false) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: const Text('后攻'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
