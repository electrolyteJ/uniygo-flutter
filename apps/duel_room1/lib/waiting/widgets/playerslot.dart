import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

/// 玩家槽位：头像/名称/房主标记/准备状态/踢人。
/// 猜拳结果不在这里展示（由 HandSelectPanel 的结果区承担）。
class PlayerSlot extends StatelessWidget {
  final PlayerInfo? player;
  final String placeholder;
  final bool isHostSlot;
  final bool isMe;
  final bool canKick;
  final VoidCallback onKick;

  const PlayerSlot({
    super.key,
    required this.player,
    required this.placeholder,
    this.isHostSlot = false,
    this.isMe = false,
    this.canKick = false,
    required this.onKick,
  });

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
                backgroundColor: isMe
                    ? Colors.amber.shade700
                    : Colors.teal.shade700,
                child: Text(
                  (player?.name ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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
                            fontWeight: isMe
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (isHostSlot) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '房主',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (player != null)
                      Text(
                        player!.ready ? '已准备' : '未准备',
                        style: TextStyle(
                          color: player!.ready
                              ? Colors.greenAccent
                              : Colors.blueGrey.shade400,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (player != null)
                Icon(
                  player!.ready ? Icons.check_circle : Icons.cancel,
                  color: player!.ready
                      ? Colors.greenAccent
                      : Colors.blueGrey.shade500,
                  size: 20,
                ),
              if (canKick)
                IconButton(
                  icon: Icon(
                    Icons.person_remove,
                    color: Colors.redAccent.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: onKick,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
