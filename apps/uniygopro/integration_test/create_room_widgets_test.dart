/// 建房/加入房间系列组件的 widget 集成测试。
///
/// 这些组件均为「纯 UI + 回调注入」，不依赖 ServiceSingleton / Provider，
/// 因此可直接挂到 MaterialApp 下逐项驱动，确定性好、覆盖率高。
library;

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/models/created_room_record.dart';
import 'package:uniygopro/models/mercury233_room_spec.dart';
import 'package:uniygopro/widgets/create_room/create_room_form.dart';
import 'package:uniygopro/widgets/create_room/env_selector.dart';
import 'package:uniygopro/widgets/create_room/join_room_form.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_form_section.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';
import 'package:uniygopro/widgets/create_room/room_history_list.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PasswordField 显示/隐藏切换', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(PasswordField(controller: controller, label: '密码')));
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret');
    expect(controller.text, 'secret');
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('EnvSelector 变更环境', (tester) async {
    DuelEnvironment? selected;
    await tester.pumpWidget(
      _wrap(
        EnvSelector(
          value: DuelEnvironment.koishi,
          onChanged: (v) => selected = v,
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<DuelEnvironment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mercury233').last);
    await tester.pumpAndSettle();
    expect(selected, DuelEnvironment.mercury233);
  });

  testWidgets('JoinRoomForm 普通环境：空密码报错 + 填写后 join', (tester) async {
    final joined = <String>[];
    await tester.pumpWidget(
      _wrap(JoinRoomForm(env: DuelEnvironment.koishi, onJoin: joined.add)),
    );
    await tester.tap(find.text('加入房间'));
    await tester.pump();
    expect(find.text('请输入房间密码'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mypw');
    await tester.tap(find.text('加入房间'));
    await tester.pump();
    expect(joined, ['mypw']);
  });

  testWidgets('JoinRoomForm DSL 环境：空房间串报错', (tester) async {
    await tester.pumpWidget(
      _wrap(JoinRoomForm(env: DuelEnvironment.mercury233, onJoin: (_) {})),
    );
    await tester.tap(find.text('加入房间'));
    await tester.pump();
    expect(find.text('请输入房间串'), findsOneWidget);
  });

  testWidgets('JoinRoomForm AI 环境：直接开始', (tester) async {
    String? joined;
    await tester.pumpWidget(
      _wrap(JoinRoomForm(env: DuelEnvironment.ai, onJoin: (p) => joined = p)),
    );
    expect(find.text('开始人机对战'), findsOneWidget);
    await tester.tap(find.text('开始人机对战'));
    await tester.pump();
    expect(joined, isNotNull);
  });

  testWidgets('RoomHistoryList 回填/进入/删除回调', (tester) async {
    final record = CreatedRoomRecord(
      env: DuelEnvironment.mycard,
      roomName: '历史房',
      password: 'pw',
      options: const RoomOptions(mode: RoomMode.match),
    );
    var filled = 0;
    var entered = 0;
    var deleted = 0;
    await tester.pumpWidget(
      _wrap(
        RoomHistoryList(
          records: [record],
          onFill: (_) => filled++,
          onEnter: (_) => entered++,
          onDelete: (_) => deleted++,
        ),
      ),
    );
    expect(find.text('历史房'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(deleted, 1);
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    expect(entered, 1);
    await tester.tap(find.text('回填'));
    expect(filled, 1);
  });

  testWidgets('CreateRoomForm 普通环境：空密码报错 + 创建成功回调', (tester) async {
    RoomOptions? capturedOptions;
    String? capturedRoomName;
    String? capturedPassword;
    await tester.pumpWidget(
      _wrap(
        CreateRoomForm(
          env: DuelEnvironment.mycard,
          historyLoader: () async => const [],
          onSaveRecord: (_) async {},
          onDeleteRecord: (_) async {},
          onEnterRoom: ({
            required options,
            required roomName,
            required password,
          }) {
            capturedOptions = options;
            capturedRoomName = roomName;
            capturedPassword = password;
          },
        ),
      ),
    );
    // 空密码
    await tester.ensureVisible(find.text('创建房间'));
    await tester.tap(find.text('创建房间'));
    await tester.pump();
    expect(find.text('请设置房间密码'), findsOneWidget);

    // 填写密码后创建
    await tester.enterText(
      find.widgetWithText(TextField, '房间密码'),
      'secret',
    );
    await tester.tap(find.text('创建房间'));
    await tester.pump();
    expect(capturedOptions, isNotNull);
    expect(capturedRoomName, '');
    expect(capturedPassword, isNotNull);
  });

  testWidgets('CreateRoomForm DSL 环境：渲染 233 表单并可切换', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CreateRoomForm(
          env: DuelEnvironment.mercury233,
          historyLoader: () async => const [],
          onSaveRecord: (_) async {},
          onDeleteRecord: (_) async {},
          onEnterRoom: ({
            required options,
            required roomName,
            required password,
          }) {},
        ),
      ),
    );
    expect(find.textContaining('最终房间串:'), findsOneWidget);
    expect(find.byType(Mercury233RoomFormSection), findsOneWidget);
  });

  testWidgets('Mercury233RoomFormSection 交互', (tester) async {
    var spec = const Mercury233RoomSpec();
    await tester.pumpWidget(
      _wrap(
        Mercury233RoomFormSection(
          spec: spec,
          errorText: null,
          onSpecChanged: (next) => spec = next,
        ),
      ),
    );
    expect(find.textContaining('最终房间串:'), findsOneWidget);

    // 修改房间名
    await tester.enterText(
      find.widgetWithText(TextField, '房间名称'),
      '我的房间',
    );
    expect(spec.roomName, '我的房间');

    // 切换不检查卡组 checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(spec.noCheckDeck, isTrue);

    // 切换手动编辑房间串（会以当前生成串作为种子回填）
    await tester.tap(find.text('手动编辑最终房间串'));
    await tester.pumpAndSettle();
    expect(spec.manualRoomStringEnabled, isTrue);
    expect(spec.manualRoomString, isNotEmpty);
  });
}
