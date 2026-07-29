import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../preview_helpers.dart';

class LpBar extends StatelessWidget {
  final int lp;
  final String playerName;
  final bool isOpponent;
  final bool isActive;

  const LpBar({
    super.key,
    required this.lp,
    required this.playerName,
    this.isOpponent = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (lp / 8000).clamp(0.0, 1.0);
    final barColor = lp > 4000
        ? Colors.greenAccent
        : lp > 2000
            ? Colors.orange
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? Colors.yellowAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.yellowAccent : Colors.grey,
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: Colors.yellowAccent.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              playerName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: lp),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              '$value',
              style: TextStyle(
                color: barColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(name: '满血', group: 'LpBar', wrapper: darkPreviewWrapper)
Widget previewLpFull() =>
    const LpBar(lp: 8000, playerName: 'Player', isActive: true);

@Preview(name: '残血', group: 'LpBar', wrapper: darkPreviewWrapper)
Widget previewLpLow() =>
    const LpBar(lp: 1200, playerName: 'Opponent', isOpponent: true);

@Preview(name: '中等血量', group: 'LpBar', wrapper: darkPreviewWrapper)
Widget previewLpMid() => const LpBar(lp: 4500, playerName: 'Player');
