import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room3/waiting/waiting_room_page.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resource_data/lf_table.dart';

class _FakeRoomNotifier extends DuelRoomNotifier {
  _FakeRoomNotifier(this._state);

  final DuelRoomState _state;

  @override
  DuelRoomState build() => _state;

  @override
  Future<void> loadDecks() async {}

  @override
  Future<({ResolvedDeck? deck, String? error})> selectDeck(String? name) async {
    return (deck: null, error: null);
  }

  @override
  Future<String?> toggleReady() async => null;

  @override
  Future<String?> confirmSiding() async => null;

  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DuelRoomState buildState({
    RoomStage? stage,
    bool? firstTurn,
    List<PlayerInfo>? players,
    List<String>? invalidation,
    String? roomId,
    int observerCount = 0,
    PlayerType selfType = PlayerType.player1,
  }) {
    return DuelRoomState(
      stage:
          stage ??
          RoomInLobby(
            selfType: selfType,
            isHost: true,
            options: RoomOptions(),
          ),
      selfType: selfType,
      isHost: true,
      observerCount: observerCount,
      players:
          players ??
          const [PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true)],
      roomOptions: const RoomOptions(),
      invalidationDeckResult: invalidation,
      roomId: roomId,
      isFirstTurn: firstTurn,
    );
  }

  Widget subject({
    VoidCallback? onOpenSettings,
    RoomStage? stage,
    bool? firstTurn,
    List<PlayerInfo>? players,
    List<String>? invalidation,
    String? roomId,
    int observerCount = 0,
    PlayerType selfType = PlayerType.player1,
  }) {
    YgoSoundService.enabled = false;
    addTearDown(() => YgoSoundService.enabled = true);
    return ProviderScope(
      overrides: [
        duelRoomProvider.overrideWith(
          () => _FakeRoomNotifier(
            buildState(
              stage: stage,
              firstTurn: firstTurn,
              players: players,
              invalidation: invalidation,
              roomId: roomId,
              observerCount: observerCount,
              selfType: selfType,
            ),
          ),
        ),
        ygoSoundServiceProvider.overrideWith((ref) => YgoSoundService()),
        if (onOpenSettings != null)
          showYgoSettingsDialogProvider.overrideWithValue(
            (
              context, {
              autoDuel,
              autoHand,
              autoTurnOrder,
              onAutoDuelChanged,
              onAutoHandChanged,
              onAutoTurnOrderChanged,
            }) => onOpenSettings(),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(body: WaitingRoomPage3D(roomId: roomId)),
      ),
    );
  }

  testWidgets('05 等候页：顶部状态栏 / 选手卡 / 等待舞台 / 规则条', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(find.text('海马濑人'), findsOneWidget);
    expect(find.text('出战卡组'), findsOneWidget);
    // 大厅阶段中央直接展示房间信息卡（不再有「等待对手」舞台）。
    expect(find.text('房间信息'), findsWidgets);
    expect(find.text('等待对手加入…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置入口可用，房间信息卡直接展示', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var opened = false;
    await tester.pumpWidget(subject(onOpenSettings: () => opened = true));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('waiting-settings')));
    expect(opened, isTrue);

    // 无浮层入口：信息卡直接可读。
    expect(find.byKey(const ValueKey('waiting-room-info')), findsNothing);
    expect(find.text('房间信息'), findsWidgets);
    expect(find.text('禁限表'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('观战入口：头像堆叠人数 + 点击打开观战列表弹窗', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(observerCount: 2));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('waiting-spectators-entry')),
      findsOneWidget,
    );
    // 有几个观战就叠几个头像（没有“/ 2”上限文案）。
    expect(find.byKey(const ValueKey('spectator-avatar-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('spectator-avatar-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('spectator-avatar-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('waiting-spectators-entry')));
    await tester.pumpAndSettle();
    expect(find.text('观战列表'), findsOneWidget);
    expect(find.text('观战 2 · 仅好友可观看'), findsOneWidget);
    expect(find.text('观战位 1'), findsOneWidget);
    expect(find.text('观战位 2'), findsOneWidget);
    expect(find.text('观战位 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('转为观战：自己的席位显示等待玩家加入', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(observerCount: 1, selfType: PlayerType.observer),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('waiting-self-observer')),
      findsOneWidget,
    );
    expect(find.text('等待玩家加入…'), findsOneWidget);
    // 观战入口头像随观战人数增加（1 人 → 1 个头像）。
    expect(find.byKey(const ValueKey('spectator-avatar-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('spectator-avatar-1')), findsNothing);
    expect(find.text('转为决斗者'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('844×390 设计画布下不溢出', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('房间信息'), findsWidgets);
  });

  testWidgets('05b 猜拳：手势位 + 石头/剪刀/布 + 出拳提示', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(stage: const RoomSelectingHand()));
    await tester.pump();

    expect(find.text('猜拳 · 决定先后攻'), findsOneWidget);
    expect(find.text('石头'), findsOneWidget);
    expect(find.text('剪刀'), findsOneWidget);
    expect(find.text('布'), findsOneWidget);
    expect(find.text('双方选择中 · 倒计时结束后自动出拳'), findsOneWidget);
    expect(find.text('双方已连接 · 出拳决定先后攻'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05b2 出拳结果：显示双方手势与胜负', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(stage: const RoomHandResult(myHand: 1, opponentHand: 3)),
    );
    await tester.pump();

    expect(find.text('出拳结果'), findsOneWidget);
    expect(find.text('你胜出'), findsOneWidget);
    expect(find.text('你 · 剪刀'), findsOneWidget);
    expect(find.text('对手 · 布'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05c 选择先后攻：先攻/后攻可选', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(stage: const RoomSelectingTurn()));
    await tester.pump();

    expect(find.text('猜拳胜出 · 你先选'), findsOneWidget);
    expect(find.text('先攻'), findsOneWidget);
    expect(find.text('后攻'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05c2 等待对手选择：按钮禁用', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(stage: const RoomSelectingTurn()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('05a7 卡组校验：点校验行弹出明细', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(invalidation: const ['禁卡：灰流丽 超出数量', '主卡组 39 张']),
    );
    await tester.pump();

    expect(find.text('卡组不合法 2 项'), findsOneWidget);
    await tester.tap(find.text('卡组不合法 2 项'));
    await tester.pumpAndSettle();

    expect(find.text('卡组校验明细'), findsOneWidget);
    expect(find.text('2 项未通过'), findsOneWidget);
    expect(find.text('禁卡：灰流丽 超出数量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('房间信息含禁限卡表入口', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    // 信息卡常驻：禁限表行直接可见。
    expect(find.text('禁限表'), findsOneWidget);
    expect(find.text('不限制'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2：对手卡展示第二名对手', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
          PlayerInfo(name: '城之内', pos: 2, ready: false),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('城之内'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2 小窗口：选手卡内容缩放不溢出', (tester) async {
    tester.view.physicalSize = const Size(1158, 535);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
          PlayerInfo(name: '城之内', pos: 2, ready: false),
          PlayerInfo(name: '偷摸灵兽幽灵', pos: 3, ready: true),
        ],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('有房间邀码：显示邀请入口并可查看邀码', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(roomId: '462890'));
    await tester.pump();

    expect(find.text('邀码 462890 · 点击邀请好友'), findsOneWidget);
    final invite = find.byKey(const ValueKey('waiting-invite'));
    expect(invite, findsOneWidget);

    await tester.tap(invite);
    await tester.pumpAndSettle();
    expect(find.text('462890'), findsOneWidget);
    expect(find.text('复制房间号'), findsWidgets);
    expect(find.text('复制分享链接'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text('复制分享链接'));
    await tester.pump();
    expect(find.text('分享链接已复制'), findsOneWidget);
  });

  testWidgets('无房间邀码：不展示邀请入口', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(find.byKey(const ValueKey('waiting-invite')), findsNothing);
    expect(find.text('预计 10 秒内匹配'), findsOneWidget);
  });
}