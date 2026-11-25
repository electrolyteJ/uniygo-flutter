import 'package:duel_room3/hud/cyber_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyberOverlay 铺满且不拦截下层点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            const Positioned.fill(child: CyberOverlay()),
          ],
        ),
      ),
    );
    await tester.pump();

    // 叠层自带 IgnorePointer（3D 房射线拾取依赖点击穿透）。
    expect(
      find.descendant(
        of: find.byType(CyberOverlay),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    expect(taps, 1, reason: '赛博后处理叠层不能吃掉决斗场的手势');
  });
}
