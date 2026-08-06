import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../hud/cyber_button.dart';

class HandActionMenuEntry {
  final String label;
  final VoidCallback onTap;

  const HandActionMenuEntry({required this.label, required this.onTap});
}

class HandActionMenu extends StatelessWidget {
  final List<HandActionMenuEntry> actions;

  const HandActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xE6080D16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00F0FF), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withOpacity(0.25),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '可执行操作',
                style: TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < actions.length; i++) ...[
                CyberButton(
                  label: actions[i].label,
                  width: double.infinity,
                  onTap: actions[i].onTap,
                ),
                if (i != actions.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'HandActionMenu',
  size: Size(240, 200),
  brightness: Brightness.dark,
)
Widget handActionMenuPreview() => HandActionMenu(
  actions: const [
    HandActionMenuEntry(label: '攻击', onTap: _noop),
    HandActionMenuEntry(label: '守备表示', onTap: _noop),
    HandActionMenuEntry(label: '发动效果', onTap: _noop),
  ],
);

void _noop() {}
