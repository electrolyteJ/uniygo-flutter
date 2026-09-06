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
///
/// 尺寸策略：宽度/高度上限固定（[maxWidth] / [maxHeight]），下限包裹内容。
/// 高度侧天然包裹：Column 用 [MainAxisSize.min]，body 经 [Flexible] 松约束，
/// 滚动体（GridView/ListView）须开启 shrinkWrap 才能随内容收缩而非撑满。
/// 宽度侧由 [wrapWidth] 决定：为 true 时用 [IntrinsicWidth] 让面板收缩到
/// 内容固有宽度（上限仍为 [maxWidth]）；内容为网格/列表等无固有宽度的
/// 滚动体时应设为 false，让其撑满 [maxWidth] 以正确分行/分列。
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
    this.wrapWidth = false,
  });

  final Key? panelKey;
  final double maxWidth;
  final double maxHeight;
  final Widget header;
  final Widget body;
  final Widget? actions;
  final Decoration decoration;

  /// 是否按内容固有宽度收缩（最小包裹内容、最大 [maxWidth]）。
  final bool wrapWidth;

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
          final panelPadding = 20.0;
          return Padding(
            key: const ValueKey('responsive-panel-safe-padding'),
            padding: EdgeInsets.all(spec.pagePadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: height),
                child: wrapWidth
                    ? IntrinsicWidth(child: _buildChrome(panelPadding))
                    : _buildChrome(panelPadding),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChrome(double panelPadding) {
    return DecoratedBox(
      key: panelKey ?? const ValueKey('responsive-panel-chrome'),
      decoration: decoration,
      child: Padding(
        padding: EdgeInsets.all(panelPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            Flexible(child: body),
            if (actions != null) ...[
              const SizedBox(height: 12),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}
