import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CONFIRM_CARDS (0x1F) / MSG_CONFIRM_DECKTOP (0x1E) /
/// MSG_CONFIRM_EXTRATOP (0x2A) — 展示并确认卡牌信息。
///
/// 三者都会携带由 7 字节 `CardInfo` 组成的列表，但原始协议格式略有差异：
/// - `MSG_CONFIRM_CARDS` 为 `player + skipPanel + count + cards`
/// - `MSG_CONFIRM_DECKTOP` / `MSG_CONFIRM_EXTRATOP` 为 `player + count + cards`
///
/// `duelink` 统一复用本类型承载，`funcId` 用于区分是否带 `skipPanel` 字节。
/// `skipPanel = 1` 表示服务端要求跳过确认弹窗（卡片已通过其他途径展示过），
/// 客户端应静默处理而不弹出确认面板。
///
/// 有线格式 (变长):
/// | 偏移 | 大小  | 类型         | 说明                |
/// |------|-------|--------------|---------------------|
/// | 0x00 | 1     | uint8        | 玩家 (0 或 1)       |
/// | 0x01 | 1     | uint8        | `skipPanel`（仅 MSG_CONFIRM_CARDS） |
/// | 0x02 | 1     | uint8        | `count`              |
/// | ...  | 7 * n | CardInfo[n]  | 每张卡的 7 字节信息：`code(u32) + controller(u8) + location(u8) + sequence(u8)` |
///
/// 对照 ygopro / ocgcore：
/// - MSG_CONFIRM_CARDS: `player + skip_panel + count + n * 7`
/// - MSG_CONFIRM_DECKTOP / MSG_CONFIRM_EXTRATOP: `player + count + n * 7`
class MsgConfirmCards {
  final int player;

  /// 0 = 弹出确认面板；1 = 跳过确认面板（仅 MSG_CONFIRM_CARDS 有该字节）。
  final int skipPanel;
  final int count;
  final List<CardInfo> cards;

  /// 消息类型（MSG_CONFIRM_CARDS / MSG_CONFIRM_DECKTOP / MSG_CONFIRM_EXTRATOP），
  /// 决定编码/解码时是否带 `skipPanel` 字节。
  final int funcId;

  const MsgConfirmCards({
    required this.player,
    required this.count,
    required this.cards,
    this.skipPanel = 0,
    this.funcId = MSG_CONFIRM_CARDS,
  });

  /// 是否携带 `skipPanel` 字节（仅 MSG_CONFIRM_CARDS 有）。
  bool get hasSkipPanel => funcId == MSG_CONFIRM_CARDS;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    if (hasSkipPanel) {
      w.writeUint8(skipPanel);
    }
    w.writeUint8(count);
    for (final c in cards) {
      w.writeCardInfo(c);
    }
    return w.toBytes();
  }

  static MsgConfirmCards decode(Uint8List data, int funcId) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final hasSkipPanel = funcId == MSG_CONFIRM_CARDS;
    final skipPanel = hasSkipPanel ? r.readUint8() : 0;
    final count = r.readUint8();
    final cards = <CardInfo>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readCardInfo());
    }
    return MsgConfirmCards(
      player: player,
      skipPanel: skipPanel,
      count: count,
      cards: cards,
      funcId: funcId,
    );
  }

  @override
  String toString() =>
      'MsgConfirmCards(player:$player skipPanel:$skipPanel count:$count cards:$cards)';
}
