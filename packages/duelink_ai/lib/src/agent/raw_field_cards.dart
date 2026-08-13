/// ocgcore `query_field_card` 记录字节流的标志位驱动解析器。
///
/// 记录格式（ocgcore `card::get_infos`，与 ygo-agent env
/// `get_cards_in_location` 消费的格式一致）：
///
/// ```text
/// [u32 len]                        // 本记录总长（含 len 自身）；
///                                  // len == LEN_EMPTY(4) 表示空槽，无后续字段
/// [u32 flag]                       // 本记录实际携带的 QUERY_* 位集合
/// 按 flag 位升序排列的字段：
///   CODE u32 / POSITION c,l,s,pos / ALIAS u32 / TYPE u32 / LEVEL u32 /
///   RANK u32 / ATTRIBUTE u32 / RACE u32 / ATTACK i32 / DEFENSE i32 /
///   BASE_ATTACK i32 / BASE_DEFENSE i32 / REASON u32 / REASON_CARD u32 /
///   EQUIP_CARD u32 / TARGET_CARD u32 n + n×u32 /
///   OVERLAY_CARD u32 n + n×u32 / COUNTERS u32 n + n×u32(type|count<<16) /
///   OWNER u32 / STATUS u32 / LSCALE u32 / RSCALE u32 /
///   LINK u32 link + u32 link_marker
/// ```
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader;
import 'package:ocgcore/ocgcore.dart';

/// 单张卡的原始查询结果（未做 DB 修正的引擎当前值）。
class RawFieldCard {
  int code = 0;
  int controller = 0;
  int location = 0;
  int sequence = 0;
  int position = 0;
  int type = 0;
  int level = 0;
  int rank = 0;
  int link = 0;
  int linkMarker = 0;
  int attribute = 0;
  int race = 0;
  int attack = 0;
  int defense = 0;
  int status = 0;

  /// 第一个计数器的打包值（`type | count << 16`）；无计数器为 0。
  /// 与 env 一致：只取第一条记录。
  int counter = 0;

  /// XYZ 素材卡号列表（QUERY_OVERLAY_CARD），按素材顺序。
  List<int> overlayCodes = const [];

  @override
  String toString() =>
      'RawFieldCard(code:$code c:$controller l:$location s:$sequence '
      'pos:$position overlays:$overlayCodes)';
}

/// 本解析器能处理的全部 QUERY_* 位；记录里出现其它位时抛
/// [FormatException]（宽度未知，无法安全跳过）。
const int _supportedQueryFlags = QUERY_CODE |
    QUERY_POSITION |
    QUERY_ALIAS |
    QUERY_TYPE |
    QUERY_LEVEL |
    QUERY_RANK |
    QUERY_ATTRIBUTE |
    QUERY_RACE |
    QUERY_ATTACK |
    QUERY_DEFENSE |
    QUERY_BASE_ATTACK |
    QUERY_BASE_DEFENSE |
    QUERY_REASON |
    QUERY_REASON_CARD |
    QUERY_EQUIP_CARD |
    QUERY_TARGET_CARD |
    QUERY_OVERLAY_CARD |
    QUERY_COUNTERS |
    QUERY_OWNER |
    QUERY_STATUS |
    QUERY_LSCALE |
    QUERY_RSCALE |
    QUERY_LINK;

/// 解析 `query_field_card` 输出。空槽（len == LEN_EMPTY）被跳过，
/// 返回列表与区域内实际卡牌的顺序一致（素材卡不在其中 ——
/// 它们通过宿主卡的 [RawFieldCard.overlayCodes] 呈现）。
List<RawFieldCard> parseFieldCards(Uint8List buffer) {
  final r = BufferReader(buffer);
  final cards = <RawFieldCard>[];
  while (r.hasRemaining) {
    final len = r.readUint32();
    if (len == LEN_EMPTY) continue; // 空槽：仅 len 字段
    if (len < 8) {
      throw FormatException('query record len too small: $len');
    }
    final recordEnd = r.offset - 4 + len;
    final flag = r.readUint32();
    if ((flag & ~_supportedQueryFlags) != 0) {
      throw FormatException(
          'unsupported QUERY bits in record: 0x${flag.toRadixString(16)}');
    }
    final card = RawFieldCard();

    if (flag & QUERY_CODE != 0) card.code = r.readUint32();
    if (flag & QUERY_POSITION != 0) {
      card.controller = r.readUint8();
      card.location = r.readUint8();
      card.sequence = r.readUint8();
      card.position = r.readUint8();
    }
    if (flag & QUERY_ALIAS != 0) r.skip(4);
    if (flag & QUERY_TYPE != 0) card.type = r.readUint32();
    if (flag & QUERY_LEVEL != 0) card.level = r.readUint32();
    if (flag & QUERY_RANK != 0) card.rank = r.readUint32();
    if (flag & QUERY_ATTRIBUTE != 0) card.attribute = r.readUint32();
    if (flag & QUERY_RACE != 0) card.race = r.readUint32();
    if (flag & QUERY_ATTACK != 0) card.attack = r.readInt32();
    if (flag & QUERY_DEFENSE != 0) card.defense = r.readInt32();
    if (flag & QUERY_BASE_ATTACK != 0) r.skip(4);
    if (flag & QUERY_BASE_DEFENSE != 0) r.skip(4);
    if (flag & QUERY_REASON != 0) r.skip(4);
    if (flag & QUERY_REASON_CARD != 0) r.skip(4);
    if (flag & QUERY_EQUIP_CARD != 0) r.skip(4);
    if (flag & QUERY_TARGET_CARD != 0) {
      r.skip(4 * r.readUint32());
    }
    if (flag & QUERY_OVERLAY_CARD != 0) {
      card.overlayCodes = r.readUint32List(r.readUint32());
    }
    if (flag & QUERY_COUNTERS != 0) {
      final n = r.readUint32();
      if (n > 0) {
        card.counter = r.readUint32();
        r.skip(4 * (n - 1));
      }
    }
    if (flag & QUERY_OWNER != 0) r.skip(4);
    if (flag & QUERY_STATUS != 0) card.status = r.readUint32();
    if (flag & QUERY_LSCALE != 0) r.skip(4);
    if (flag & QUERY_RSCALE != 0) r.skip(4);
    if (flag & QUERY_LINK != 0) {
      card.link = r.readUint32();
      card.linkMarker = r.readUint32();
    }

    // 按 len 对齐到下一记录（双保险：即使字段解析有偏差也不串行）。
    if (r.offset != recordEnd) {
      if (recordEnd < r.offset || recordEnd > buffer.length) {
        throw FormatException('query record len mismatch: $len');
      }
      r.setOffset(recordEnd);
    }
    cards.add(card);
  }
  return cards;
}
