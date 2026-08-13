import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

class PlayerSlot extends StatelessWidget {
  final PlayerInfo? player;
  final String placeholder;
  final int? handResult;
  final bool showResult;
  final bool isHostSlot;
  final bool isMe;
  final bool canKick;
  final VoidCallback onKick;

  const PlayerSlot({super.key,
    required this.player,
    required this.placeholder,
    this.handResult,
    required this.showResult,
    this.isHostSlot = false,
    this.isMe = false,
    this.canKick = false,
    required this.onKick,
  });

  String _getHandEmoji(int? result) {
    switch (result) {
      case 1: return '✌️';
      case 2: return '✊';
      case 3: return '🖐️';
      default: return '❓';
    }
  }

  String _getHandName(int? result) {
    switch (result) {
      case 1: return '剪刀';
      case 2: return '石头';
      case 3: return '布';
      default: return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: isMe
            ? Border.all(color: Colors.amber.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isMe ? Colors.amber.shade700 : Colors.teal.shade700,
                child: Text((player?.name ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          player == null ? placeholder : (player?.name ?? ''),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: isMe ? FontWeight.bold : FontWeight
                                .normal,
                          ),
                        ),
                        if (isHostSlot) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('房主', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    if (player != null)
                      Text(
                        player!.ready ? '已准备' : '未准备',
                        style: TextStyle(
                          color: player!.ready ? Colors.greenAccent : Colors.blueGrey.shade400,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (player != null)
                Icon(player!.ready ? Icons.check_circle : Icons.cancel,
                  color: player!.ready ? Colors.greenAccent : Colors.blueGrey.shade500,
                  size: 20,
                ),
              if (canKick)
                IconButton(
                  icon: Icon(Icons.person_remove, color: Colors.redAccent.withValues(alpha: 0.7), size: 20),
                  onPressed: onKick,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (showResult && handResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.blueGrey.shade600, width: 1)),
              ),
              child: Row(
                children: [
                  Text(_getHandEmoji(handResult), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    _getHandName(handResult),
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

