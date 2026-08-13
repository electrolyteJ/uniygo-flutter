/// [AgentInputBuilder] 测试：用假 [AgentFieldQuery] 注入构造好的查询记录，
/// 验证 env 观测语义（区域隐藏、单卡隐藏、素材顺序、controller 相对化、
/// 全局特征）。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferWriter;
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';
import 'package:ygo_agent/ygo_agent.dart';

/// 构造单张卡的查询记录（字段集与 env 查询标志一致）。
Uint8List cardRecord({
  required int code,
  required int controller,
  required int location,
  required int sequence,
  required int position,
  int level = 0,
  int rank = 0,
  int attack = 0,
  int defense = 0,
  int status = 0,
  List<int> overlays = const [],
}) {
  var flag = QUERY_CODE |
      QUERY_POSITION |
      QUERY_LEVEL |
      QUERY_RANK |
      QUERY_ATTACK |
      QUERY_DEFENSE |
      QUERY_STATUS;
  if (overlays.isNotEmpty) flag |= QUERY_OVERLAY_CARD;

  final inner = BufferWriter();
  inner.writeUint32(code);
  inner.writeUint8(controller);
  inner.writeUint8(location);
  inner.writeUint8(sequence);
  inner.writeUint8(position);
  inner.writeUint32(level);
  inner.writeUint32(rank);
  inner.writeInt32(attack);
  inner.writeInt32(defense);
  if (overlays.isNotEmpty) {
    inner.writeUint32(overlays.length);
    for (final c in overlays) {
      inner.writeUint32(c);
    }
  }
  inner.writeUint32(status);

  final w = BufferWriter();
  final bytes = inner.toBytes();
  w.writeUint32(8 + bytes.length);
  w.writeUint32(flag);
  w.writeBytes(bytes);
  return w.toBytes();
}

Uint8List concat(List<Uint8List> parts) {
  final w = BufferWriter();
  for (final p in parts) {
    w.writeBytes(p);
  }
  return w.toBytes();
}

class FakeField implements AgentFieldQuery {
  final Map<(int, int), Uint8List> buffers = {};
  final Map<(int, int), int> counts = {};

  void put(int player, int location, Uint8List buffer, {int? count}) {
    buffers[(player, location)] = buffer;
    counts[(player, location)] = count ?? 0;
  }

  @override
  int fieldCount(int player, int location) =>
      counts[(player, location)] ?? 0;

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      buffers[(player, location)] ?? Uint8List(0);
}

Uint8List yesNoPayload(int player, int desc) {
  final w = BufferWriter();
  w.writeUint8(player);
  w.writeUint32(desc);
  return w.toBytes();
}

