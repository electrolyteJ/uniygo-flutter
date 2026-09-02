import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

class _LayoutDependent extends StatefulWidget {
  const _LayoutDependent({required this.dependencies});

  final ValueNotifier<int> dependencies;

  @override
  State<_LayoutDependent> createState() => _LayoutDependentState();
}

class _LayoutDependentState extends State<_LayoutDependent> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DuelRoomLayout.of(context);
    widget.dependencies.value++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('DuelRoomLayoutSpec.resolve', () {
    test('selects size class from safe dimensions with larger boundaries', () {
      expect(
        DuelRoomLayoutSpec.resolve(const Size(640, 360)).sizeClass,
        DuelRoomSizeClass.compact,
      );
      expect(
        DuelRoomLayoutSpec.resolve(const Size(800, 450)).sizeClass,
        DuelRoomSizeClass.compact,
      );
      expect(
        DuelRoomLayoutSpec.resolve(const Size(1280, 720)).sizeClass,
        DuelRoomSizeClass.regular,
      );
      expect(
        DuelRoomLayoutSpec.resolve(const Size(1920, 1080)).sizeClass,
        DuelRoomSizeClass.wide,
      );
      expect(
        DuelRoomLayoutSpec.resolve(const Size(1024, 600)).sizeClass,
        DuelRoomSizeClass.regular,
      );
      expect(
        DuelRoomLayoutSpec.resolve(const Size(1600, 900)).sizeClass,
        DuelRoomSizeClass.wide,
      );
      expect(
        DuelRoomLayoutSpec.resolve(
          const Size(1640, 920),
          safePadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        ).sizeClass,
        DuelRoomSizeClass.wide,
      );
      expect(
        DuelRoomLayoutSpec.resolve(
          const Size(1600, 900),
          safePadding: const EdgeInsets.only(left: 1),
        ).sizeClass,
        DuelRoomSizeClass.regular,
      );
    });

    test('clamps negative and oversized safe padding inside viewport', () {
      final negative = DuelRoomLayoutSpec.resolve(
        const Size(640, 360),
        safePadding: const EdgeInsets.fromLTRB(-10, -20, 21, 16),
      );
      expect(negative.safePadding, const EdgeInsets.fromLTRB(0, 0, 21, 16));
      expect(negative.safeRect, const Rect.fromLTWH(0, 0, 619, 344));

      final oversized = DuelRoomLayoutSpec.resolve(
        const Size(100, 50),
        safePadding: const EdgeInsets.fromLTRB(80, 40, 80, 40),
      );
      expect(oversized.safePadding, const EdgeInsets.fromLTRB(80, 40, 20, 10));
      expect(oversized.safeRect, const Rect.fromLTWH(80, 40, 0, 0));
      expect(oversized.dialogMaxSize, Size.zero);
      expect(oversized.dockedPanelWidth, 0);
    });

    test('normalizes invalid viewport dimensions to one', () {
      for (final raw in [
        Size.zero,
        const Size(-10, -20),
        const Size(double.nan, double.infinity),
      ]) {
        final spec = DuelRoomLayoutSpec.resolve(raw);
        expect(spec.viewport, const Size(1, 1));
        expect(spec.safeRect, const Rect.fromLTWH(0, 0, 1, 1));
        expect(spec.hudScale, 1);
      }
    });

    test(
      'uses safe height for hud scale and preserves invalid-height fallback',
      () {
        expect(DuelRoomLayoutSpec.resolve(const Size(1280, 760)).hudScale, 1);
        expect(
          DuelRoomLayoutSpec.resolve(
            const Size(1280, 760),
            safePadding: const EdgeInsets.symmetric(vertical: 76),
          ).hudScale,
          closeTo(0.8, 1e-9),
        );
        expect(DuelRoomLayoutSpec.resolve(const Size(640, 360)).hudScale, 0.6);
        expect(DuelRoomLayoutSpec.resolve(const Size(640, 0)).hudScale, 1);
      },
    );

    test('provides responsive geometry and grid columns', () {
      final compact = DuelRoomLayoutSpec.resolve(const Size(640, 360));
      final regular = DuelRoomLayoutSpec.resolve(const Size(1280, 720));

      expect(compact.gridColumns, 2);
      expect(DuelRoomLayoutSpec.resolve(const Size(800, 450)).gridColumns, 3);
      expect(regular.gridColumns, 4);
      expect(compact.isCompact, isTrue);
      expect(compact.minimumTapExtent, 44);
      expect(compact.pagePadding, 8);
      expect(compact.panelGap, 8);
      expect(compact.topHudHeight, 52 * compact.hudScale);
      expect(compact.handBarHeight, 96 * compact.hudScale);
      expect(regular.pagePadding, 18);
      expect(regular.panelGap, 18);
      expect(regular.dialogMaxSize, const Size(860, 684));
      expect(regular.dockedPanelWidth, 440);
    });

    test('implements value equality', () {
      final first = DuelRoomLayoutSpec.resolve(
        const Size(1280, 720),
        safePadding: const EdgeInsets.all(8),
      );
      final second = DuelRoomLayoutSpec.resolve(
        const Size(1280, 720),
        safePadding: const EdgeInsets.all(8),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(DuelRoomLayoutSpec.resolve(const Size(1281, 720))));
    });
  });

  testWidgets(
    'DuelRoomLayout exposes spec and avoids equal-value notifications',
    (tester) async {
      final spec = DuelRoomLayoutSpec.resolve(const Size(800, 450));
      final dependencies = ValueNotifier(0);
      final dependent = _LayoutDependent(dependencies: dependencies);

      await tester.pumpWidget(DuelRoomLayout(spec: spec, child: dependent));
      final context = tester.element(find.byType(_LayoutDependent));
      expect(DuelRoomLayout.of(context), spec);
      expect(DuelRoomLayout.maybeOf(context), spec);
      await tester.pumpWidget(
        DuelRoomLayout(
          spec: DuelRoomLayoutSpec.resolve(const Size(800, 450)),
          child: dependent,
        ),
      );
      expect(dependencies.value, 1);
    },
  );

  testWidgets('DuelRoomLayout notifies dependents when spec changes', (
    tester,
  ) async {
    final dependencies = ValueNotifier(0);
    final dependent = _LayoutDependent(dependencies: dependencies);

    await tester.pumpWidget(
      DuelRoomLayout(
        spec: DuelRoomLayoutSpec.resolve(const Size(800, 450)),
        child: dependent,
      ),
    );
    await tester.pumpWidget(
      DuelRoomLayout(
        spec: DuelRoomLayoutSpec.resolve(const Size(1280, 720)),
        child: dependent,
      ),
    );

    expect(dependencies.value, 2);
  });

  testWidgets(
    'DuelRoomLayout fallback keeps view padding when keyboard opens',
    (tester) async {
      const viewPadding = EdgeInsets.fromLTRB(12, 4, 20, 8);
      const viewInsets = EdgeInsets.only(bottom: 120);
      late DuelRoomLayoutSpec spec;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 450),
            padding: EdgeInsets.fromLTRB(12, 4, 20, 0),
            viewPadding: viewPadding,
            viewInsets: viewInsets,
          ),
          child: Builder(
            builder: (context) {
              spec = DuelRoomLayout.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(spec.safePadding, viewPadding);
      expect(spec.safeRect, const Rect.fromLTWH(12, 4, 768, 438));
    },
  );

  testWidgets('responsive harness preserves custom MediaQuery values', (
    tester,
  ) async {
    const size = Size(800, 450);
    const padding = EdgeInsets.fromLTRB(12, 4, 20, 8);
    const insets = EdgeInsets.only(bottom: 120);
    const scaler = TextScaler.linear(1.3);
    late MediaQueryData data;
    late DuelRoomLayoutSpec spec;
    late BoxConstraints constraints;

    await pumpResponsiveWidget(
      tester,
      LayoutBuilder(
        builder: (context, value) {
          constraints = value;
          return Builder(
            builder: (context) {
              data = MediaQuery.of(context);
              spec = DuelRoomLayout.of(context);
              return const SizedBox();
            },
          );
        },
      ),
      size,
      safePadding: padding,
      textScaler: scaler,
      viewInsets: insets,
    );

    expect(responsiveViewports, containsAll([size, const Size(640, 360)]));
    expect(data.size, size);
    expect(data.padding, const EdgeInsets.fromLTRB(12, 4, 20, 0));
    expect(data.viewPadding, const EdgeInsets.fromLTRB(12, 4, 20, 0));
    expect(data.viewInsets, EdgeInsets.zero);
    expect(data.textScaler.scale(10), 13);
    expect(constraints.maxHeight, size.height - insets.bottom);
    expect(spec.safePadding, padding);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in responsiveViewports) {
    testWidgets('responsive harness pumps $viewport exactly', (tester) async {
      late MediaQueryData data;
      late DuelRoomLayoutSpec spec;

      await pumpResponsiveWidget(
        tester,
        Builder(
          builder: (context) {
            data = MediaQuery.of(context);
            spec = DuelRoomLayout.of(context);
            return const SizedBox();
          },
        ),
        viewport,
      );

      expect(data.size, viewport);
      expect(spec.viewport, viewport);
      expect(tester.view.physicalSize, viewport);
      expect(tester.view.devicePixelRatio, 1);
    });
  }
}
