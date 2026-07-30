import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../preview_helpers.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback? onNextPhase;
  final VoidCallback? onSummon;
  final VoidCallback? onAttack;
  final VoidCallback? onSurrender;

  const ActionButtons({
    super.key,
    this.onNextPhase,
    this.onSummon,
    this.onAttack,
    this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(Icons.skip_next, '下一阶段', Colors.amber, onNextPhase),
        const SizedBox(width: 8),
        _buildButton(Icons.flash_on, '召唤', Colors.orange, onSummon),
        const SizedBox(width: 8),
        _buildButton(Icons.sports_kabaddi, '攻击', Colors.redAccent, onAttack),
        const SizedBox(width: 8),
        _buildButton(Icons.flag, '投降', Colors.grey, onSurrender),
      ],
    );
  }

  Widget _buildButton(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(name: '操作按钮', group: 'ActionButtons', wrapper: darkPreviewWrapper)
Widget previewActionButtons() => const ActionButtons();