void main() {
  group('AgentInputBuilder', () {
    test('区域隐藏：revealed 为空时对手 deck/hand/extra 只写数量占位', () {
      final tracker = DuelFieldTracker(startLp: 8000);
      tracker.observe(MSG_NEW_TURN, Uint8List.fromList([0]));
      final field = FakeField();
      // 我方（player 0）mzone 一张明面卡。
      field.put(
        0,
        LOCATION_MZONE,
        cardRecord(
          code: 100,
          controller: 0,
          location: LOCATION_MZONE,
          sequence: 0,
          position: POS_FACEUP_ATTACK,
          level: 4,
          attack: 1800,
          defense: 1200,
        ),
      );
      // 对方（player 1）deck 3 张、hand 2 张（仅数量）。
      field.put(1, LOCATION_DECK, Uint8List(0), count: 3);
      field.put(1, LOCATION_HAND, Uint8List(0), count: 2);

      final builder = AgentInputBuilder(field: field, tracker: tracker);
      final input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(0, 99),
        toPlay: 0,
      );

      // 我方逐卡：deck 0 + hand 0 + mzone 1 → 首张即我方怪兽。
      final mine = input.cards.first;
      expect(mine.code, 100);
      expect(mine.controller, Controller.me);
      expect(mine.level, 4);

      // 对方隐藏区：3 + 2 张占位行（code=0、controller=opponent）。
      final placeholders = input.cards.where((c) => c.code == 0).toList();
      expect(placeholders, hasLength(5));
      expect(
        placeholders.where((c) => c.location == Location.deck),
        hasLength(3),
      );
      expect(
        placeholders.where((c) => c.location == Location.hand),
        hasLength(2),
      );
      for (final p in placeholders) {
        expect(p.controller, Controller.opponent);
        expect(p.position, Position.none);
        expect(p.overlaySequence, -1);
      }
    });

    test('单卡隐藏：对方里侧卡写暗牌行；revealed 后解禁', () {
      final tracker = DuelFieldTracker(startLp: 8000);
      final field = FakeField();
      field.put(
        1,
        LOCATION_MZONE,
        concat([
          cardRecord(
            code: 300,
            controller: 1,
            location: LOCATION_MZONE,
            sequence: 0,
            position: POS_FACEDOWN_DEFENSE,
            attack: 1000,
          ),
          cardRecord(
            code: 301,
            controller: 1,
            location: LOCATION_MZONE,
            sequence: 1,
            position: POS_FACEUP_ATTACK,
            level: 3,
            attack: 1500,
          ),
        ]),
      );
      final builder = AgentInputBuilder(field: field, tracker: tracker);

      // 未 revealed：里侧卡 code=0 但保留位置信息。
      var input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(0, 0),
        toPlay: 0,
      );
      expect(input.cards, hasLength(2));
      expect(input.cards[0].code, 0);
      expect(input.cards[0].position, Position.facedownDefense);
      expect(input.cards[0].sequence, 0);
      expect(input.cards[0].controller, Controller.opponent);
      expect(input.cards[0].attack, 0);
      expect(input.cards[1].code, 301);

      // CONFIRM_CARDS 公开后：暗牌变明牌。
      // env 语义：插入 spec 时 opponent 标志 = (c == player)，而观测侧
      // 查找用 opponent=true 的 'o' 前缀 spec —— 因此要解禁对方视角的
      // 卡，消息 player 必须等于卡牌 controller（此处均为 1）。
      tracker.observe(MSG_CONFIRM_CARDS, () {
        final w = BufferWriter();
        w.writeUint8(1); // player == controller → spec 带 o 前缀
        w.writeUint8(0);
        w.writeUint8(1);
        w.writeUint32(300);
        w.writeUint8(1); // controller
        w.writeUint8(LOCATION_MZONE);
        w.writeUint8(0);
        return w.toBytes();
      }());
      input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(0, 0),
        toPlay: 0,
      );
      expect(input.cards[0].code, 300);
      expect(input.cards[0].attack, 1000);
    });

    test('素材先于宿主入列，素材特征走 DB（level 取绝对值）', () {
      final tracker = DuelFieldTracker(startLp: 8000);
      final field = FakeField();
      field.put(
        0,
        LOCATION_MZONE,
        cardRecord(
          code: 400,
          controller: 0,
          location: LOCATION_MZONE,
          sequence: 2,
          position: POS_FACEUP_ATTACK,
          rank: 4,
          attack: 2500,
          defense: 2000,
          overlays: [501, 502],
        ),
      );
      final db = <int, CardData>{
        501: CardData(
          code: 501,
          alias: 0,
          setcode: const [],
          type: TYPE_MONSTER | TYPE_XYZ | TYPE_EFFECT,
          level: -4, // 本工程 CardData 对 XYZ 存负数
          attribute: ATTRIBUTE_FIRE,
          race: RACE_DRAGON,
          attack: 2500,
          defense: 2000,
          lscale: 0,
          rscale: 0,
          linkMarker: 0,
          ruleCode: 0,
          name: 'mat',
          desc: '',
        ),
      };
      final builder = AgentInputBuilder(
        field: field,
        tracker: tracker,
        cardData: (code) => db[code],
      );
      final input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(0, 0),
        toPlay: 0,
      );

      expect(input.cards.map((c) => c.code), [501, 502, 400]);
      final mat1 = input.cards[0];
      expect(mat1.overlaySequence, 0);
      expect(mat1.sequence, 2); // 宿主 sequence
      expect(mat1.location, Location.mzone);
      expect(mat1.controller, Controller.me);
      expect(mat1.level, 4); // abs(-4)
      expect(mat1.attribute, Attribute.fire);
      expect(mat1.race, Race.dragon);
      expect(mat1.types, containsAll([CardType.monster, CardType.xyz]));
      expect(input.cards[1].overlaySequence, 1);
      expect(input.cards[1].code, 502); // 无 DB 数据 → 仅卡面特征为 0
      expect(input.cards[1].level, 0);

      final host = input.cards[2];
      expect(host.overlaySequence, -1);
      expect(host.level, 4); // rank 链覆写
    });

    test('toPlay=1：controller 按应答玩家相对化', () {
      final tracker = DuelFieldTracker(startLp: 8000);
      tracker.observe(MSG_NEW_TURN, Uint8List.fromList([1]));
      final field = FakeField();
      field.put(
        0,
        LOCATION_MZONE,
        cardRecord(
          code: 600,
          controller: 0,
          location: LOCATION_MZONE,
          sequence: 0,
          position: POS_FACEUP_ATTACK,
          level: 2,
        ),
      );
      field.put(
        1,
        LOCATION_MZONE,
        cardRecord(
          code: 601,
          controller: 1,
          location: LOCATION_MZONE,
          sequence: 0,
          position: POS_FACEUP_ATTACK,
          level: 5,
        ),
      );

      final builder = AgentInputBuilder(field: field, tracker: tracker);
      final input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(1, 0),
        toPlay: 1,
      );

      // pi=0 先观测 toPlay=1（绝对玩家 1）的区。
      expect(input.cards.first.code, 601);
      expect(input.cards.first.controller, Controller.me);
      final other = input.cards.firstWhere((c) => c.code == 600);
      expect(other.controller, Controller.opponent);

      expect(input.global.isFirst, isFalse);
      expect(input.global.isMyTurn, isTrue);
    });

    test('global 特征：LP / turn / phase / isFirst / isMyTurn', () {
      final tracker = DuelFieldTracker(startLp: 8000);
      for (var i = 0; i < 5; i++) {
        tracker.observe(MSG_NEW_TURN, Uint8List.fromList([i % 2]));
      }
      tracker.observe(
          MSG_NEW_PHASE,
          Uint8List.fromList(
              [PHASE_MAIN2 & 0xff, (PHASE_MAIN2 >> 8) & 0xff]));
      var w = BufferWriter()
        ..writeUint8(1)
        ..writeUint32(5000);
      tracker.observe(MSG_DAMAGE, w.toBytes());

      final builder =
          AgentInputBuilder(field: FakeField(), tracker: tracker);
      final input = builder.build(
        func: MSG_SELECT_YESNO,
        payload: yesNoPayload(1, 0),
        toPlay: 1,
      );
      expect(input.global.myLp, 3000);
      expect(input.global.opLp, 8000);
      expect(input.global.turn, 5);
      expect(input.global.phase, Phase.main2);
      expect(input.global.isFirst, isFalse);
      // turnPlayer = 最后一次 NEW_TURN = 4 % 2 = 0 ≠ toPlay 1
      expect(input.global.isMyTurn, isFalse);
    });

    test('env 不支持的消息形状抛 NotSupportedException', () {
      final builder =
          AgentInputBuilder(field: FakeField(), tracker: DuelFieldTracker());
      expect(
        () => builder.build(
          func: MSG_SORT_CARD,
          payload: Uint8List.fromList([0, 1]),
          toPlay: 0,
        ),
        throwsA(isA<NotSupportedException>()),
      );
    });
  });
}
