import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/duel/models/duel_menu.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

class HandActionMenu extends StatelessWidget {
  final List<ActionMenuEntry> actions;

  const HandActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final spec = DuelRoomLayout.of(context);
    final width = menuWidthFor(spec);
    return ConstrainedBox(
      key: const ValueKey('hand-action-menu'),
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: spec.safeRect.height * .7,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xE6080D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00F0FF), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < actions.length;
                          index++
                        ) ...[
                          TextButton(
                            key: ValueKey('hand-action-$index'),
                            onPressed: actions[index].onTap,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0x4D00F0FF),
                              side: const BorderSide(
                                color: Color(0xFF00F0FF),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            child: Text(
                              actions[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
        ),
      ),
    );
  }
}

double menuWidthFor(DuelRoomLayoutSpec spec) =>
    (spec.safeRect.width - spec.pagePadding * 2).clamp(0, 220).toDouble();

@Preview(
  name: 'HandActionMenu',
  size: Size(240, 200),
  brightness: Brightness.dark,
)
Widget handActionMenuPreview() => HandActionMenu(
  actions: const [
    ActionMenuEntry(label: '攻击', onTap: _noop),
    ActionMenuEntry(label: '守备表示', onTap: _noop),
    ActionMenuEntry(label: '发动效果', onTap: _noop),
  ],
);

void _noop() {}
