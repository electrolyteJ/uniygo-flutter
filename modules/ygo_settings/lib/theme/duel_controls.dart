/// 三屏共用的小交互件。
library;

import 'package:flutter/material.dart';

/// 无水波点击区域：鼠标悬停高亮，点击回调；键盘 Enter/Space 亦可触发。
class DuelHit extends StatefulWidget {
  const DuelHit({
    super.key,
    required this.child,
    this.onTap,
    this.hoverColor = const Color(0x0AFFFFFF),
    this.cursor = SystemMouseCursors.click,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color hoverColor;
  final MouseCursor cursor;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  @override
  State<DuelHit> createState() => _DuelHitState();
}

class _DuelHitState extends State<DuelHit> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: _hovered && enabled ? widget.hoverColor : Colors.transparent,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );

    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? widget.cursor : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }
}
