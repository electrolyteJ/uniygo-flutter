import 'package:biz/ygo_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_settings/ygo_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DuelRoomRendererPreference', () {
    test('默认值 2D；set 后持久化并通知', () async {
      SharedPreferences.setMockInitialValues({});
      await DuelRoomRendererPreference.restore();
      expect(DuelRoomRendererPreference.current.value, DuelRoomRenderer.room2d);

      await DuelRoomRendererPreference.set(DuelRoomRenderer.room3d);
      expect(DuelRoomRendererPreference.current.value, DuelRoomRenderer.room3d);

      // 模拟重启恢复
      DuelRoomRendererPreference.current.value = DuelRoomRenderer.room2d;
      await DuelRoomRendererPreference.restore();
      expect(DuelRoomRendererPreference.current.value, DuelRoomRenderer.room3d);

      // 复位，避免影响其它用例
      await DuelRoomRendererPreference.set(DuelRoomRenderer.room2d);
    });
  });

  group('YgoSettingsDialog', () {
    Widget buildDialog({
      List<SettingsExtraAction> extraActions = const [],
      ValueChanged<bool>? onAutoMonster,
      ValueChanged<bool>? onSpectateJump,
      ValueChanged<double>? onReplaySpeedFactor,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: YgoSettingsDialog(
            initialSettings: YgoSettings.defaults,
            onShowChain1Changed: (_) {},
            onAutoMonsterChanged: onAutoMonster ?? (_) {},
            onAutoSpellTrapChanged: (_) {},
            onSpectateJumpChanged: onSpectateJump ?? (_) {},
            onReplaySpeedFactorChanged: onReplaySpeedFactor ?? (_) {},
            extraActions: extraActions,
          ),
        ),
      );
    }

    testWidgets('渲染三个对局开关 + 2D/3D 分段选择', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog());
      expect(find.text('连锁1 也要显示连锁动画'), findsOneWidget);
      expect(find.text('自动选择怪兽卡片位置'), findsOneWidget);
      expect(find.text('自动选择魔陷卡片位置'), findsOneWidget);
      // 测试环境非 Web → 显示渲染选择
      expect(find.text('决斗场地'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('切换开关触发回调；切换 3D 更新渲染偏好', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var monster = false;
      await tester.pumpWidget(buildDialog(onAutoMonster: (v) => monster = v));
      await tester.tap(find.text('自动选择怪兽卡片位置'));
      expect(monster, isTrue);

      await tester.tap(find.text('3D'));
      await tester.pump();
      expect(DuelRoomRendererPreference.current.value, DuelRoomRenderer.room3d);
      await DuelRoomRendererPreference.set(DuelRoomRenderer.room2d);
    });

    testWidgets('观战区块渲染；切换模式与速度触发回调', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 加高测试 surface，保证弹窗全部区块在可见区域（可直接 tap）。
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var jump = false;
      var speed = 1.0;
      await tester.pumpWidget(buildDialog(
        onSpectateJump: (v) => jump = v,
        onReplaySpeedFactor: (v) => speed = v,
      ));
      expect(find.text('观战'), findsOneWidget);
      expect(find.text('带节奏回放'), findsOneWidget);
      expect(find.text('跳到当前局面'), findsOneWidget);

      await tester.tap(find.text('跳到当前局面'));
      expect(jump, isTrue);

      await tester.tap(find.text('2x'));
      expect(speed, 2.0);
    });

    test('观战回放设置持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
      ]);
      addTearDown(container.dispose);
      // 等异步读盘落定。
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(ygoSettingsProvider.notifier);
      notifier.setSpectateJumpToCurrent(true);
      notifier.setReplaySpeedFactor(2.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 新容器模拟重启：先 read 触发 build/_load，再等读盘落定后读状态。
      final container2 = ProviderContainer(overrides: [
        ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
      ]);
      addTearDown(container2.dispose);
      container2.read(ygoSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final restored = container2.read(ygoSettingsProvider);
      expect(restored.spectateJumpToCurrent, isTrue);
      expect(restored.replaySpeedFactor, 2.0);
    });

    testWidgets('附加动作渲染并可点击', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 加高测试 surface，保证弹窗全部区块在可见区域（可直接 tap）。
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var tapped = false;
      await tester.pumpWidget(buildDialog(extraActions: [
        SettingsExtraAction(
          label: '3D 场景预览',
          icon: Icons.view_in_ar,
          onTap: (_) => tapped = true,
        ),
      ]));
      await tester.tap(find.text('3D 场景预览'));
      expect(tapped, isTrue);
    });
  });
}
