import 'package:biz/duel/models/duel_menu.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// MDPro3 风格操作条：底部居中横向胶囊按钮组（召唤/发动/攻击等）。
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.entries,
    required this.onClose,
  });

  final List<ActionMenuEntry> entries;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: HudTheme.glowPanel(radius: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ActionButton(label: entry.label, onTap: entry.onTap),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  color: HudTheme.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF123049), Color(0xFF1B5A7A)],
          ),
          border: Border.all(color: HudTheme.cyan.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: HudTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
