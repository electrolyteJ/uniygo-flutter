/// 房间流程前三页的 widget 级测试：等候大厅（05）、猜拳（05b）、选先后攻（05c）。
///
/// 原名 `waiting_room_page_3d_test` 只对应 `waiting/` 目录时代；该目录已
/// 拆成 `lobby/` + `hand/` + `turn/` 三页，本文件同时覆盖三页，故改名。
library;

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room3/hand/hand_page.dart';
import 'package:duel_room3/lobby/lobby_page.dart';
import 'package:duel_room3/turn/turn_page.dart';
import 'package:duel_room3/widgets/phase_status_bar.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resource_data/lf_table.dart';

/// 只记录发出的聊天内容，避免真的走 duelService。
class _FakeChatNotifier extends DuelChatNotifier {
  _FakeChatNotifier(this.sent);

  final List<String> sent;

  @override
  DuelChatState build() => const DuelChatState();

  @override
  void sendChat(String text) => sent.add(text);
}

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
  LfTable? getLfTable(int hash) => null;
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
    RoomMode mode = RoomMode.match,
  }) {
    return DuelRoomState(
      stage:
          stage ??
          RoomInLobby(
            selfType: selfType,
            isHost: true,
            options: RoomOptions(mode: mode),
          ),
      selfType: selfType,
      isHost: true,
      observerCount: observerCount,
      players:
          players ??
          const [PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true)],
      roomOptions: RoomOptions(mode: mode),
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
    RoomMode mode = RoomMode.match,
    bool isAiRoom = false,
    List<String>? sentChat,
  }) {
    YgoSoundService.enabled = false;
    addTearDown(() => YgoSoundService.enabled = true);
    final state = buildState(
      stage: stage,
      firstTurn: firstTurn,
      players: players,
      invalidation: invalidation,
      roomId: roomId,
      observerCount: observerCount,
      selfType: selfType,
      mode: mode,
    );
    final page =
        state.stage is RoomSelectingHand || state.stage is RoomHandResult
        ? const HandPage3D()
        : state.stage is RoomSelectingTurn
        ? const TurnPage3D()
        : LobbyPage3D(roomId: roomId, isAiRoom: isAiRoom);
    return ProviderScope(
      overrides: [
        duelRoomProvider.overrideWith(() => _FakeRoomNotifier(state)),
        ygoSoundServiceProvider.overrideWith((ref) => YgoSoundService()),
        if (sentChat != null)
          duelChatProvider.overrideWith(() => _FakeChatNotifier(sentChat)),
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
      child: MaterialApp(home: Scaffold(body: page)),
    );
  }

  testWidgets('05 等候页：顶部状态栏 / 选手卡 / 等待舞台 / 规则条', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(find.text('海马濑人'), findsOneWidget);
    expect(find.text('更换'), findsOneWidget);
    // 大厅阶段中央直接展示房间信息卡（不再有「等待对手」舞台）。
    // 信息卡标题是「房间#<邀码>」，不再有单独的「房间信息」字样。
    expect(find.textContaining('房间#'), findsWidgets);
    expect(find.text('等待加入…'), findsOneWidget);
    // 设计稿底栏：聊天 + 转为观战 / 开始决斗 / 准备。
    expect(find.byKey(const ValueKey('waiting-chat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('waiting-become-observer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('waiting-start-duel')), findsNothing);
    expect(find.byKey(const ValueKey('waiting-ready')), findsOneWidget);
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
    expect(find.textContaining('房间#'), findsWidgets);
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
    // 入口为 120×26 胶囊：三个小人叠加 + 「观战 N」文案（设计稿 369:37）。
    expect(find.byKey(const ValueKey('spectator-avatar-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('spectator-avatar-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('spectator-avatar-2')), findsOneWidget);
    expect(find.text('观战 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('waiting-spectators-entry')));
    await tester.pumpAndSettle();
    expect(find.text('观战列表'), findsOneWidget);
    expect(find.text('观战 2 · 仅好友可观看'), findsOneWidget);
    expect(find.text('观战位 1'), findsOneWidget);
    expect(find.text('观战位 2'), findsOneWidget);
    expect(find.text('观战位 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('转为观战：左侧展示队伍 1 玩家与观战提示', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(observerCount: 1, selfType: PlayerType.observer),
    );
    await tester.pump();

    // 观战者左侧不再是空态：展示队伍 1 的玩家 + 观战提示。
    final ally = find.byKey(const ValueKey('waiting-ally-card'));
    expect(ally, findsOneWidget);
    expect(
      find.descendant(of: ally, matching: find.text('海马濑人')),
      findsOneWidget,
    );
    expect(find.text('你正在观战 · 点「转为决斗者」回到席位'), findsOneWidget);
    // 观战者没有「准备」这个动作：占位按钮要说清状态，不能只写「准备」。
    expect(find.text('无需准备'), findsOneWidget);
    expect(find.text('准备'), findsNothing);
    expect(find.byKey(const ValueKey('waiting-self-observer')), findsNothing);
    // 观战入口人数随观战者增加（转为观战后 1 人）。
    expect(find.text('观战 1'), findsOneWidget);
    expect(find.text('转为决斗者'), findsOneWidget);

    // 观战列表只渲染实际人数：1 人只有 1 条，不再补空位。
    await tester.tap(find.byKey(const ValueKey('waiting-spectators-entry')));
    await tester.pumpAndSettle();
    expect(find.text('观战位 1'), findsOneWidget);
    expect(find.text('观战位 2'), findsNothing);
    expect(find.text('空位'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('844×390 设计画布下不溢出', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('房间#'), findsWidgets);
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
    expect(find.text('双方已连接 · 出拳决定先后攻'), findsNothing);
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

  // ───────────────── 观战视角：不能有「我方 / 对方 / 你」 ─────────────────
  //
  // 观战者既没有出拳/选攻按钮，也没有任何立场；沿用决斗者的文案会说出
  // 「你胜出」「等待对方…」这种根本不可能发生的话。

  testWidgets('05b 观战：隐藏出拳按钮，称谓改为号位', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(stage: const RoomSelectingHand(), selfType: PlayerType.observer),
    );
    await tester.pump();

    expect(find.text('猜拳 · 决定先后攻'), findsOneWidget);
    // 观战者无按钮可点（点了会向服务端发非法动作）。
    expect(find.text('石头'), findsNothing);
    expect(find.text('剪刀'), findsNothing);
    expect(find.text('布'), findsNothing);
    // 「你 / 对手」不成立，改用号位。
    expect(find.text('你'), findsNothing);
    expect(find.text('对手'), findsNothing);
    expect(find.text('1 号位'), findsOneWidget);
    expect(find.text('2 号位'), findsOneWidget);
    // 交互动作文案也要消失。
    expect(find.textContaining('已出拳'), findsNothing);
    expect(find.textContaining('等待对方'), findsNothing);
    expect(find.text('双方出拳中 · 倒计时结束后自动判定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05b2 观战：出拳结果不判「你胜出」', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        stage: const RoomHandResult(myHand: 1, opponentHand: 3),
        selfType: PlayerType.observer,
      ),
    );
    await tester.pump();

    expect(find.text('出拳结果'), findsOneWidget);
    expect(find.text('1 号位胜出'), findsOneWidget);
    expect(find.text('你胜出'), findsNothing);
    expect(find.text('对手胜出'), findsNothing);
    expect(find.text('1 号位 · 剪刀'), findsOneWidget);
    expect(find.text('2 号位 · 布'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05c 观战：隐藏先后攻按钮，文案中性', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(stage: const RoomSelectingTurn(), selfType: PlayerType.observer),
    );
    await tester.pump();

    expect(find.text('先攻'), findsNothing);
    expect(find.text('后攻'), findsNothing);
    expect(find.text('猜拳胜出 · 你先选'), findsNothing);
    // 只断言「先攻/后攻」的立场措辞；左侧 PlayerCard 的
    // 「你正在观战 · 点「转为决斗者」回到席位」指观战者本人，是正确文案。
    expect(find.textContaining('你先'), findsNothing);
    expect(find.textContaining('你为'), findsNothing);
    expect(find.textContaining('对手'), findsNothing);
    expect(find.text('等待胜出方选择先后攻'), findsOneWidget);
    expect(find.text('观战中 · 等待胜出方决定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('观战：猜拳/选攻页不显示阶段进度条', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 进度条暗示「到点会自动出拳 / 自动选攻」，观战者没有这些动作。
    await tester.pumpWidget(
      subject(stage: const RoomSelectingHand(), selfType: PlayerType.observer),
    );
    await tester.pump();
    expect(find.byType(WaitingPhaseStatusBar), findsNothing);

    await tester.pumpWidget(
      subject(stage: const RoomSelectingTurn(), selfType: PlayerType.observer),
    );
    await tester.pump();
    expect(find.byType(WaitingPhaseStatusBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('决斗者：猜拳页仍保留阶段进度条', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(stage: const RoomSelectingHand()));
    await tester.pump();
    expect(find.byType(WaitingPhaseStatusBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('05c 决斗者：仍然看得到按钮与「你先选」', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(stage: const RoomSelectingTurn()));
    await tester.pump();

    // 防止把观战分支做成「所有人都看不到按钮」。
    expect(find.text('猜拳胜出 · 你先选'), findsOneWidget);
    expect(find.text('先攻'), findsOneWidget);
    expect(find.text('后攻'), findsOneWidget);
    expect(find.text('等待胜出方选择先后攻'), findsNothing);
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

  testWidgets('2v2：队友展示在我方卡，对手卡只放对方队伍', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
          PlayerInfo(name: '城之内', pos: 2, ready: false),
        ],
      ),
    );
    await tester.pump();

    // tag 分队：座位 0/2 同队，座位 2 的队友必须出现在左侧我方卡。
    final ally = find.byKey(const ValueKey('waiting-ally-card'));
    final enemy = find.byKey(const ValueKey('waiting-enemy-card'));
    expect(
      find.descendant(of: ally, matching: find.text('城之内')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.text('剑斗士 K')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.text('城之内')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2：从 3 号位入局时我方卡以自己为首位并带队友', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
        selfType: PlayerType.player3,
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
          PlayerInfo(name: '城之内', pos: 2, ready: false),
        ],
      ),
    );
    await tester.pump();

    final ally = find.byKey(const ValueKey('waiting-ally-card'));
    expect(
      find.descendant(of: ally, matching: find.text('城之内')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: ally, matching: find.text('海马濑人')),
      findsOneWidget,
    );
    // 自己的卡组区跟随自己，队友行不喧宾夺主。
    expect(find.text('更换'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2 观战：左右两列分别显示两支队伍', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
        selfType: PlayerType.observer,
        observerCount: 1,
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
          PlayerInfo(name: '城之内', pos: 2, ready: true),
          PlayerInfo(name: '偷摸灵兽幽灵', pos: 3, ready: false),
        ],
      ),
    );
    await tester.pump();

    final ally = find.byKey(const ValueKey('waiting-ally-card'));
    final enemy = find.byKey(const ValueKey('waiting-enemy-card'));
    expect(
      find.descendant(of: ally, matching: find.text('城之内')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.text('偷摸灵兽幽灵')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.text('城之内')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2：未加入的座位展示空位等待', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
        ],
      ),
    );
    await tester.pump();

    final ally = find.byKey(const ValueKey('waiting-ally-card'));
    final enemy = find.byKey(const ValueKey('waiting-enemy-card'));
    // 我方少一个队友：显示队友空位。
    expect(
      find.descendant(of: ally, matching: find.textContaining('等待队友加入')),
      findsOneWidget,
    );
    // 对手两名都未加入：两个对手空位。
    expect(
      find.descendant(of: enemy, matching: find.textContaining('等待对手 1加入')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.textContaining('等待对手 2加入')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2：已加入一名对手时只补剩余空位', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
        players: const [
          PlayerInfo(name: '海马濑人', pos: 0, ready: true, host: true),
          PlayerInfo(name: '剑斗士 K', pos: 1, ready: true),
        ],
      ),
    );
    await tester.pump();

    final enemy = find.byKey(const ValueKey('waiting-enemy-card'));
    expect(
      find.descendant(of: enemy, matching: find.text('剑斗士 K')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: enemy, matching: find.textContaining('等待对手 2加入')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('2v2 小窗口：选手卡内容缩放不溢出', (tester) async {
    tester.view.physicalSize = const Size(1158, 535);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      subject(
        mode: RoomMode.tag,
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

    // 新选手卡不再内嵌邀码文案，邀请入口统一在顶栏图标。
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

  testWidgets('人机房间：底栏「呼叫 AI」发送 /ai', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sent = <String>[];
    await tester.pumpWidget(subject(isAiRoom: true, sentChat: sent));
    await tester.pump();

    final callAi = find.byKey(const ValueKey('waiting-call-ai'));
    expect(callAi, findsOneWidget);
    // 呼叫 AI 在「转为观战」左边。
    expect(
      tester.getCenter(callAi).dx,
      lessThan(
        tester
            .getCenter(find.byKey(const ValueKey('waiting-become-observer')))
            .dx,
      ),
    );

    await tester.tap(callAi);
    await tester.pump();
    expect(sent, ['/ai']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非人机房间：不显示「呼叫 AI」', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(find.byKey(const ValueKey('waiting-call-ai')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
