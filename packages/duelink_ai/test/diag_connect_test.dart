import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_loader/service_loader.dart';

ffi.DynamicLibrary loadOcgCore() {
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('libocgcore.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('ocgcore.dll');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    final candidates = <String>[
      'macos/Frameworks/libocgcore.dylib',
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
    ];
    for (final path in candidates) {
      try {
        return ffi.DynamicLibrary.open(path);
      } catch (_) {}
    }
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

Future<T> waitUntil<T>(List<T> cache, Stream<T> stream, bool Function(T) match,
    {Duration timeout = const Duration(seconds: 15), String? hint}) async {
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

  final retry = cache.where(match);
  if (retry.isNotEmpty && !completer.isCompleted) {
    completer.complete(retry.last);
    await sub.cancel();
  }

  return completer.future.timeout(
    timeout,
    onTimeout: () => throw TimeoutException('wait ${hint ?? ''}'),
  );
}

Uint8List deckBytes(List<int> codes) {
  final data = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    data.setInt32(i * 4, codes[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List minimalDeck() => deckBytes(List<int>.filled(40, 15025844));

void main() {
  group('diag', () {
    late AiDuelService player;
    late List<RoomStage> states;
    late StreamSubscription<RoomStage> stateSub;

    setUp(() {
      if (!ServiceFactory.isRegistered<AiDuelService>()) {
        ServiceFactory.register<AiDuelService>(
          () => AiDuelService(connection: AiConnection(lib: loadOcgCore())),
        );
      }
      player = ServiceFactory.create<AiDuelService>();
      states = [];
      stateSub = player.onRoomStageChange.listen(states.add);
    });

    tearDown(() async {
      await stateSub.cancel();
      if (player.connectionState == ConnectionState.connected) {
        player.surrender();
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await player.disconnect();
    });

    test('connect & enter room', () async {
      const o = RoomOptions(mode: RoomMode.single, noCheckDeck: true,
          noShuffleDeck: true);
      final pw = RoomPassword.encodeCreate(options: o, roomId: 'ai_diag');

      await player.connect('ai', 0);
      expect(player.connectionState, isNot(ConnectionState.error),
          reason: 'connection should not be in error state');

      player.setPlayerName('Human');
      player.enterRoom(pw);

      final lobby = await waitUntil(
        states,
        player.onRoomStageChange,
        (state) => state is RoomInLobby &&
            state.players.length >= 2 &&
            state.players.any((player) => player.name == 'AI_Bob'),
        hint: 'lobby with AI Bob',
      ) as RoomInLobby;

      expect(lobby.players.length, greaterThanOrEqualTo(2),
          reason: 'AI Bob should auto-join');
    });

    test('submit deck & ready', () async {
      const o = RoomOptions(mode: RoomMode.single, noCheckDeck: true,
          noShuffleDeck: true);
      final pw = RoomPassword.encodeCreate(options: o, roomId: 'ai_diag2');

      await player.connect('ai', 0);
      player.setPlayerName('Human');
      player.enterRoom(pw);

      await waitUntil(
        states,
        player.onRoomStageChange,
        (state) => state is RoomInLobby &&
            state.players.length >= 2 &&
            state.players.any((player) => player.name == 'AI_Bob'),
        hint: 'lobby before ready',
      );

      // 提交一个最小卡组
      player.submitDeck(minimalDeck(), Uint8List(0));
      player.ready();

      final state = await waitUntil(
        states,
        player.onRoomStageChange,
        (state) => state is RoomSelectingHand,
        hint: 'hand selection after ready',
      );

      expect(state, isA<RoomSelectingHand>(),
          reason: 'should transition to hand selection after ready');
    });
  });
}
