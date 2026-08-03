import 'dart:typed_data';
import '../constants.dart';
import '../model/card.dart';

/// 二进制缓冲区顺序读写工具。
///
/// 所有数值均为小端序（LE），与 ygopro 服务端协议一致。
///
/// 本文件里的 `CardLocation` / `CardShortLocation` / `CardInfo` 在保留原始协议字段
/// 的同时，额外提供了 enum helper getter，方便上层直接按语义消费：
/// - 优先使用 `zone` / `zoneEnum` / `cardPosition` 这类语义化 getter
/// - 需要保留原始字节、做位运算、或兼容未知值时，再读取 `rawLocation` / `rawPosition`
///
/// 参考 neos-ts 的 bufferIO.ts 定义。

/// 顺序二进制读取器，小端序。
class BufferReader {
  final Uint8List _data;
  int _offset = 0;

  BufferReader(this._data);

  int get offset => _offset;
  int get remaining => _data.length - _offset;
  bool get hasRemaining => _offset < _data.length;

  void skip(int n) => _offset += n;
  void setOffset(int n) => _offset = n;

  int readUint8() => _data[_offset++];
  int readInt8() {
    final v = _data[_offset++];
    return v > 127 ? v - 256 : v;
  }

  int readUint16() {
    final v = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return v;
  }

  int readInt16() {
    final v = readUint16();
    return v > 32767 ? v - 65536 : v;
  }

  int readUint32() {
    final v = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24);
    _offset += 4;
    return v;
  }

  int readInt32() {
    final v = readUint32();
    return v > 2147483647 ? v - 4294967296 : v;
  }

  Uint8List readBytes(int n) {
    final bytes = _data.sublist(_offset, _offset + n);
    _offset += n;
    return bytes;
  }

  List<int> readUint32List(int count) {
    return List.generate(count, (_) => readUint32());
  }

  /// 读取 4 字节卡牌位置：
  /// - controller (u8): 控制者，0=自己，1=对方
  /// - location (u8): 区域标识（可能包含 LOCATION_OVERLAY 位标记）
  /// - sequence (u8): 序列号
  /// - ss (u8): 表示形式或叠放序号（由 isOverlay 决定语义）
  CardLocation readCardLocation() {
    final c = readUint8();
    final l = readUint8();
    final s = readUint8();
    final ss = readUint8();
    final isOverlay = (l & LOCATION_OVERLAY) != 0;
    return CardLocation(
      controller: c,
      location: l & ~LOCATION_OVERLAY,
      sequence: s,
      position: isOverlay ? 0 : ss,
      isOverlay: isOverlay,
      overlaySequence: isOverlay ? ss : 0,
    );
  }

  /// 读取 3 字节短卡牌位置（不含表示形式/叠放序号）：
  /// - controller (u8) + location (u8) + sequence (u8)
  CardShortLocation readCardShortLocation() {
    return CardShortLocation(
      controller: readUint8(),
      location: readUint8(),
      sequence: readUint8(),
    );
  }

  /// 读取 7 字节卡牌信息：
  /// - code (u32): 卡牌密码
  /// - controller (u8): 控制者
  /// - location (u8): 区域
  /// - sequence (u8): 序列号
  CardInfo readCardInfo() {
    return CardInfo(
      code: readUint32(),
      controller: readUint8(),
      location: readUint8(),
      sequence: readUint8(),
    );
  }

  /// 读取固定长度 UTF-16 LE 编码的字符串（最大 [maxBytes] 字节）。
  ///
  /// ygopro 协议中的昵称等字段使用 20 字符（40 字节）固定长度，
  /// 以 null 结束，剩余用 0xcccc 填充。
  String readUtf16({int maxBytes = 40}) {
    final codes = <int>[];
    final end = (_offset + maxBytes).clamp(0, _data.length);
    while (_offset < end - 1) {
      final low = _data[_offset];
      final high = _data[_offset + 1];
      _offset += 2;
      if (low == 0 && high == 0) break;
      codes.add(low | (high << 8));
    }
    // 跳过固定块中剩余字节
    _offset = end;
    return String.fromCharCodes(codes.where((c) => c != 0xcccc && c != 0));
  }

  /// 读取变长 UTF-16 LE 编码的字符串（以 null 结束）。
  String readUtf16Var() {
    final codes = <int>[];
    while (_offset < _data.length - 1) {
      final low = _data[_offset];
      final high = _data[_offset + 1];
      _offset += 2;
      if (low == 0 && high == 0) break;
      codes.add(low | (high << 8));
    }
    return String.fromCharCodes(codes);
  }
}

/// 顺序二进制写入器，小端序。
class BufferWriter {
  final _buffer = <int>[];

  void writeUint8(int v) => _buffer.add(v & 0xff);
  void writeInt8(int v) => _buffer.add(v & 0xff);

  void writeUint16(int v) {
    _buffer.add(v & 0xff);
    _buffer.add((v >> 8) & 0xff);
  }

  void writeInt16(int v) => writeUint16(v & 0xffff);

  void writeUint32(int v) {
    _buffer.add(v & 0xff);
    _buffer.add((v >> 8) & 0xff);
    _buffer.add((v >> 16) & 0xff);
    _buffer.add((v >> 24) & 0xff);
  }

  void writeInt32(int v) => writeUint32(v & 0xffffffff);

  void writeBytes(Uint8List data) => _buffer.addAll(data);
  void writeUint32List(List<int> list) {
    for (final v in list) writeUint32(v);
  }

