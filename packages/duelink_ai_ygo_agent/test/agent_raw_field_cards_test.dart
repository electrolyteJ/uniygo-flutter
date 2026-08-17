/// `parseFieldCards` 测试：手工构造 `query_field_card` 记录字节流，
/// 覆盖 LEN_EMPTY 空槽、素材/计数器/LINK 字段与记录末尾重对齐。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferWriter;
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';

/// 构造一条查询记录：[len][flag][字段…]，len 含自身 4 字节。
Uint8List record(int flag, void Function(BufferWriter w) body) {
  final inner = BufferWriter();
  body(inner);
  final bytes = inner.toBytes();
  final w = BufferWriter();
  w.writeUint32(8 + bytes.length);
  w.writeUint32(flag);
  w.writeBytes(bytes);
  return w.toBytes();
}

void main() {
  group('parseFieldCards', () {
    test('完整记录 + LEN_EMPTY 空槽 + 第二条记录', () {
      final buf = BufferWriter();

      // 记录 1：场上 XYZ 素材宿主（全字段）。
      buf.writeBytes(record(
        QUERY_CODE |
            QUERY_POSITION |
            QUERY_LEVEL |
            QUERY_RANK |
            QUERY_ATTACK |
            QUERY_DEFENSE |
            QUERY_OVERLAY_CARD |
            QUERY_COUNTERS |
            QUERY_STATUS |
            QUERY_LSCALE |
            QUERY_RSCALE |
            QUERY_LINK,
        (w) {
          w.writeUint32(1001); // code
          w.writeUint8(0); // controller
          w.writeUint8(LOCATION_MZONE);
          w.writeUint8(3);
          w.writeUint8(POS_FACEUP_ATTACK);
          w.writeUint32(4); // level
          w.writeUint32(0); // rank
          w.writeInt32(2500); // attack
          w.writeInt32(2000); // defense
          w.writeUint32(2); // overlay count
          w.writeUint32(2001);
          w.writeUint32(2002);
          w.writeUint32(1); // counters count
          w.writeUint32(0x1 | (3 << 16)); // type=1 count=3
          w.writeUint32(STATUS_DISABLED); // status
          w.writeUint32(0); // lscale
          w.writeUint32(0); // rscale
          w.writeUint32(0); // link
          w.writeUint32(0); // link_marker
        },
      ));

      // 空槽（仅 len=4）。
      buf.writeUint32(LEN_EMPTY);

      // 记录 2：连接怪兽（LINK 覆盖 level/defense）。
      buf.writeBytes(record(
        QUERY_CODE |
            QUERY_POSITION |
            QUERY_ATTACK |
            QUERY_DEFENSE |
            QUERY_STATUS |
            QUERY_LINK,
        (w) {
          w.writeUint32(1002);
          w.writeUint8(1);
          w.writeUint8(LOCATION_MZONE);
          w.writeUint8(0);
          w.writeUint8(POS_FACEUP_DEFENSE);
          w.writeInt32(1800);
          w.writeInt32(1200); // defense（将被 link_marker 覆盖）
          w.writeUint32(0);
          w.writeUint32(2); // link
          w.writeUint32(0x40); // link_marker
        },
      ));

      final cards = parseFieldCards(buf.toBytes());
      expect(cards, hasLength(2));

      final c1 = cards[0];
      expect(c1.code, 1001);
      expect(c1.controller, 0);
      expect(c1.location, LOCATION_MZONE);
      expect(c1.sequence, 3);
      expect(c1.position, POS_FACEUP_ATTACK);
      expect(c1.level, 4);
      expect(c1.attack, 2500);
      expect(c1.defense, 2000);
      expect(c1.overlayCodes, [2001, 2002]);
      expect(c1.counter, 0x1 | (3 << 16));
      expect(c1.status, STATUS_DISABLED);

      final c2 = cards[1];
      expect(c2.code, 1002);
      expect(c2.link, 2);
      expect(c2.linkMarker, 0x40);
    });

    test('跳过未请求字段，按 flag 解析', () {
      final buf = BufferWriter();
      buf.writeBytes(record(QUERY_CODE | QUERY_POSITION, (w) {
        w.writeUint32(42);
        w.writeUint8(1);
        w.writeUint8(LOCATION_HAND);
        w.writeUint8(5);
        w.writeUint8(POS_FACEDOWN);
      }));

      final cards = parseFieldCards(buf.toBytes());
      expect(cards.single.code, 42);
      expect(cards.single.location, LOCATION_HAND);
      expect(cards.single.level, 0); // 未查询 → 默认 0
      expect(cards.single.overlayCodes, isEmpty);
    });

    test('record len 对齐：多余尾部字节不串行', () {
      // 记录 1 声明的 len 比实际字段多 4 字节（模拟引擎填充）。
      final inner = BufferWriter();
      inner.writeUint32(77); // code
      inner.writeUint8(0);
      inner.writeUint8(LOCATION_DECK);
      inner.writeUint8(0);
      inner.writeUint8(POS_FACEDOWN);
      final innerBytes = inner.toBytes();

      final buf = BufferWriter();
      buf.writeUint32(8 + innerBytes.length + 4);
      buf.writeUint32(QUERY_CODE | QUERY_POSITION);
      buf.writeBytes(innerBytes);
      buf.writeUint32(0xdeadbeef); // 填充（位于声明的 len 之内）
      // 记录 2：正常。
      buf.writeBytes(record(QUERY_CODE, (w) => w.writeUint32(78)));

      final cards = parseFieldCards(buf.toBytes());
      expect(cards.map((c) => c.code), [77, 78]);
    });

    test('未知 QUERY 位抛 FormatException', () {
      final buf = BufferWriter();
      buf.writeBytes(record(QUERY_CODE | (1 << 30), (w) {
        w.writeUint32(1);
      }));
      expect(() => parseFieldCards(buf.toBytes()), throwsFormatException);
    });

    test('空缓冲返回空列表', () {
      expect(parseFieldCards(Uint8List(0)), isEmpty);
    });
  });
}
