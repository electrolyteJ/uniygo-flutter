/// 房间连接生命周期钩子（roomConnectionLifetime）回归测试。
///
/// 背景：Riverpod 3 禁止在 onDispose 等生命周期回调中使用 ref
/// （read/watch/listen 触发 _debugCallbackStack 断言）。该钩子曾在
/// onDispose 里 ref.read(duelServiceProvider)，离开房间销毁 scope 时
/// 直接抛断言、disconnect 未执行，服务器侧 socket 随后 reset。
library;

import 'dart:typed_data';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingDuelService implements IDuelService {
  int disconnectCount = 0;

  @override
  Stream<RoomStage> get onRoomStageChange => const Stream.empty();

  @override
  Stream<YgoStocMsg> get onServerMessage => const Stream.empty();

  @override
  Stream<YgoStocMsg> get onChatServerMessage => const Stream.empty();

  @override
  Stream<DuelPhase> get onDuelPhaseMessage => const Stream.empty();

  @override
  ConnectionState get connectionState => ConnectionConnected();

  @override
  Future<void> connect(Uri address) async {}

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  void setPlayerName(String name) {}

  @override
  void enterRoom(String password) {}

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck,
      [Uint8List? sideDeck]) {}

  @override
  void ready() {}

  @override
  void unready() {}

  @override
  void startDuel() {}

  @override
  void kickPlayer(int pos) {}

  @override
  void becomeObserver() {}

  @override
  void becomeDuelist() {}

  @override
  void chooseHand(HandType hand) {}

  @override
  void chooseTurnOrder(bool goFirst) {}

  @override
  void playGameResponse(CtosGameMsgResponse response) {}

  @override
  void surrender() {}

  @override
  void confirmTime() {}

  @override
  void sendChat(String message) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('房间 scope 销毁时兜底断开连接，且不在生命周期回调内使用 ref', () {
    final service = _RecordingDuelService();
    // 对齐 DuelRoomPage 的容器结构：服务在应用级父容器，
    // 连接生命周期钩子在房间级子容器 override 后随 scope 销毁。
    final appContainer = ProviderContainer(
      overrides: [duelServiceProvider.overrideWithValue(service)],
    );
    final roomContainer = ProviderContainer(
      parent: appContainer,
      overrides: [
        roomConnectionLifetimeProvider.overrideWith(roomConnectionLifetime),
      ],
    );
    addTearDown(appContainer.dispose);

    // 对齐房间页：build 中 watch 使钩子在房间 scope 内实例化。
    roomContainer.read(roomConnectionLifetimeProvider);

    // 离开房间销毁 scope：修复前此处 onDispose 内 ref.read 抛
    // 「Cannot use Ref or modify other providers inside life-cycles」
    // 断言，disconnect 不会执行。
    roomContainer.dispose();

    expect(service.disconnectCount, 1, reason: 'scope 销毁应兜底断开 socket');
  });
}