  /// 写入 4 字节卡牌位置。
  ///
  /// - controller (u8): 控制者
  /// - location (u8): 区域标识（叠放时设置 LOCATION_OVERLAY 位）
  /// - sequence (u8): 序列号
  /// - ss (u8): 非叠放时为表示形式，叠放时为叠放序号
  void writeCardLocation(CardLocation loc) {
    final locationByte = loc.isOverlay ? (loc.location | LOCATION_OVERLAY) : loc.location;
    writeUint8(loc.controller);
    writeUint8(locationByte);
    writeUint8(loc.sequence);
    writeUint8(loc.isOverlay ? loc.overlaySequence : loc.position);
  }

  /// 写入 3 字节短卡牌位置（controller + location + sequence）。
  void writeCardShortLocation(CardShortLocation loc) {
    writeUint8(loc.controller);
    writeUint8(loc.location);
    writeUint8(loc.sequence);
  }

  /// 写入 7 字节卡牌信息（code: u32 + controller: u8 + location: u8 + sequence: u8）。
  void writeCardInfo(CardInfo info) {
    writeUint32(info.code);
    writeUint8(info.controller);
    writeUint8(info.location);
    writeUint8(info.sequence);
  }

  /// 写入定长 UTF-16 LE 字符串（最多 20 字符 / 40 字节）。
  ///
  /// 以 null 结束，剩余字节以 0xcccc 填充（与 ygopro 服务端一致）。
  void writeUtf16Fixed(String str) {
    final codes = str.codeUnits;
    for (int i = 0; i < 20; i++) {
      if (i < codes.length) {
        writeUint16(codes[i]);
      } else if (i == codes.length) {
        writeUint16(0); // null 结束符
      } else {
        writeUint16(0xcccc); // 填充
      }
    }
  }

  /// 写入变长 UTF-16 LE 字符串，以 null 结束。
  void writeUtf16Var(String str) {
    for (final c in str.codeUnits) {
      writeUint16(c);
    }
    writeUint16(0); // null 结束符
  }

  Uint8List toBytes() => Uint8List.fromList(_buffer);
}

/// 4 字节卡牌位置。
///
/// 当 [isOverlay] 为 true 时，[overlaySequence] 表示叠放序号，
/// 否则 [position] 表示卡牌表示形式。
class CardLocation {
  final int controller;
  final int location;
  final int sequence;
  final int position;
  final bool isOverlay;
  final int overlaySequence;

  const CardLocation({
    required this.controller,
    required this.location,
    required this.sequence,
    this.position = 0,
    this.isOverlay = false,
    this.overlaySequence = 0,
  });

  /// 原始协议中的 location 数字值。
  ///
  /// 当上层需要保留线协议值、做位运算、或排查未知区域编码时使用；
  /// 一般业务逻辑优先使用 [zone] / [zoneEnum]。
  int get rawLocation => location;

  /// [rawLocation] 的别名，便于和其他 message 上的 `*Code` getter 保持一致。
  int get zoneCode => location;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zone => zoneEnum;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneEnum => CardZone.of(location);

  /// 原始协议中的 position 数字值。
  ///
  /// 仅在非叠放位置有意义；若 [isOverlay] 为 true，该字节语义改为叠放序号。
  int get rawPosition => position;

  /// [rawPosition] 的别名，便于和其他 message 上的 `*Code` getter 保持一致。
  int get positionCode => position;

  /// 语义化的表示形式枚举，适合 UI/规则判断。
  CardPosition get cardPosition => positionEnum;

  /// 语义化的表示形式枚举，适合 UI/规则判断。
  CardPosition get positionEnum => CardPosition.of(position);

  @override
  bool operator ==(Object other) =>
      other is CardLocation &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence &&
      other.position == position &&
      other.isOverlay == isOverlay &&
      other.overlaySequence == overlaySequence;

  @override
  int get hashCode => Object.hash(controller, location, sequence, position, isOverlay, overlaySequence);

  @override
  String toString() => 'CardLocation(c:$controller l:$location s:$sequence p:$position)';
}

/// 3 字节短卡牌位置（controller + location + sequence）。
///
/// 不含表示形式/叠放信息，常用于只需要区域的场景。
class CardShortLocation {
  final int controller;
  final int location;
  final int sequence;

  const CardShortLocation({
    required this.controller,
    required this.location,
    required this.sequence,
  });

  /// 原始协议中的 location 数字值。
  int get rawLocation => location;

  /// [rawLocation] 的别名，便于与 message 上的辅助 getter 命名保持一致。
  int get zoneCode => location;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zone => zoneEnum;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneEnum => CardZone.of(location);

  @override
  bool operator ==(Object other) =>
      other is CardShortLocation &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(controller, location, sequence);
}

/// 7 字节卡牌信息（code: u32 + controller: u8 + location: u8 + sequence: u8）。
///
/// 一种紧凑的卡牌引用格式，常用于 select card 等交互中。
class CardInfo {
  final int code;
  final int controller;
  final int location;
  final int sequence;

  const CardInfo({
    required this.code,
    required this.controller,
    required this.location,
    required this.sequence,
  });

  /// 原始协议中的 location 数字值。
  int get rawLocation => location;

  /// [rawLocation] 的别名，便于与其他 message 的 helper getter 一致。
  int get zoneCode => location;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zone => zoneEnum;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneEnum => CardZone.of(location);

  @override
  bool operator ==(Object other) =>
      other is CardInfo &&
      other.code == code &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(code, controller, location, sequence);
}
