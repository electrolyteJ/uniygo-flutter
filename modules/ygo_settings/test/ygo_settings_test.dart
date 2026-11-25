import 'package:biz/ygo_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_settings/ygo_settings.dart';
import 'package:ygo_settings/ygo_settings_dialog.dart';

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
      bool isLoggedIn = false,
      VoidCallback? onClose,
      VoidCallback? onSignOut,
      bool? autoHand,
      ValueChanged<bool>? onAutoHandChanged,
      bool? autoDuel,
      ValueChanged<bool>? onAutoDuelChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 844,
              height: 390,
              child: YgoSettingsDialog(
                isLoggedIn: isLoggedIn,
                accountName: isLoggedIn ? '海马濑人' : null,
                accountUsername: isLoggedIn ? 'kaiba' : null,
                onClose: onClose,
                onSignOut: onSignOut,
                autoDuel: autoDuel,
                autoHand: autoHand,
                onAutoDuelChanged: onAutoDuelChanged,
                onAutoHandChanged: onAutoHandChanged,
                onGoLogin: () {},
                onOpenPreview: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('默认画面页：五个页签 + 分辨率 + AI 入口', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog());
      await tester.pump();

      expect(find.text('设置'), findsOneWidget);
      for (final label in ['画面', '音效', '对局', '账号', 'AI 设置']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('分辨率'), findsOneWidget);
    });

    testWidgets('AI 设置页：来源 / 推理模型；选 233 后隐藏模型选择', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog());
      await tester.pump();

      await tester.tap(find.text('AI 设置'));
      await tester.pumpAndSettle();
      expect(find.text('AI 来源'), findsOneWidget);
      expect(find.text('推理模型'), findsOneWidget);
      expect(find.text('端侧模型'), findsOneWidget);

      await tester.tap(find.text('233 服 AI（远端）'));
      await tester.pumpAndSettle();
      expect(find.text('推理模型'), findsNothing);
      expect(find.text('选择「233 服 AI」时无需选择推理模型，模型由服务端决定'), findsOneWidget);
    });

    testWidgets('账号页：登录态显示退出账号并回调宿主', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var signedOut = false;
      await tester.pumpWidget(
        buildDialog(isLoggedIn: true, onSignOut: () => signedOut = true),
      );
      await tester.pump();

      await tester.tap(find.text('账号'));
      await tester.pumpAndSettle();
      expect(find.text('海马濑人'), findsOneWidget);
      expect(find.text('退出账号'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-secondary')));
      await tester.pump();
      expect(signedOut, isTrue);
    });

    testWidgets('对局页按等候厅/决斗场地分组', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog());
      await tester.pump();

      await tester.tap(find.text('对局'));
      await tester.pumpAndSettle();

      expect(find.text('等候厅'), findsOneWidget);
      expect(find.text('自动加入决斗'), findsOneWidget);
      expect(find.text('自动猜拳'), findsOneWidget);
      expect(find.text('自动选先后手'), findsOneWidget);
      expect(find.text('决斗场地'), findsOneWidget);
      expect(find.text('渲染模式'), findsOneWidget);
      expect(find.text('连锁1 也要显示连锁动画'), findsOneWidget);
      expect(find.text('自动选择怪兽卡片位置'), findsOneWidget);
      expect(find.text('自动选择魔陷卡片位置'), findsOneWidget);
    });

    testWidgets('保存等候厅开关落 SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog(onClose: () {}));
      await tester.pump();

      await tester.tap(find.text('对局'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自动猜拳'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('duel.auto_hand_enabled'), isTrue);
      expect(prefs.getBool('duel.auto_duel_enabled'), isFalse);
    });

    testWidgets('画面页：分辨率/画质/帧率只读展示自动值', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog(onClose: () {}));
      await tester.pump();

      // 没有消费方的三项不再做成可点项（改了也不生效会误导）。
      expect(find.text('自动 · 跟随屏幕'), findsOneWidget);
      expect(find.text('自动 · 跟随设备性能'), findsOneWidget);
      expect(find.text('自动 · 跟随屏幕刷新率'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('home_settings.resolution'), isNull);
      expect(prefs.getInt('home_settings.quality'), isNull);
      expect(prefs.getInt('home_settings.fps'), isNull);
    });

    testWidgets('保存：注入等候厅回调时音效开关依然落盘', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        buildDialog(onClose: () {}, onAutoDuelChanged: (_) {}),
      );
      await tester.pump();

      await tester.tap(find.text('音效'));
      await tester.pumpAndSettle();
      expect(find.text('音效总开关'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-sound-switch')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('home_settings.sound_enabled'),
        isFalse,
        reason: '音效是纯偏好，与房间无关，不该被「有即时回调就不写」的分支吞掉',
      );
    });

    testWidgets('恢复默认：默认值立即写回偏好，无需再点保存', (tester) async {
      SharedPreferences.setMockInitialValues({
        'home_settings.fullscreen': false,
        'home_settings.sound_enabled': false,
        'home_settings.ai_server_233': true,
        'home_settings.ai_model': 2,
        'duel.auto_hand_enabled': true,
      });
      await tester.pumpWidget(buildDialog(onClose: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-secondary')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('home_settings.fullscreen'), isTrue);
      expect(prefs.getBool('home_settings.sound_enabled'), isTrue);
      expect(prefs.getBool('home_settings.ai_server_233'), isFalse);
      expect(prefs.getInt('home_settings.ai_model'), 0);
      expect(prefs.getBool('duel.auto_hand_enabled'), isFalse);
      expect(prefs.getBool('duel.auto_duel_enabled'), isFalse);
    });

    testWidgets('恢复默认：注入了房间回调时同时作用到当前房间', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool? duel;
      await tester.pumpWidget(
        buildDialog(
          onClose: () {},
          autoDuel: true,
          onAutoDuelChanged: (v) => duel = v,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-secondary')));
      await tester.pumpAndSettle();

      expect(duel, isFalse, reason: '恢复默认应把当前房间的开关也关掉');
    });

    testWidgets('等候厅开关：初值来自当前房间并即时回调', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool? changed;
      await tester.pumpWidget(
        buildDialog(autoHand: true, onAutoHandChanged: (v) => changed = v),
      );
      await tester.pump();

      await tester.tap(find.text('对局'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自动猜拳'));
      await tester.pump();

      expect(changed, isFalse, reason: '关闭应立即回调当前房间');
    });

    testWidgets('兼容旧调用方式：initialSettings + 五个回调 + extraActions', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var monster = false;
      var actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 844,
                height: 390,
                child: YgoSettingsDialog(
                  initialSettings: YgoSettings.defaults,
                  onShowChain1Changed: (_) {},
                  onAutoMonsterChanged: (v) => monster = v,
                  onAutoSpellTrapChanged: (_) {},
                  onSpectateJumpChanged: (_) {},
                  onReplaySpeedFactorChanged: (_) {},
                  extraActions: [
                    SettingsExtraAction(
                      label: '自定义入口',
                      icon: Icons.view_in_ar,
                      onTap: (_) => actionTapped = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('对局'));
      await tester.pumpAndSettle();
      // 等候厅分组把决斗场地项推到滚动区下方，先滚到可见再点。
      final monsterSwitch = find.text('自动选择怪兽卡片位置');
      await tester.ensureVisible(monsterSwitch);
      await tester.pumpAndSettle();
      await tester.tap(monsterSwitch);
      expect(monster, isTrue, reason: '旧回调 onAutoMonsterChanged 未触发');

      final action = find.text('自定义入口');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action, findsOneWidget);
      await tester.tap(action);
      expect(actionTapped, isTrue);
    });

    testWidgets('游客态账号页显示前往登录', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildDialog());
      await tester.pump();

      await tester.tap(find.text('账号'));
      await tester.pumpAndSettle();
      expect(find.text('游客'), findsOneWidget);
      expect(find.text('前往登录'), findsOneWidget);
    });
  });
}
