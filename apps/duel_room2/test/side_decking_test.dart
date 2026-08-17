import 'dart:typed_data';

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duel_room2/pages/duel_room_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';

import 'fakes.dart';

/// 测试卡组构成：主 40（1000..1039）/ 额外 3 / 副 2。
final List<int> mainCodes = List.generate(40, (i) => 1000 + i);
const List<int> extraCodes = [2001, 2002, 2003];
const List<int> sideCodes = [3001, 3002];

DeckInfo _testDeck() => DeckInfo(
      deckName: '测试卡组',
      mainDeck: [for (final c in mainCodes) DeckCard(code: c)],
      extraDeck: [for (final c in extraCodes) DeckCard(code: c)],
      sideDeck: [for (final c in sideCodes) DeckCard(code: c)],
    );

/// little-endian int32 字节 → 卡码列表（BaseDuelService._bytesToInts 的镜像）。
List<int> bytesToInts(Uint8List bytes) {
  final bd = ByteData.view(
      bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
  return List.generate(bytes.length ~/ 4, (i) => bd.getInt32(i * 4, Endian.little));
}

void main() {
  late ProviderContainer container;
  late RecordingDuelService duelService;
  late FakeBanlistService banlistService;
  late FakeCardService cardService;

  DuelRoomNotifier notifier() => container.read(duelRoomProvider.notifier);
  DuelRoomState room() => container.read(duelRoomProvider);

  /// 冲刷微任务/定时器，等待异步状态写入落定。
  Future<void> settle() => pumpEventQueue();

  /// 初始化容器并进入 match 房间（player1、房主）。
  Future<void> enterMatchRoom({bool noCheckDeck = true}) async {
    final n = notifier();
    n.start();
    duelService.emitStage(RoomInLobby(
      selfType: PlayerType.player1,
      isHost: true,
      options: RoomOptions(mode: RoomMode.match, noCheckDeck: noCheckDeck),
    ));
    await settle();
    // build() 里的 loadDecks 是异步的，确保所选卡组已就位。
    expect(room().selectedDeckName, '测试卡组');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    duelService = RecordingDuelService();
    banlistService = FakeBanlistService();
    cardService = FakeCardService();
    final dataService = YgoDataService(
      cardService: cardService,
      deckService: FakeDeckService(decks: [_testDeck()]),
      banlistService: banlistService,
    );
    container = ProviderContainer(
      overrides: [
        duelServiceProvider.overrideWithValue(duelService),
        dataServiceProvider.overrideWithValue(dataService),
      ],
    );
    addTearDown(container.dispose);
  });

  group('准备时首次提交（含副卡组 + 构成记录）', () {
    test('toggleReady 上送 main/extra/side 字节并记录提交构成', () async {
      await enterMatchRoom();
      final err = await notifier().toggleReady();
      expect(err, isNull);
      expect(duelService.submittedDecks, hasLength(1));
      expect(duelService.readyCount, 1);

      final sub = duelService.submittedDecks.single;
      expect(bytesToInts(sub.main), mainCodes);
      expect(bytesToInts(sub.extra), extraCodes);
      expect(sub.side, isNotNull);
      expect(bytesToInts(sub.side!), sideCodes);

      final submitted = room().submittedDeck;
      expect(submitted, isNotNull);
      expect(submitted!.main, mainCodes);
      expect(submitted.extra, extraCodes);
      expect(submitted.side, sideCodes);
    });
  });

  group('RoomSideDecking 阶段进入', () {
    test('以已提交构成为基准初始化换备状态', () async {
      await enterMatchRoom();
      await notifier().toggleReady();

      duelService.emitStage(const RoomSideDecking());
      await settle();

      expect(room().stage, isA<RoomSideDecking>());
      expect(room().sidingMain!.map((c) => c.code), mainCodes);
      expect(room().sidingExtra!.map((c) => c.code), extraCodes);
      expect(room().sidingSide!.map((c) => c.code), sideCodes);
      expect(room().sidingBaseline!.main, hasLength(mainCodes.length));
      expect(room().sidingBaseline!.extra, hasLength(extraCodes.length));
      expect(room().sidingBaseline!.side, hasLength(sideCodes.length));
      expect(room().isSidingCountsValid, isTrue);
    });

    test('无提交记录时回退到当前所选卡组的构成', () async {
      await enterMatchRoom();
      expect(room().submittedDeck, isNull);

      duelService.emitStage(const RoomSideDecking());
      await settle();

      expect(room().stage, isA<RoomSideDecking>());
      expect(room().sidingMain!.map((c) => c.code), mainCodes);
      expect(room().sidingExtra!.map((c) => c.code), extraCodes);
      expect(room().sidingSide!.map((c) => c.code), sideCodes);
      expect(room().isSidingCountsValid, isTrue);
    });

    test('离开换备阶段后清理换备状态', () async {
      await enterMatchRoom();
      await notifier().toggleReady();
      duelService.emitStage(const RoomSideDecking());
      await settle();
      expect(room().sidingDeck, isNotNull);

      duelService.emitStage(const RoomStartDuel());
      await settle();

      expect(room().stage, isA<RoomStartDuel>());
      expect(room().sidingDeck, isNull);
      expect(room().sidingBaseline, isNull);
    });
  });

  group('换备移动操作', () {
    Future<void> enterSiding() async {
      await enterMatchRoom();
      await notifier().toggleReady();
      duelService.emitStage(const RoomSideDecking());
      await settle();
    }

    test('主卡组 → 副卡组 合法', () async {
      await enterSiding();
      final moved = notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);
      expect(moved, isTrue);
      expect(room().sidingMain, hasLength(mainCodes.length - 1));
      expect(room().sidingSide, hasLength(sideCodes.length + 1));
      expect(room().sidingSide!.last.code, mainCodes.first);
      expect(room().sidingMain!.map((c) => c.code), isNot(contains(mainCodes.first)));
    });

    test('额外卡组 → 副卡组 合法', () async {
      await enterSiding();
      final moved =
          notifier().moveSidingCard(SidingZone.extra, SidingZone.side, 1);
      expect(moved, isTrue);
      expect(room().sidingExtra, hasLength(extraCodes.length - 1));
      expect(room().sidingSide!.map((c) => c.code), contains(extraCodes[1]));
    });

    test('副卡组 → 主卡组 / 额外卡组 合法', () async {
      await enterSiding();
      expect(
        notifier().moveSidingCard(SidingZone.side, SidingZone.main, 0),
        isTrue,
      );
      expect(room().sidingMain!.last.code, sideCodes[0]);
      expect(
        notifier().moveSidingCard(SidingZone.side, SidingZone.extra, 0),
        isTrue,
      );
      expect(room().sidingExtra!.last.code, sideCodes[1]);
      expect(room().sidingSide, isEmpty);
    });

    test('主卡组 ↔ 额外卡组 直接交换被拒绝', () async {
      await enterSiding();
      final before = room().sidingDeck;
      expect(
        notifier().moveSidingCard(SidingZone.main, SidingZone.extra, 0),
        isFalse,
      );
      expect(
        notifier().moveSidingCard(SidingZone.extra, SidingZone.main, 0),
        isFalse,
      );
      expect(room().sidingDeck, same(before));
    });

    test('越界下标 / 同分区 / 非换备阶段 均被拒绝', () async {
      await enterSiding();
      expect(
        notifier().moveSidingCard(SidingZone.main, SidingZone.side, 999),
        isFalse,
      );
      expect(
        notifier().moveSidingCard(SidingZone.main, SidingZone.side, -1),
        isFalse,
      );
      expect(
        notifier().moveSidingCard(SidingZone.main, SidingZone.main, 0),
        isFalse,
      );

      duelService.emitStage(const RoomStartDuel());
      await settle();
      expect(
        notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0),
        isFalse,
      );
    });
  });

  group('数量校验与重置', () {
    test('数量偏离基准时 isSidingCountsValid 为 false，恢复后为 true',
        () async {
      await enterMatchRoom();
      await notifier().toggleReady();
      duelService.emitStage(const RoomSideDecking());
      await settle();

      notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);
      expect(room().isSidingCountsValid, isFalse);

      notifier().moveSidingCard(SidingZone.side, SidingZone.main, 0);
      expect(room().isSidingCountsValid, isTrue);
    });

    test('重置恢复基准构成', () async {
      await enterMatchRoom();
      await notifier().toggleReady();
      duelService.emitStage(const RoomSideDecking());
      await settle();

      notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);
      notifier().moveSidingCard(SidingZone.extra, SidingZone.side, 0);
      expect(room().isSidingCountsValid, isFalse);

      notifier().resetSiding();
      expect(room().sidingMain!.map((c) => c.code), mainCodes);
      expect(room().sidingExtra!.map((c) => c.code), extraCodes);
      expect(room().sidingSide!.map((c) => c.code), sideCodes);
      expect(room().isSidingCountsValid, isTrue);
    });
  });

  group('换备确认（confirmSiding）', () {
    Future<void> enterSiding() async {
      await enterMatchRoom();
      await notifier().toggleReady();
      duelService.emitStage(const RoomSideDecking());
      await settle();
    }

    test('数量不一致时拒绝提交', () async {
      await enterSiding();
      notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);

      final err = await notifier().confirmSiding();
      expect(err, isNotNull);
      expect(err, contains('数量'));
      expect(duelService.submittedDecks, hasLength(1)); // 未新增提交
      expect(duelService.readyCount, 1); // 未再次 ready
    });

    test('非换备阶段拒绝提交', () async {
      await enterMatchRoom();
      expect(await notifier().confirmSiding(), '当前不在换备阶段');
    });

    test('换备数据未就绪时拒绝提交', () async {
      await enterMatchRoom();
      expect(room().submittedDeck, isNull);
      // 卡片解析挂起：_enterSideDecking 停在加载中，sidingDeck 保持 null。
      cardService.hang = true;
      duelService.emitStage(const RoomSideDecking());
      await settle();
      expect(room().stage, isA<RoomSideDecking>());
      expect(room().sidingDeck, isNull);
      expect(await notifier().confirmSiding(), '换备数据尚未就绪');
    });

    test('确认后按新构成编码上送，且新构成成为基准', () async {
      await enterSiding();
      // 主卡组第一张（1000）与副卡组第一张（3001）互换。
      notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);
      notifier().moveSidingCard(SidingZone.side, SidingZone.main, 0);
      expect(room().isSidingCountsValid, isTrue);

      final err = await notifier().confirmSiding();
      expect(err, isNull);
      expect(duelService.readyCount, 2); // 准备时的 ready + 换备确认的 ready
      expect(duelService.submittedDecks, hasLength(2));

      final sub = duelService.submittedDecks[1];
      final expectedMain = [...mainCodes.sublist(1), sideCodes[0]];
      final expectedSide = [sideCodes[1], mainCodes[0]];
      expect(bytesToInts(sub.main), expectedMain);
      expect(bytesToInts(sub.extra), extraCodes);
      expect(bytesToInts(sub.side!), expectedSide);

      // 新构成替换提交记录，成为下一局换备的基准。
      expect(room().submittedDeck!.main, expectedMain);
      expect(room().submittedDeck!.extra, extraCodes);
      expect(room().submittedDeck!.side, expectedSide);
      expect(room().sidingBaseline!.main.map((c) => c.code), expectedMain);
    });

    test('换备后进入下一局再换备，基准为上局确认的构成', () async {
      await enterSiding();
      notifier().moveSidingCard(SidingZone.main, SidingZone.side, 0);
      notifier().moveSidingCard(SidingZone.side, SidingZone.main, 0);
      await notifier().confirmSiding();

      // 下一局开始 → 结束 → 再次换备。
      duelService.emitStage(const RoomStartDuel());
      await settle();
      duelService.emitStage(const RoomSideDecking());
      await settle();

      final expectedMain = [...mainCodes.sublist(1), sideCodes[0]];
      expect(room().sidingMain!.map((c) => c.code), expectedMain);
      expect(room().sidingBaseline!.main, hasLength(mainCodes.length));
      expect(room().isSidingCountsValid, isTrue);
    });
  });

  group('禁限卡表复核', () {
    test('确认时复用 selectDeck 的禁限校验，违规拒绝提交', () async {
      await enterMatchRoom(noCheckDeck: false);
      // 进房时禁限表不可用（null）→ 校验跳过，准备成功。
      await notifier().toggleReady();
      expect(duelService.submittedDecks, hasLength(1));

      duelService.emitStage(const RoomSideDecking());
      await settle();

      // 局间禁限表生效，且禁止了卡池中的一张卡。
      banlistService.table = const LfTable(
        name: '测试表',
        lfInfos: {
          1000: LfInfo(code: 1000, limit: LfType.forbidden, name: '禁止卡'),
        },
      );

      final err = await notifier().confirmSiding();
      expect(err, isNotNull);
      expect(err, contains('不合规'));
      expect(duelService.submittedDecks, hasLength(1)); // 未提交
      expect(duelService.readyCount, 1);
    });
  });
}
