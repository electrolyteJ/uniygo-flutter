/// MyCard 登录门控（requireMyCardAccount）的 widget 测试。
///
/// 这部分覆盖原先挂在旧建房/加入房间表单上的用例：门控逻辑在
/// login/mycard_gate.dart，与表单无关，因此随旧组件删除后在这里重建。
library;

import 'dart:convert';

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:uniygopro/login/mycard_gate.dart';

void main() {
  /// 一个按钮：点击后走门控，结果回调给测试。
  Widget host(MyCardAccountApi api, void Function(MyCardAccount?) onDone) {
    return MaterialApp(
      home: ChangeNotifierProvider<MyCardAccountApi>.value(
        value: api,
        child: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async =>
                    onDone(await requireMyCardAccount(ctx, reason: '测试原因')),
                child: const Text('开始'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('未登录：弹出登录框，取消后中止（返回 null）', (tester) async {
    final api = MyCardAccountApi();
    addTearDown(api.dispose);
    MyCardAccount? result;
    var done = false;

    await tester.pumpWidget(
      host(api, (v) {
        done = true;
        result = v;
      }),
    );
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    expect(done, isFalse, reason: '门控应等待用户操作');
    expect(find.text('登录 MyCard 账号'), findsOneWidget);
    expect(find.text('测试原因'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(result, isNull);
    expect(find.text('登录 MyCard 账号'), findsNothing);
  });

  testWidgets('未登录：用户名/密码为空时本地报错，不发请求', (tester) async {
    final api = MyCardAccountApi();
    addTearDown(api.dispose);

    await tester.pumpWidget(host(api, (_) {}));
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mycard-login-submit')));
    await tester.pump();

    expect(find.text('请输入用户名和密码'), findsOneWidget);
    expect(find.text('登录 MyCard 账号'), findsOneWidget);
  });

  testWidgets('已登录：不弹登录框，直接返回当前账号', (tester) async {
    const account = MyCardAccount(
      id: 42,
      username: 'kai',
      name: '',
      email: '',
      token: 'tok',
      externalId: 12345,
    );
    final api = MyCardAccountApi(persistedJson: jsonEncode(account.toJson()));
    addTearDown(api.dispose);
    MyCardAccount? result;

    await tester.pumpWidget(host(api, (v) => result = v));
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    expect(find.text('登录 MyCard 账号'), findsNothing);
    expect(result?.username, 'kai');
  });
}
