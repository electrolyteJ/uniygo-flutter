import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/pages/create_room/room_history.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreatedRoomRecord', () {
    test('标准环境记录 JSON 往返', () {
      final record = CreatedRoomRecord(
        env: DuelEnvironment.mycard,
        roomName: '测试房',
        password: 'abc123',
        options: const RoomOptions(
          rule: 1,
          startLp: 4000,
          mode: RoomMode.single,
          noCheckDeck: true,
          timeLimit: 300,
        ),
      );

      final restored = CreatedRoomRecord.fromJson(record.toJson());

      expect(restored.env, DuelEnvironment.mycard);
      expect(restored.roomName, '测试房');
      expect(restored.password, 'abc123');
      expect(restored.options!.rule, 1);
      expect(restored.options!.startLp, 4000);
      expect(restored.options!.mode, RoomMode.single);
      expect(restored.options!.noCheckDeck, isTrue);
      expect(restored.options!.timeLimit, 300);
      expect(restored.identity, record.identity);
      expect(restored.title, '测试房');
      expect(restored.summary, '单局 · LP4000 · 手牌5');
    });

    test('mercury233 记录 JSON 往返', () {
      final record = CreatedRoomRecord(
        env: DuelEnvironment.mercury233,
        roomName: '233房',
        mercurySpec: const Mercury233RoomSpec(
          roomName: '233房',
          startLp: 4000,
          cardPoolMode: Mercury233CardPoolMode.tcgOnly,
          banlist: Mercury233BanlistOption(
              label: '无禁限', token: 'NF', lfTableHash: 0),
          noShuffleDeck: true,
        ),
      );

      final restored = CreatedRoomRecord.fromJson(record.toJson());

      expect(restored.env, DuelEnvironment.mercury233);
      expect(restored.mercurySpec!.roomName, '233房');
      expect(restored.mercurySpec!.startLp, 4000);
      expect(restored.mercurySpec!.cardPoolMode,
          Mercury233CardPoolMode.tcgOnly);
      expect(restored.mercurySpec!.banlist.token, 'NF');
      expect(restored.mercurySpec!.noShuffleDeck, isTrue);
      expect(restored.identity, record.identity);
      expect(restored.title, '233房');
    });
  });

  group('RoomHistoryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    CreatedRoomRecord standard(String name, {String pw = 'p'}) =>
        CreatedRoomRecord(
          env: DuelEnvironment.mycard,
          roomName: name,
          password: pw,
          options: const RoomOptions(),
        );

    test('add 后按创建时间倒序 load', () async {
      final older = standard('旧');
      await RoomHistoryStore.add(older);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await RoomHistoryStore.add(standard('新'));

      final records = await RoomHistoryStore.load();
      expect(records.length, 2);
      expect(records.first.roomName, '新');
      expect(records.last.roomName, '旧');
    });

    test('相同参数的记录去重置顶', () async {
      final a = standard('A');
      await RoomHistoryStore.add(a);
      await RoomHistoryStore.add(standard('B'));
      await RoomHistoryStore.add(a.touch());

      final records = await RoomHistoryStore.load();
      expect(records.length, 2);
      expect(records.first.roomName, 'A');
    });

    test('remove 删除指定记录', () async {
      final a = standard('A');
      await RoomHistoryStore.add(a);
      await RoomHistoryStore.add(standard('B'));
      await RoomHistoryStore.remove(a);

      final records = await RoomHistoryStore.load();
      expect(records.length, 1);
      expect(records.single.roomName, 'B');
    });
  });
}
