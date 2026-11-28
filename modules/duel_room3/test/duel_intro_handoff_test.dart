import 'package:duel_room3/field/duel_field_page.dart';
import 'package:duel_room3/loading/duel_field_loading_page.dart';
import 'package:duel_room3/loading/models/duel_intro_timeline.dart';
import 'package:duel_room3/loading/widgets/intro_phases.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 校验「加载页 → 场地」的交接时序契约。
///
/// 这里不挂整个 `DuelRoomPage3D`（要真连接 + flame_3d 的 GPU 后端），
/// 也不挂 `DuelFieldPage3D`（build 里就会碰 `gpuContext`，测试环境没有
/// Impeller 会直接抛异常）。只钉住两根支柱：
///
/// 1. `DuelFieldPage3D` **自己**创建 3D（构造签名里没有 `game` 参数）——
///    页面之间不共享实例，加载页不预热 3D；
/// 2. `DuelFieldLoadingPage` 按时间轴演完即交接（设计稿 2700ms，全程可跳过）。
const _sceneData = DuelIntroSceneData(
  myName: '混沌龙博士',
  opponentName: '剑斗士 K',
  iGoFirst: true,
);

/// 场地页构造签名的**类型守卫**。
///
/// 只在类型层面存在，不实例化（实例化会触碰 GPU）。若有人把 3D 实例重新
/// 加回构造参数（那意味着又要跨页共享，回到 `PageView` 不保活 + flame
/// 单值 `_gameRenderBox` 的老坑），下面 main() 里的赋值会立刻编译失败。
typedef DuelFieldPage3DFactory =
    DuelFieldPage3D Function({
      Key? key,
      required List<PlayerInfo> players,
      VoidCallback? onSceneReady,
    });

void main() {
  group('场地页 3D 实例归属', () {
    // 注意：这里不能真的 `Duel3DGame(...)`——它的构造函数就会创建
    // GraphicsDevice → `gpuContext`，测试环境没有 Impeller 会直接抛
    // `Flutter GPU requires the Impeller rendering backend`。
    //
    // 改用**函数类型**校验签名：3D 必须由场地页自己建，构造签名里
    // 不该出现 `game`。赋值本身就是断言。
    test('场地页自己创建 3D，不从外部接收实例', () {
      const DuelFieldPage3DFactory ctor = DuelFieldPage3D.new;
      expect(ctor, isNotNull);
    });
  });

  group('交接时序', () {
    Future<int Function()> pumpIntro(WidgetTester tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(
            data: _sceneData,
            onFinished: () => finished++,
          ),
        ),
      );
      return () => finished;
    }

    testWidgets('演出没演完不交接', (tester) async {
      final read = await pumpIntro(tester);

      // 还在 02 field 相位。
      await tester.pump(const Duration(milliseconds: 1200));
      expect(read(), 0);

      // 进了 03 vs 但没播完。
      await tester.pump(
        Duration(milliseconds: DuelIntroTimeline.totalMs - 1500),
      );
      expect(read(), 0);
    });

    testWidgets('演出播完 → 立刻交接', (tester) async {
      final read = await pumpIntro(tester);
      await tester.pump(Duration(milliseconds: DuelIntroTimeline.totalMs));
      await tester.pumpAndSettle();
      expect(read(), 1);
    });

    testWidgets('跳过后立刻交接，不等自然播完', (tester) async {
      final read = await pumpIntro(tester);
      await tester.pump();
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(read(), 1);
    });
  });
}
