
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

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
      child: Column(
        children: [
          Text('猜拳', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _handButton(HandType.scissors, '✌️', '剪刀', onSendHand),
              const SizedBox(width: 12),
              _handButton(HandType.rock, '✊', '石头', onSendHand),
              const SizedBox(width: 12),
              _handButton(HandType.paper, '🖐️', '布', onSendHand),
            ],
          ),
        ],
      ),
    );
  }

  Widget _handButton(HandType hand, String emoji, String label, void Function(HandType) onTap) {
    return GestureDetector(
      key: ValueKey('hand-select-${hand.name}'),
      onTap: enabled ? () => onTap(hand) : null,
      child: Column(
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12)),
        ],
      ),
    );
  }
}
