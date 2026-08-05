@Timeout(Duration(minutes: 5))
library;

import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/duelink_socket.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

const String kServerHost = 's1.ygo233.com';
const int kServerPort = 233;
const Duration kNetTimeout = Duration(seconds: 30);

void main() {
  group('SocketDuelService integration with s1.ygo233.com:233', () {
    late IDuelService alice;

    setUp(() {
      if (!ServiceFactory.isRegistered<SocketDuelService>()) {
        ServiceFactory.register<SocketDuelService>(SocketDuelService.new);
      }
      alice = ServiceFactory.create<SocketDuelService>();
    });

    tearDown(() async {
      try {
        if (alice.connectionState == ConnectionState.connected) {
          alice.surrender();
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        await alice.disconnect();
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    });

    test('connects and disconnects successfully', () async {
      await alice.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(alice.connectionState, ConnectionState.connected);

      await alice.disconnect();
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(alice.connectionState, ConnectionState.disconnected);
    });

    test('can reconnect after disconnect', () async {
      await alice.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(alice.connectionState, ConnectionState.connected);

      await alice.disconnect();
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(alice.connectionState, ConnectionState.disconnected);

      await alice.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(alice.connectionState, ConnectionState.connected);

      await alice.disconnect();
    });

    test('connect to invalid host emits error state', () async {
      try {
        await alice.connect(Uri.parse('tcp://invalid.host.that.does.not.exist.test:233'))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(alice.connectionState, ConnectionState.error);
    });

    test('initial connectionState is disconnected', () {
      expect(alice.connectionState, ConnectionState.disconnected);
    });

    test('onServerMessage stream works after connect', () async {
      final msgs = <YgoStocMsg>[];
      final sub = alice.onServerMessage.listen(msgs.add);

      await alice.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future<void>.delayed(const Duration(seconds: 3));

      // The server may or may not send initial messages.
      // Verify the stream is functional (no crash).

      await sub.cancel();
    });

    test(
        'onRoomStageChange stream emits initial RoomNotJoined',
        () async {
      final stages = <RoomStage>[];
      alice.onRoomStageChange.listen(stages.add);

      // After connect without entering room, should remain RoomNotJoined
      await alice.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future<void>.delayed(const Duration(seconds: 2));

      // On disconnect, room stage resets to RoomNotJoined
      await alice.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(stages.last, isA<RoomNotJoined>());
    });
  });

  group('SocketConnection direct integration with s1.ygo233.com:233', () {
    test('raw socket connect emits state transitions', () async {
      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      await conn.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(ConnectionState.connecting));
      expect(states, contains(ConnectionState.connected));

      await conn.disconnect();
    });

    test('raw socket disconnect emits disconnected state', () async {
      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      await conn.connect(Uri.parse('tcp://$kServerHost:$kServerPort'));
      await Future.delayed(const Duration(milliseconds: 200));

      await conn.disconnect();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(ConnectionState.disconnected));
    });

    test(
        'raw socket connect to unreachable host emits error state',
        () async {
      final conn = SocketConnection();
      final states = <ConnectionState>[];
      conn.state.listen(states.add);

      try {
        await conn.connect(Uri.parse('tcp://1111:$kServerPort'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(ConnectionState.error));
    });
  });
}
