import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';

enum DisplayStyle { card, statusBar }

class HandResultDisplay extends StatelessWidget {
  final int? myHandResult;
  final int? opponentHandResult;
  final bool? isFirstTurn;
  final RoomStage stage;
  final DisplayStyle style;
  final String myName;
  final String opponentName;

  const HandResultDisplay({
    super.key,
    this.myHandResult,
    this.opponentHandResult,
    this.isFirstTurn,
    required this.stage,
    required this.style,
    required this.myName,
    required this.opponentName,
  });

  String _getHandEmoji(int? handResult) {
    switch (handResult) {
      case 1:
        return '✌️'; // scissors
      case 2:
        return '✊'; // rock
      case 3:
        return '🖐️'; // paper
      default:
        return '❓';
    }
  }

  String _getHandName(int? handResult) {
    switch (handResult) {
      case 1:
        return '剪刀';
      case 2:
        return '石头';
      case 3:
        return '布';
      default:
        return '未知';
    }
  }

  bool _shouldShowResults() {
    return (stage is RoomSelectingTurn || stage is HandResultDisplay);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowResults()) {
      return const SizedBox.shrink();
    }

    if (style == DisplayStyle.card) {
      return _buildCardStyle();
    } else {
      return _buildStatusBarStyle();
    }
  }

  Widget _buildCardStyle() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade600),
      ),
      child: Column(
        children: [
          if (stage is RoomSelectingTurn || stage is HandResultDisplay) ...[
            _buildPlayerResult(myName, myHandResult, true),
            const SizedBox(height: 8),
            _buildPlayerResult(opponentName, opponentHandResult, false),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerResult(String name, int? handResult, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.amber.withValues(alpha: 0.15) : Colors.blueGrey.shade600,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isMe ? Icons.person : Icons.person_outline,
            size: 16,
            color: isMe ? Colors.amber : Colors.blueGrey.shade300,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isMe ? Colors.amber : Colors.blueGrey.shade300,
                fontSize: 12,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (stage is RoomSelectingTurn || stage is HandResultDisplay) ...[
            Text(
              _getHandEmoji(handResult),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 4),
            Text(
              _getHandName(handResult),
              style: TextStyle(
                color: Colors.blueGrey.shade200,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBarStyle() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF263238), // #263238
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            stage is RoomHandResult ? '猜拳结果' : '先后攻选择',
            style: const TextStyle(
              color: Color(0xFF78909C), // #78909c
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusPlayer(myName, myHandResult, true),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Color(0xFF78909C), // #78909c
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusPlayer(opponentName, opponentHandResult, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPlayer(String name, int? handResult, bool isMe) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFFB0BEC5), // #b0bec5
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _getHandEmoji(handResult),
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          _getHandName(handResult),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
