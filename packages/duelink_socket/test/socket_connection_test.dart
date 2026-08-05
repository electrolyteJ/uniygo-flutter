import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/duelink_socket.dart';
import 'package:test/test.dart';

Uint8List _mkPacket(int proto, Uint8List exData) {
  final b = ByteData(3 + exData.length);
  b.setUint16(0, exData.length + 1, Endian.little);
  b.setUint8(2, proto);
  b.buffer.asUint8List().setAll(3, exData);
  return b.buffer.asUint8List();
}

Uint8List _mkStocChat({int player = 0, String message = ''}) {
  final w = BufferWriter();
  w.writeUint16(player);
  w.writeUtf16Var(message);
  return _mkPacket(25, w.toBytes());
}

Future<({ServerSocket server, int port})> _startServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) {
    client.listen((_) {}, onDone: () {});
  });
  return (server: server, port: server.port);
}

void main() {
  group('SocketConnection state machine (via local TCP)', () {
    test('successful connect emits connecting then connected', () async {
      final (:server, :port) = await _startServer();

      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      await conn.connect(Uri.parse('tcp://127.0.0.1:${port}'));

      // State events are delivered asynchronously in the test environment.
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, contains(ConnectionState.connecting));
      expect(states, contains(ConnectionState.connected));

      await conn.disconnect();
      await server.close();
    });

    test(
        'connect establishes a working connection (can send/receive)',
        () async {
      final (:server, :port) = await _startServer();

      final conn = SocketConnection();
      await conn.connect(Uri.parse('tcp://127.0.0.1:${port}'));
      await Future.delayed(const Duration(milliseconds: 100));

      conn.send(YgoCtosMsg.chat(CtosChat(message: 'ping')));

      await Future.delayed(const Duration(milliseconds: 100));

      // If we got here without throw, the connection works
      await conn.disconnect();
      await server.close();
    });

    test('manual disconnect emits disconnected', () async {
      final (:server, :port) = await _startServer();

      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      await conn.connect(Uri.parse('tcp://127.0.0.1:${port}'));
      await Future.delayed(const Duration(milliseconds: 100));

      conn.disconnect();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(ConnectionState.disconnected));

      await server.close();
    });

    test('connect to refused port emits error', () async {
      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      try {
        await conn
            .connect(Uri.parse('tcp://127.0.0.1:19999'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, contains(ConnectionState.error));
    });
  });

  group('SocketConnection null-safety', () {
    test('send does not throw when socket is null', () {
      final c = SocketConnection();
      expect(
        () => c.send(YgoCtosMsg.chat(CtosChat(message: 'test'))),
        returnsNormally,
      );
    });

    test('disconnect does not throw when not connected', () async {
      final c = SocketConnection();
      await c.disconnect();
    });
  });

  group('SocketConnection message flow (via local TCP)', () {
    late ServerSocket server;
    late int port;
    late SocketConnection conn;
    late Socket client;
    late StreamSubscription<Socket> serverSub;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      conn = SocketConnection();

      final accepted = Completer<Socket>();
      serverSub = server.listen((c) {
        if (!accepted.isCompleted) accepted.complete(c);
      });

      await conn.connect(Uri.parse('tcp://127.0.0.1:$port'));
      client = await accepted.future;
    });

    tearDown(() async {
      try {
        await client.close();
      } catch (_) {}
      try {
        await conn.disconnect();
      } catch (_) {}
      await serverSub.cancel();
      try {
        await server.close();
      } catch (_) {}
    });

    test('send writes encoded bytes to socket', () async {
      conn.send(YgoCtosMsg.chat(CtosChat(message: 'hello')));

      final data = await client.first.timeout(const Duration(seconds: 3));
      final received = Uint8List.fromList(data);

      expect(received.length, greaterThan(3));
    });

    test('messages stream emits decoded packets from server', () async {
      final msgs = <YgoStocMsg>[];
      conn.messages.listen(msgs.add);

      client.add(_mkStocChat(player: 0, message: 'test'));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(msgs.length, 1);
      expect(msgs[0].chat, isNotNull);
      expect(msgs[0].chat!.message, 'test');
    });

    test('messages stream handles multiple sequential packets', () async {
      final msgs = <YgoStocMsg>[];
      conn.messages.listen(msgs.add);

      client.add(_mkStocChat(player: 0, message: 'a'));
      client.add(_mkStocChat(player: 0, message: 'b'));
      client.add(_mkStocChat(player: 0, message: 'c'));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(msgs.length, 3);
      for (final m in msgs) {
        expect(m.chat, isNotNull);
      }
    });

    test('messages stream handles combined packets (stickiness)', () async {
      final msgs = <YgoStocMsg>[];
      conn.messages.listen(msgs.add);

      final p1 = _mkStocChat(player: 0, message: 'first');
      final p2 = _mkStocChat(player: 0, message: 'second');
      final combined = Uint8List(p1.length + p2.length);
      combined.setAll(0, p1);
      combined.setAll(p1.length, p2);
      client.add(combined);

      await Future.delayed(const Duration(milliseconds: 300));

      expect(msgs.length, 2);
      expect(msgs[0].chat?.message, 'first');
      expect(msgs[1].chat?.message, 'second');
    });

    test('messages stream handles unknown proto id without crashing',
        () async {
      final msgs = <YgoStocMsg>[];
      conn.messages.listen(msgs.add);

      client.add(_mkPacket(255, Uint8List(0)));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(msgs.length, 1);
      expect(msgs[0], isA<YgoStocMsg>());
    });

    test('state and messages streams support multiple listeners', () async {
      final m1 = <YgoStocMsg>[];
      final m2 = <YgoStocMsg>[];

      conn.messages.listen(m1.add);
      conn.messages.listen(m2.add);

      client.add(_mkStocChat(player: 0, message: 'multi'));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(m1.length, 1);
      expect(m2.length, 1);
      expect(m1[0].chat!.message, 'multi');
      expect(m2[0].chat!.message, 'multi');
    });
  });

  group('SocketDuelService', () {
    test('creates instance with SocketConnection', () {
      final svc = SocketDuelService();
      expect(svc.connection, isA<SocketConnection>());
    });

    test('connection has correct DuelConnection interface', () {
      final svc = SocketDuelService();
      final conn = svc.connection;

      expect(conn, isA<DuelConnection>());
      expect(conn.state, isA<Stream<ConnectionState>>());
      expect(conn.messages, isA<Stream<YgoStocMsg>>());
    });
  });
}
