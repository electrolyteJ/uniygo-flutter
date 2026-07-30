import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../preview_helpers.dart';

class PlayerBanner extends StatelessWidget {
  final String name;
  final bool isOpponent;
  final int deckCount;
  final int graveCount;
  final int extraCount;

  const PlayerBanner({
    super.key,
    required this.name,
    this.isOpponent = false,
    this.deckCount = 40,
    this.graveCount = 0,
    this.extraCount = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoneChip(Icons.layers, deckCount, Colors.blueGrey),
        const SizedBox(width: 6),
        _buildZoneChip(Icons.archive, graveCount, Colors.deepPurple),
        const SizedBox(width: 6),
        _buildZoneChip(Icons.library_add, extraCount, Colors.teal),
      ],
    );
  }

  Widget _buildZoneChip(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(name: '玩家信息', group: 'PlayerBanner', wrapper: darkPreviewWrapper)
Widget previewPlayerBanner() => const PlayerBanner(
    name: 'Player', deckCount: 35, graveCount: 2, extraCount: 12);
