import 'package:flutter/material.dart';

import 'package:biz/duel/models/duel_menu.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

import 'hand_action_menu.dart';

class PhaseActionMenu extends StatelessWidget {
  final List<ActionMenuEntry> actions;

  const PhaseActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final spec = DuelRoomLayout.of(context);
    return ConstrainedBox(
      key: const ValueKey('phase-action-menu'),
      constraints: BoxConstraints(
        maxWidth: menuWidthFor(spec),
        maxHeight: spec.safeRect.height * .7,
      ),
      child: Container(
        width: menuWidthFor(spec),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xF1080D16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00F0FF), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.18),
              blurRadius: 26,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PHASE ACTION',
              style: TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      _PhaseActionButton(
                        key: ValueKey('phase-action-$index'),
                        label: actions[index].label,
                        onTap: actions[index].onTap,
                      ),
                      if (index != actions.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PhaseActionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      canRequestFocus: true,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Noto Sans SC',
          ),
        ),
      ),
    );
  }
}
