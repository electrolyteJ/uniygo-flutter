import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/duel_field_game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duel_room1/platform/platform_adaptive.dart';

void main() {
  group('PlatformAdaptive 上下文菜单平台判断', () {
    testWidgets('桌面平台支持悬停、右键菜单与滚轮', (tester) async {
      final previous = debugDefaultTargetPlatformOverride;
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      late final PlatformAdaptive adaptive;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              adaptive = PlatformAdaptive.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(adaptive.supportsHover, isTrue);
      expect(adaptive.supportsContextMenu, isTrue);
      expect(adaptive.supportsScrollWheel, isTrue);
      debugDefaultTargetPlatformOverride = previous;
    });

    testWidgets('移动平台不支持悬停、右键菜单与滚轮', (tester) async {
      final previous = debugDefaultTargetPlatformOverride;
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late final PlatformAdaptive adaptive;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              adaptive = PlatformAdaptive.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(adaptive.supportsHover, isFalse);
      expect(adaptive.supportsContextMenu, isFalse);
      expect(adaptive.supportsScrollWheel, isFalse);
      debugDefaultTargetPlatformOverride = previous;
    });
  });

  group('DuelFlameGame 右键回调透传', () {
    test('构造参数正确保留', () {
      FieldCard? capturedCard;
      int? capturedFieldCode;
      int? capturedHandIndex;
      int? capturedHandCode;

      final game = DuelFieldGame(
        contextMenuEnabled: true,
        onFieldCardSecondaryTap: (card, code) {
          capturedCard = card;
          capturedFieldCode = code;
        },
        onHandCardSecondaryTap: (index, code) {
          capturedHandIndex = index;
          capturedHandCode = code;
        },
      );

      expect(game.contextMenuEnabled, isTrue);

      const card = FieldCard(
        code: 12345,
        controller: 0,
        zone: 4,
        sequence: 0,
        position: 0x1,
      );
      game.onFieldCardSecondaryTap?.call(card, card.code);
      expect(capturedCard, card);
      expect(capturedFieldCode, 12345);

      game.onHandCardSecondaryTap?.call(2, 67890);
      expect(capturedHandIndex, 2);
      expect(capturedHandCode, 67890);
    });

    test('默认不启用上下文菜单', () {
      final game = DuelFieldGame();
      expect(game.contextMenuEnabled, isFalse);
      expect(game.onFieldCardSecondaryTap, isNull);
      expect(game.onHandCardSecondaryTap, isNull);
    });
  });

  group('ClickableCursor / HoverHighlight', () {
    testWidgets('桌面平台包裹可点击 MouseRegion', (tester) async {
      final previous = debugDefaultTargetPlatformOverride;
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        const MaterialApp(
          home: ClickableCursor(
            child: HoverHighlight(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      final clickableRegion = find.descendant(
        of: find.byType(ClickableCursor),
        matching: find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
        ),
      );
      expect(clickableRegion, findsOneWidget);
      debugDefaultTargetPlatformOverride = previous;
    });

    testWidgets('移动端不包裹可点击 MouseRegion', (tester) async {
      final previous = debugDefaultTargetPlatformOverride;
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        const MaterialApp(
          home: ClickableCursor(
            child: HoverHighlight(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      final clickableRegion = find.descendant(
        of: find.byType(ClickableCursor),
        matching: find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
        ),
      );
      expect(clickableRegion, findsNothing);
      debugDefaultTargetPlatformOverride = previous;
    });
  });
}
