/// 纯逻辑单元测试（模型 / 配置 / 仓库 / 服务），无需 App 启动。
///
/// 放在 integration_test 下以复用同一套覆盖率采集流程；
/// 这些用例确定、无网络、无 UI，是覆盖率的主要来源之一。
library;

import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/models/created_room_record.dart';
import 'package:deck_editor1/deck_editor1.dart';
import 'package:uniygopro/models/mercury233_room_spec.dart';
import 'package:uniygopro/models/mercury233_room_string_codec.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/pages/create_room/room_history_store.dart';
import 'package:uniygopro/pages/side/side_store.dart';
import 'package:ygo_data/card_info.dart' as pkg;
import 'package:ygo_data/lf_table.dart';

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

  group('Mercury233RoomStringCodec', () {
    test('结构化构建（默认 + 非默认）', () {
      const spec = Mercury233RoomSpec(roomName: '测试房');
      final result = Mercury233RoomStringCodec.build(spec);
      expect(result.error, isNull);
      expect(result.value, 'MR5#测试房');

      final custom = Mercury233RoomStringCodec.build(
        const Mercury233RoomSpec(
          roomName: '房',
          duelRule: DuelRule.mr4,
          cardPoolMode: Mercury233CardPoolMode.tcgAndOcg,
          startLp: 4000,
          noCheckDeck: true,
        ),
      );
      expect(custom.error, isNull);
      expect(custom.value, 'MR4,OT,LP4000,NC#房');
    });

    test('手动房间串与校验', () {
      final manual = Mercury233RoomStringCodec.build(
        const Mercury233RoomSpec(manualRoomStringEnabled: true, manualRoomString: 'M#abc'),
      );
      expect(manual.value, 'M#abc');
      expect(manual.error, isNull);

      final blank = Mercury233RoomStringCodec.build(
        const Mercury233RoomSpec(manualRoomStringEnabled: true, manualRoomString: '  '),
      );
      expect(blank.error, '房间串不能为空');

      final tooLong = Mercury233RoomStringCodec.build(
        const Mercury233RoomSpec(roomName: '12345678901234567890123'),
      );
      expect(tooLong.error, isNotNull);
    });
  });

  group('Mercury233RoomSpec', () {
    test('toRoomOptions 映射 cardPoolMode', () {
      const spec = Mercury233RoomSpec(
        mode: RoomMode.match,
        cardPoolMode: Mercury233CardPoolMode.noUnique,
        noCheckDeck: true,
      );
      final options = spec.toRoomOptions();
      expect(options.mode, RoomMode.match);
      expect(options.rule, 4);
      expect(options.noCheckDeck, isTrue);
    });

    test('toJson/fromJson 往返', () {
      const spec = Mercury233RoomSpec(
        roomName: 'X',
        duelRule: DuelRule.mr3,
        cardPoolMode: Mercury233CardPoolMode.tcgOnly,
        startLp: 1000,
        startHand: 3,
        timeLimit: 240,
      );
      final restored = Mercury233RoomSpec.fromJson(spec.toJson());
      expect(restored.roomName, 'X');
      expect(restored.duelRule, DuelRule.mr3);
      expect(restored.cardPoolMode, Mercury233CardPoolMode.tcgOnly);
      expect(restored.startLp, 1000);
      expect(restored.startHand, 3);
      expect(restored.timeLimit, 240);
    });

    test('buildMercury233BanlistOptions', () {
      expect(buildMercury233BanlistOptions(const []).length, 2);
      final options = buildMercury233BanlistOptions([
        const LfTable(name: '2024.04', date: '2024-04-01'),
        const LfTable(name: '', date: ''),
      ]);
      expect(options.length, 3); // 2 张表 + 无禁限
      expect(options[0].label, '2024.04');
      expect(options[1].label, '禁限卡表 2');
    });
  });

  group('CreatedRoomRecord', () {
    CreatedRoomRecord standard() => CreatedRoomRecord(
          env: DuelEnvironment.mycard,
          roomName: '标准房',
          password: 'pw',
          options: const RoomOptions(mode: RoomMode.match, startLp: 8000),
        );

    CreatedRoomRecord mercury() => CreatedRoomRecord(
          env: DuelEnvironment.mercury233,
          roomName: '',
          mercurySpec: const Mercury233RoomSpec(roomName: '233房'),
        );

    test('title/summary 分支', () {
      expect(standard().title, '标准房');
      expect(mercury().title, '233房');
      expect(
        CreatedRoomRecord(env: DuelEnvironment.koishi, roomName: '').title,
        '未命名房间',
      );
      expect(standard().summary, contains('Match'));
      expect(mercury().summary, contains('单局'));
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
      expect(gameServers.length, 5);
      expect(DuelEnvironment.mycard.canCreate, isTrue);
      expect(DuelEnvironment.koishi.canCreate, isFalse);
      expect(DuelEnvironment.ai.isAi, isTrue);
      expect(DuelEnvironment.puzzle.isPuzzle, isTrue);
      expect(DuelEnvironment.mycard.useEncodedPassword, isTrue);
      expect(DuelEnvironment.mercury233.usesRoomStringDsl, isTrue);
      expect(
        gameServers.first.wsUrl,
        startsWith('wss://'),
      );
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
      final store = MatchStore()..selectPuzzle(gameServers.first, 'puzzle/xx/yy.lua');
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
      store.setMatchResult('1.2.3.4', 9999, 'secret');
      expect(store.isSearching, isFalse);
      expect(store.serverAddress, '1.2.3.4');
      expect(store.serverPort, 9999);
      store.reset();
      expect(store.isSearching, isFalse);
      expect(store.serverAddress, isNull);
      expect(store.username, 'Guest');
      expect(store.environment, DuelEnvironment.koishi);
    });

    test('setEnvironment / stopSearching', () {
      final store = MatchStore();
      store.setEnvironment(DuelEnvironment.mercury233);
      expect(store.environment, DuelEnvironment.mercury233);
      store.stopSearching();
      expect(store.isSearching, isFalse);
    });
  });

  group('SideStore', () {
    test('stage 流转', () {
      final store = SideStore();
      expect(store.stage, SideStage.none);
      store.enterSide();
      expect(store.stage, SideStage.sideChanging);
      store.waiting();
      expect(store.stage, SideStage.waiting);
      store.startDuel();
      expect(store.stage, SideStage.duelStart);
      store.reset();
      expect(store.stage, SideStage.none);
    });
  });

  group('DeckEditorSaveResult', () {
    test('isCompliant', () {
      expect(const DeckEditorSaveResult(saved: true).isCompliant, isTrue);
      expect(
        const DeckEditorSaveResult(saved: true, validationErrors: [])
            .isCompliant,
        isTrue,
      );
      expect(
        const DeckEditorSaveResult(saved: true, validationErrors: ['x'])
            .isCompliant,
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
        mercurySpec: const Mercury233RoomSpec(roomName: '历史房'),
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
