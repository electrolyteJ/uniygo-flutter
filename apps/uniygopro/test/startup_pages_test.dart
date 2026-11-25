/// 开屏 / 登录 / 主页 / 对战模式的渲染与交互冒烟测试。
library;

import 'dart:convert';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/home/home_page.dart';
import 'package:uniygopro/create_room/create_room_page.dart';
import 'package:uniygopro/login/login_page.dart';
import 'package:uniygopro/splash/splash_page.dart';

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(Widget page, {MyCardAccountApi? api}) {
  return MultiProvider(
    providers: [
      if (api == null)
        ChangeNotifierProvider<MyCardAccountApi>(
          create: (_) => MyCardAccountApi(),
        )
      else
        ChangeNotifierProvider<MyCardAccountApi>.value(value: api),
    ],
    child: MaterialApp(home: page),
  );
}

void main() {
  setUp(() {
    YgoSoundService.enabled = false;
  });

  testWidgets('开屏：品牌字标与资源校验进度', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_app(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('uniy'), findsOneWidget);
    expect(find.text('go'), findsOneWidget);
    expect(find.text('决斗终端'), findsOneWidget);
    expect(find.text('REAL-TIME DUAL CLIENT'), findsNothing);
    expect(find.text('REAL-TIME DUEL CLIENT'), findsOneWidget);
    expect(find.text('第 26 赛季'), findsOneWidget);
    expect(find.textContaining('正在校验卡表与卡图资源'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 卸载以停止动画（正常流程会自动跳转，这里只验证首屏渲染）。
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('登录：账号密码表单与游客入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopSurface(tester);
    await tester.pumpWidget(_app(const LoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('账号登录'), findsOneWidget);
    expect(find.text('使用 MyCard 账号进入主页'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登 录'), findsOneWidget);
    expect(find.text('游客进入主页'), findsOneWidget);
    expect(find.text('记住账号'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
    expect(find.text('20114'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主页：新版页签 / 匹配条 / 设置弹窗与退出账号', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopSurface(tester);
    final api = MyCardAccountApi(
      persistedJson: jsonEncode({
        'id': 42,
        'username': 'kaiba',
        'name': '海马濑人',
        'email': '',
        'token': 'fake-token',
        'external_id': 42,
        'avatar_url': '',
      }),
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(_app(const HomePage(), api: api));
    await tester.pumpAndSettle();

    expect(find.text('公告'), findsOneWidget);
    expect(find.text('青眼白龙'), findsOneWidget);
    expect(find.text('竞技匹配 ▾'), findsOneWidget);
    expect(find.text('开始匹配'), findsOneWidget);
    // 新版底栏：比赛观看 + 卡组/战绩/商店/活动/鉴赏
    expect(find.text('比赛观看 ▾'), findsOneWidget);
    expect(find.text('卡组'), findsOneWidget);
    expect(find.text('战绩'), findsOneWidget);
    expect(find.text('商店'), findsOneWidget);
    expect(find.text('活动'), findsOneWidget);
    expect(find.text('鉴赏'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 设置弹窗：默认画面页签 + 账号页退出
    await tester.tap(find.byKey(const ValueKey('home-settings')));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('分辨率'), findsOneWidget);

    // 对局页签需包含旧版设置的全部选项
    await tester.tap(find.text('对局'));
    await tester.pumpAndSettle();
    expect(find.text('连锁1 也要显示连锁动画'), findsOneWidget);
    expect(find.text('自动选择怪兽卡片位置'), findsOneWidget);
    expect(find.text('自动选择魔陷卡片位置'), findsOneWidget);
    expect(find.text('观战历史'), findsOneWidget);
    expect(find.text('回放速度'), findsOneWidget);
    expect(find.text('带节奏回放'), findsOneWidget);
    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('决斗场地'), findsOneWidget); // flutter test 非 Web

    await tester.tap(find.text('账号'));
    await tester.pumpAndSettle();
    expect(find.text('退出账号'), findsOneWidget);

    // AI 设置页签：来源 + 推理模型；选 233 服时隐藏模型选择
    await tester.tap(find.text('AI 设置'));
    await tester.pumpAndSettle();
    expect(find.text('AI 来源'), findsOneWidget);
    expect(find.text('本地 AI'), findsOneWidget);
    expect(find.text('推理模型'), findsOneWidget);
    expect(find.text('端侧模型'), findsOneWidget);
    expect(find.text('远端模型'), findsOneWidget);

    await tester.tap(find.text('233 服 AI（远端）'));
    await tester.pumpAndSettle();
    expect(find.text('推理模型'), findsNothing);
    expect(find.text('选择「233 服 AI」时无需选择推理模型，模型由服务端决定'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 退出账号只在「账号」页签提供，切回去再点。
    await tester.tap(find.text('账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-secondary')));
    await tester.pumpAndSettle();
    expect(api.isLoggedIn, isFalse);
    expect(find.text('游客'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('建房：底部页签 / 匹配盘 / 各页签配置', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_app(const CreateRoomPage()));
    // 匹配盘有常驻旋转动画，不能用 pumpAndSettle。
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('create-room-back')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('对战'), findsNothing);
    expect(find.text('← 返回大厅'), findsNothing);
    expect(find.text('选择模式后开始匹配'), findsNothing);
    expect(find.text('竞技匹配'), findsOneWidget);
    expect(find.text('娱乐匹配'), findsOneWidget);
    expect(find.text('开始匹配'), findsOneWidget);
    expect(find.text('点击进入匹配'), findsOneWidget);
    expect(find.text('均 12s · 3,214 人在线'), findsOneWidget);
    for (final label in ['匹配', '好友对战', '练习', '自由房间']) {
      expect(find.text(label), findsWidgets);
    }
    // 「加入房间」挂在页壳上：任意页签都能扫码/粘贴邀码进房。
    expect(find.byKey(const ValueKey('create-room-join')), findsOneWidget);
    expect(find.text('加入房间'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 好友对战页签 → 规则设置面板 + 创建房间
    await tester.tap(find.byKey(const ValueKey('create-room-tab-1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('规则设置'), findsOneWidget);
    expect(find.text('卡片允许'), findsOneWidget);
    expect(find.text('初始 LP'), findsOneWidget);
    expect(find.text('初始手牌'), findsOneWidget);
    expect(find.text('不切洗卡组'), findsOneWidget);
    expect(find.text('创建房间'), findsOneWidget);

    // 规则选项复用 Flutter 下拉：点击展开、选中后回填。
    await tester.tap(find.text('OCG'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('TCG'), findsOneWidget);
    await tester.tap(find.text('TCG'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('OCG'), findsNothing);
    expect(find.text('TCG'), findsOneWidget);

    // 408 环境同样走创建房间（不再只能加入）：规则被锁定，只展示固定文案面板
    await tester.tap(find.byKey(const ValueKey('mode-entry-friend-408')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('规则设置'), findsNothing);
    expect(find.text('408 固定规则'), findsOneWidget);
    expect(find.text('不适用'), findsOneWidget);
    expect(find.text('2006.3'), findsOneWidget);
    expect(find.text('规则由环境锁定 · 不可修改'), findsOneWidget);
    expect(find.text('创建房间'), findsWidgets);
    expect(find.text('408 特殊规则 · 创建房间'), findsOneWidget);

    // 练习页签 → 规则设置面板（含赛制下拉）+ 开始人机对战
    await tester.tap(find.byKey(const ValueKey('create-room-tab-2')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('规则设置'), findsOneWidget);
    expect(find.text('赛制'), findsOneWidget);
    expect(find.text('单局'), findsOneWidget);
    expect(find.text('大师规则'), findsOneWidget);
    expect(find.text('初始 LP'), findsOneWidget);
    expect(find.text('禁限卡表'), findsOneWidget);
    expect(find.text('开始人机对战'), findsOneWidget);

    // 自由房间页签 → 左侧环境签 + 宽配置面板
    await tester.tap(find.byKey(const ValueKey('create-room-tab-3')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Koishi 通用环境'), findsOneWidget);
    expect(find.text('mycard 环境'), findsOneWidget);
    // 自由房间收敛成「面板设参数 + 圆盘建房」。
    expect(find.text('规则设置'), findsOneWidget);
    expect(find.text('三局两胜'), findsOneWidget);
    expect(find.text('最近房间'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}