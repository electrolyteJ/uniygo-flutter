/// 纯逻辑单元测试（模型 / 配置 / 仓库 / 服务），无需 App 启动。
///
/// 放在 integration_test 下以复用同一套覆盖率采集流程；
/// 这些用例确定、无网络、无 UI，是覆盖率的主要来源之一。
library;

import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/create_room/free/created_room_record.dart';
import 'package:deck_editor1/deck_editor1.dart';
import 'package:uniygopro/create_room/match_store.dart';
import 'package:uniygopro/create_room/free/room_history_store.dart';
import 'package:resource_data/card_info.dart' as pkg;

pkg.CardInfo _card(int code, {String name = '', int type = 0x1}) =>
    pkg.CardInfo(code: code, type: type, name: name);

void main() {
  group('CardFilter', () {
    test('默认筛选判定与 copyWith 清除', () {
      const filter = CardFilter();
      expect(filter.isDefault, isTrue);
      const withEnv = CardFilter(env: 1);
      expect(withEnv.isDefault, isFalse);
      final cleared = withEnv.copyWith(clearEnv: true);
      expect(cleared.env, isNull);
      expect(cleared.isDefault, isTrue);
      final overridden = withEnv.copyWith(attribute: 0x1);
      expect(overridden.attribute, 0x1);
      expect(overridden.env, 1);
    });
  });

  group('DeckMeta', () {
    test('toJson/fromJson 往返', () {
      final meta = DeckMeta(
        deckName: '卡组A',
        mainCount: 40,
        extraCount: 3,
        sideCount: 5,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1234567),
        isBuiltin: true,
      );
      final restored = DeckMeta.fromJson(meta.toJson());
      expect(restored.deckName, '卡组A');
      expect(restored.mainCount, 40);
      expect(restored.extraCount, 3);
      expect(restored.sideCount, 5);
      expect(restored.isBuiltin, isTrue);
      expect(
        restored.updatedAt?.millisecondsSinceEpoch,
        meta.updatedAt?.millisecondsSinceEpoch,
      );
    });

    test('fromJson 缺省字段', () {
      final meta = DeckMeta.fromJson({'deckName': 'B'});
      expect(meta.mainCount, 0);
      expect(meta.isBuiltin, isFalse);
      expect(meta.updatedAt, isNull);
    });

    test('copyWith', () {
      const meta = DeckMeta(deckName: 'A', mainCount: 1);
      final next = meta.copyWith(mainCount: 60);
      expect(next.mainCount, 60);
      expect(next.deckName, 'A');
    });
  });

  group('EditingDeck', () {
    test('数量统计 / clear / reset / toMeta', () {
      final deck = EditingDeck(
        deckName: 'D',
        main: [_card(1), _card(2)],
        extra: [_card(3)],
        side: [_card(4), _card(5), _card(6)],
      );
      expect(deck.mainCount, 2);
      expect(deck.extraCount, 1);
      expect(deck.sideCount, 3);
      expect(deck.totalCount, 6);
      expect(deck.toMeta().mainCount, 2);

      deck.clear();
      expect(deck.totalCount, 0);
      expect(deck.isDirty, isTrue);

      deck.reset('R', [_card(7)], [], []);
      expect(deck.deckName, 'R');
      expect(deck.mainCount, 1);
      expect(deck.isDirty, isFalse);
    });
  });


  group('CreatedRoomRecord', () {
    CreatedRoomRecord standard() => CreatedRoomRecord(
      env: DuelEnvironment.mycard,
      roomName: '标准房',
      password: 'pw',
      options: const RoomOptions(mode: RoomMode.match, startLp: 8000),
    );

    // 233 记录：房间串即进房凭证，整串存 password；options 与 roomName 同级。
    CreatedRoomRecord mercury() => CreatedRoomRecord(
      env: DuelEnvironment.mercury233,
      roomName: 'BO3-123456',
      password: 'M,MR5#BO3-123456',
      options: const RoomOptions(mode: RoomMode.single),
    );

    test('title/summary 分支', () {
      expect(standard().title, '标准房');
      expect(mercury().title, 'BO3-123456');
      expect(
        CreatedRoomRecord(env: DuelEnvironment.koishi, roomName: '').title,
        '未命名房间',
      );
      expect(
        CreatedRoomRecord(
          env: DuelEnvironment.koishi,
          roomName: '',
          password: 'abc',
        ).title,
        'abc',
      );
      expect(standard().summary, contains('Match'));
      expect(mercury().summary, contains('单局'));
      // 没有 options 时回退到环境名
      expect(
        CreatedRoomRecord(env: DuelEnvironment.koishi, roomName: 'x').summary,
        DuelEnvironment.koishi.displayName,
      );
    });

    test('旧 JSON（带 mercurySpec）仍可读，多余字段被忽略', () {
      // 旧版本把 233 规则放在 mercurySpec 里、password 留空。
      final legacy = {
        'env': 'mercury233',
        'roomName': '旧房',
        'password': '',
        'mercurySpec': {'roomName': '旧房', 'mode': 0, 'startLp': 8000},
        'createdAt': 1700000000000,
      };
      final restored = CreatedRoomRecord.fromJson(legacy);
      expect(restored.roomName, '旧房');
      expect(restored.title, '旧房');
      expect(restored.options, isNull);
      expect(restored.createdAt.millisecondsSinceEpoch, 1700000000000);
      // 再写回时只剩新格式
      expect(restored.toJson().containsKey('mercurySpec'), isFalse);
    });

    test('toJson/fromJson 往返 + identity 稳定', () {
      final record = standard();
      final restored = CreatedRoomRecord.fromJson(record.toJson());
      expect(restored.title, record.title);
      expect(restored.identity, record.identity);
      // identity 不含 createdAt
      final touched = record.touch();
      expect(touched.identity, record.identity);
    });
  });

  group('servers 配置', () {
    test('gameServers 与 DuelEnvironment getters', () {
      expect(gameServers.length, 8);
      expect(DuelEnvironment.mycard.canCreate, isTrue);
      expect(DuelEnvironment.koishi.canCreate, isFalse);
      expect(DuelEnvironment.ai.isAi, isTrue);
      expect(DuelEnvironment.puzzle.isPuzzle, isTrue);
      expect(DuelEnvironment.mycard.useEncodedPassword, isTrue);
      expect(DuelEnvironment.mercury233.usesRoomStringDsl, isTrue);
      expect(gameServers.first.wsUrl, startsWith('wss://'));
    });
  });

  group('MatchStore', () {
    test('selectServer / configureCreatedRoom / toDuelRoomParams', () {
      final store = MatchStore();
      store.setUsername('小明');
      store.configureCreatedRoom(
        roomOptions: const RoomOptions(mode: RoomMode.single),
        roomName: 'AI 人机对战',
      );
      store.selectServer(
        gameServers.firstWhere((s) => s.type == ServerType.aiRoom),
        DuelEnvironment.ai,
        RoomPassword.encodeJoin(),
      );
      final params = store.toDuelRoomParams();
      expect(params['username'], '小明');
      expect(params['roomName'], 'AI 人机对战');
      expect(store.uri?.scheme, 'ai');
    });

    test('uri：puzzle / 普通环境', () {
      final store = MatchStore()
        ..selectPuzzle(gameServers.first, 'puzzle/xx/yy.lua');
      expect(store.uri?.scheme, 'puzzle');
      expect(store.environment, DuelEnvironment.puzzle);

      store.selectServer(
        gameServers.firstWhere((s) => s.type == ServerType.freeRoom),
        DuelEnvironment.koishi,
        'pw',
      );
      expect(store.uri?.host, 'koishi.momobako.com');
      expect(store.uri?.port, 7211);
    });

    test('searching / match result / reset', () {
      final store = MatchStore();
      store.startSearching('athletic');
      expect(store.isSearching, isTrue);
      expect(store.arena, 'athletic');
      expect(store.isSearching, isFalse);
      expect(store.serverAddress, '1.2.3.4');
      expect(store.serverPort, 9999);
      store.reset();
      expect(store.isSearching, isFalse);
      expect(store.serverAddress, isNull);
      expect(store.username, 'Guest');
      expect(store.environment, DuelEnvironment.koishi);
    });


  });

  group('DeckEditorSaveResult', () {
    test('isCompliant', () {
      expect(const DeckEditorSaveResult(saved: true).isCompliant, isTrue);
      expect(
        const DeckEditorSaveResult(
          saved: true,
          validationErrors: [],
        ).isCompliant,
        isTrue,
      );
      expect(
        const DeckEditorSaveResult(
          saved: true,
          validationErrors: ['x'],
        ).isCompliant,
        isFalse,
      );
    });
  });

  group('RoomHistoryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('add/load/remove', () async {
      final record = CreatedRoomRecord(
        env: DuelEnvironment.mercury233,
        roomName: '历史房',
        password: 'MR5#历史房',
        options: const RoomOptions(mode: RoomMode.single),
      );
      await RoomHistoryStore.add(record);
      var loaded = await RoomHistoryStore.load();
      expect(loaded.length, 1);
      expect(loaded.first.title, '历史房');

      await RoomHistoryStore.add(record); // 同 identity 去重置顶
      loaded = await RoomHistoryStore.load();
      expect(loaded.length, 1);

      await RoomHistoryStore.remove(record);
      loaded = await RoomHistoryStore.load();
      expect(loaded, isEmpty);
    });
  });
}
