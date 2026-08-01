import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

class _FakeConnection implements DuelConnection {
  final _messages = StreamController<YgoStocMsg>.broadcast();
  final _states = StreamController<ConnectionState>.broadcast();

  @override
  Future<void> connect(String address, int port) async {
    _states.add(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _states.add(ConnectionState.disconnected);
  }

  @override
  Stream<YgoStocMsg> get messages => _messages.stream;

  @override
  void send(YgoCtosMsg data) {}

  @override
  Stream<ConnectionState> get state => _states.stream;

  void emit(YgoStocMsg msg) {
    _messages.add(msg);
  }
}

class _TestService extends BaseDuelService {
  _TestService(super.connection);
}

Future<T> waitUntil<T>(List<T> cache, Stream<T> stream, bool Function(T) match,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final hit = cache.where(match);
  if (hit.isNotEmpty) return hit.last;
  final completer = Completer<T>();
  late final StreamSubscription<T> sub;
  sub = stream.listen((event) {
    if (!completer.isCompleted && match(event)) {
      completer.complete(event);
      sub.cancel();
    }
  });
  return completer.future.timeout(timeout);
}

Future<_TestService> _buildService(List<RoomStage> states) async {
  final connection = _FakeConnection();
  final service = _TestService(connection);
  service.onRoomStageChange.listen(states.add);
  await service.connect('x', 0);
  connection.emit(YgoStocMsg.joinGame(const StocJoinGame()));
  connection.emit(YgoStocMsg.typeChange(
    const StocTypeChange(isHost: true, selfType: 0),
  ));
  connection.emit(YgoStocMsg.hsPlayerEnter(
    const StocHsPlayerEnter(name: 'A', pos: 0),
  ));
  await waitUntil(states, service.onRoomStageChange,
      (s) => s is RoomInLobby && s.players.length == 1);
  return service;
}

void main() {
  test('player change low-code READY marks player as ready in room state', () async {
    final states = <RoomStage>[];
    final service = await _buildService(states);
    final connection = service.connection as _FakeConnection;

    connection.emit(YgoStocMsg.hsPlayerChange(
      const StocHsPlayerChange(pos: 0, state: HS_PLAYER_STATE_READY),
    ));

    final state = await waitUntil(states, service.onRoomStageChange,
        (s) => s.players.isNotEmpty && s.players.first.ready);
    expect(state.players.first.ready, isTrue);
  });

  test('player change high-code READY marks player as ready in room state', () async {
    final states = <RoomStage>[];
    final service = await _buildService(states);
    final connection = service.connection as _FakeConnection;

    connection.emit(YgoStocMsg.hsPlayerChange(
      const StocHsPlayerChange(pos: 0, state: 9),
    ));

    final state = await waitUntil(states, service.onRoomStageChange,
        (s) => s.players.isNotEmpty && s.players.first.ready);
    expect(state.players.first.ready, isTrue);
  });
}
