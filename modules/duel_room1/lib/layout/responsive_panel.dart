import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:duel_room1/layout/duel_room_layout.dart';

const responsivePanelDecoration = BoxDecoration(
  color: Color(0xFF09111A),
  borderRadius: BorderRadius.all(Radius.circular(16)),
  border: Border.fromBorderSide(BorderSide(color: Color(0x5500F0FF))),
  boxShadow: [
    BoxShadow(color: Color(0xAA000000), blurRadius: 28, offset: Offset(0, 12)),
  ],
);

/// Safe-area-aware selector shell with a fixed header/actions and bounded body.
class ResponsivePanel extends StatelessWidget {
  const ResponsivePanel({
    super.key,
    this.panelKey,
    required this.maxWidth,
    required this.header,
    required this.body,
    this.actions,
    this.maxHeight = 620,
    this.decoration = responsivePanelDecoration,
  });

  final Key? panelKey;
  final double maxWidth;
  final double maxHeight;
  final Widget header;
  final Widget body;
  final Widget? actions;
  final Decoration decoration;

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = math.max(
            0.0,
            math.min(spec.dialogMaxSize.width, constraints.maxWidth) -
                spec.pagePadding * 2,
          );
          final availableHeight = math.max(
            0.0,
            math.min(
                  spec.dialogMaxSize.height,
                  constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : spec.dialogMaxSize.height,
                ) -
                spec.pagePadding * 2,
          );
          final width = math.min(maxWidth, availableWidth);
          final height = math.min(maxHeight, availableHeight);
          final panelPadding = spec.isCompact ? 12.0 : 20.0;
          return Padding(
            key: const ValueKey('responsive-panel-safe-padding'),
            padding: EdgeInsets.all(spec.pagePadding),
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: DecoratedBox(
                  key: panelKey ?? const ValueKey('responsive-panel-chrome'),
                  decoration: decoration,
                  child: Padding(
                    padding: EdgeInsets.all(panelPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        SizedBox(height: spec.isCompact ? 4 : 12),
                        Expanded(child: body),
                        if (actions != null) ...[
                          const SizedBox(height: 12),
                          actions!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
