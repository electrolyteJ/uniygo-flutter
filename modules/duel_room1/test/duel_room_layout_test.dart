import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('DuelRoomLayoutSpec.fixed', () {
    test('固定设计几何（1280×800，无设备安全区）', () {
      const spec = DuelRoomLayoutSpec.fixed;
      expect(spec.viewport, const Size(1280, 800));
      expect(spec.safePadding, EdgeInsets.zero);
      expect(spec.safeRect, const Rect.fromLTWH(0, 0, 1280, 800));
      expect(spec.pagePadding, 18);
      expect(spec.dialogMaxSize, const Size(860, 764));
      expect(spec.dockedPanelWidth, 440);
      expect(spec.gridColumns, 4);
      expect(spec.minimumTapExtent, 44);
      expect(spec.topHudHeight, 52);
      expect(spec.handBarHeight, 96);
      expect(spec.panelGap, 18);
    });

    test('常量实例恒等', () {
      expect(identical(DuelRoomLayoutSpec.fixed, DuelRoomLayoutSpec.fixed), isTrue);
      expect(
        DuelRoomLayoutSpec.fixed.hashCode,
        DuelRoomLayoutSpec.fixed.hashCode,
      );
    });
  });

  testWidgets('DuelRoomLayout exposes spec', (tester) async {
    await tester.pumpWidget(
      DuelRoomLayout(spec: DuelRoomLayoutSpec.fixed, child: const SizedBox()),
    );
    final context = tester.element(find.byType(SizedBox));
    expect(DuelRoomLayout.of(context), DuelRoomLayoutSpec.fixed);
    expect(DuelRoomLayout.maybeOf(context), DuelRoomLayoutSpec.fixed);
  });

  testWidgets('无 DuelRoomLayout 祖先时回退到 fixed', (tester) async {
    late DuelRoomLayoutSpec spec;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          spec = DuelRoomLayout.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(spec, DuelRoomLayoutSpec.fixed);
  });

  testWidgets('同一常量 spec 不触发重复依赖通知', (tester) async {
    final dependencies = ValueNotifier(0);
    final dependent = _LayoutDependent(dependencies: dependencies);
    await tester.pumpWidget(
      DuelRoomLayout(spec: DuelRoomLayoutSpec.fixed, child: dependent),
    );
    await tester.pumpWidget(
      DuelRoomLayout(spec: DuelRoomLayoutSpec.fixed, child: dependent),
    );
    expect(dependencies.value, 1);
  });
}
