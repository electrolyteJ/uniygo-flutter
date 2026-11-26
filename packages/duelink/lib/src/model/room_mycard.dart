import 'dart:convert';
import 'dart:typed_data';

/// 房间操作类型（MyCard 密码 buffer[1] 的高 4 位）。
enum _RoomAction {
  createPublic(1),
  createPrivate(2),
  joinPublic(3),
  joinPrivate(5);

  final int value;
  const _RoomAction(this.value);
}

/// 建房密码解码结果（字段语义同 [MyCardRoomPassword.encodeCreate]）。
typedef MyCardCreatePassword = ({
  int mode,
  int duelRule,
  int rule,
  bool noCheckDeck,
  bool noShuffleDeck,
  bool autoDeath,
  int startLp,
  int startHand,
  int drawCount,
  String roomId,
  bool isPrivate,
});

/// 加入密码解码结果。
typedef MyCardJoinPassword = ({String roomId, bool isPrivate});

/// MyCard 服房间密码编解码 / 私房 ID 派生。
///
/// MyCard 的房间密码是 6 字节 buffer：按位写入动作位与房间规则参数，
/// 用 secret 做 XOR 校验加密后 Base64 编码，并在末尾拼接房间 ID，
/// 供 CTOS_JOIN_GAME 使用。对齐 neos-ts room.ts 与 YGOMobile MyCard.java
/// （createCustomRoomPassword / createPrivateRoomJoinPassword）。
///
/// 本 codec 与协议层 RoomOptions 解耦：入参是直接的游戏规则字段
/// （均按 ygopro 协议取值）。
class MyCardRoomPassword {
  /// 由 external_id 派生私密房 ID：external_id ^ 0x54321。
  ///
  /// 对齐 neos-ts getPrivateRoomID（src/api/mycard/room.ts）：MyCard 私密房
  /// 的房间 ID 固定由房主 external_id 派生，同一用户恒定；朋友输入这个数字
  /// ID 即可加入（配合 [encodeJoin] 的私密房编码）。
  static int derivePrivateRoomId(int externalId) => externalId ^ 0x54321;

  /// 编码建房密码（createPublic / createPrivate）。
  ///
  /// [mode] 0=单局 / 1=三局两胜 / 2=双打
  /// [duelRule] 3=MR3 / 4=MR4 / 5=MR2020
  /// [rule] 0=OCG / 1=TCG / 2=OT 混 / 4=专有卡禁止
  /// [roomId] 房间 ID 字符串（私密房传 [derivePrivateRoomId] 的结果）
  /// [secret] 加密密钥：优先使用 u16Secret（时间轮换密钥，**每次操作前需
  ///   重新获取**，见 account_mycard），没有则使用 external_id
  /// [isPrivate] 是否为私密房间（MyCard 建房固定为 true）
  static String encodeCreate({
    int mode = 1,
    int duelRule = 5,
    int rule = 0,
    bool noCheckDeck = false,
    bool noShuffleDeck = false,
    bool autoDeath = false,
    int startLp = 8000,
    int startHand = 5,
    int drawCount = 1,
    String roomId = '',
    int secret = 0,
    bool isPrivate = false,
  }) {
    final buf = Uint8List(6);
    buf[1] = ((isPrivate
                ? _RoomAction.createPrivate.value
                : _RoomAction.createPublic.value) <<
            4) |
        (duelRule << 1) |
        (autoDeath ? 0x1 : 0);

    buf[2] = (rule << 5) |
        (mode << 3) |
        (noCheckDeck ? 1 << 1 : 0) |
        (noShuffleDeck ? 1 : 0);

    _writeUint16LE(buf, 3, startLp);
    buf[5] = (startHand << 4) | drawCount;

    _encrypt(buf, secret);
    return base64Encode(buf) + roomId;
  }

  /// 编码加入密码（joinPublic / joinPrivate）。
  ///
  /// [roomId] 朋友告知的私密房 ID（数字字符串，由房主 external_id 派生）
  /// [secret] 加密密钥，语义同 [encodeCreate]（优先 u16Secret）
  /// [isPrivate] MyCard 私密房固定为 true（joinPrivate=5）
  static String encodeJoin({
    String roomId = '',
    int secret = 0,
    bool isPrivate = false,
  }) {
    final buf = Uint8List(6);
    buf[1] = (isPrivate
            ? _RoomAction.joinPrivate.value
            : _RoomAction.joinPublic.value) <<
        4;
    _encrypt(buf, secret);
    // 对齐 neos-ts：房间 ID 中的空白替换为 BOM 后拼在密文末尾。
    final suffix = roomId.replaceFirst(RegExp(r'\s'), '\ufeff');
    return base64Encode(buf) + suffix;
  }

  // ── 解码 ──────────────────────────────────────────────────────────

  /// 解码建房密码（[encodeCreate] 的逆操作）；密钥/校验不匹配返回 null。
  static MyCardCreatePassword? tryParseCreatePassword(
    String password, {
    required int secret,
  }) {
    final decoded = _decode(password, secret);
    if (decoded == null) return null;
    final buf = decoded.buffer;
    final action = buf[1] >> 4;
    if (action != _RoomAction.createPublic.value &&
        action != _RoomAction.createPrivate.value) {
      return null;
    }
    return (
      mode: (buf[2] >> 3) & 0x3,
      duelRule: (buf[1] >> 1) & 0x7,
      rule: (buf[2] >> 5) & 0x7,
      noCheckDeck: ((buf[2] >> 1) & 0x1) == 1,
      noShuffleDeck: (buf[2] & 0x1) == 1,
      autoDeath: (buf[1] & 0x1) == 1,
      startLp: _readUint16LE(buf, 3),
      startHand: (buf[5] >> 4) & 0xF,
      drawCount: buf[5] & 0xF,
      roomId: decoded.roomId,
      isPrivate: action == _RoomAction.createPrivate.value,
    );
  }

  /// 解码加入密码（[encodeJoin] 的逆操作）；密钥/校验不匹配返回 null。
  static MyCardJoinPassword? tryParseJoinPassword(
    String password, {
    required int secret,
  }) {
    final decoded = _decode(password, secret);
    if (decoded == null) return null;
    final action = decoded.buffer[1] >> 4;
    if (action != _RoomAction.joinPublic.value &&
        action != _RoomAction.joinPrivate.value) {
      return null;
    }
    return (
      roomId: decoded.roomId.replaceAll('\ufeff', ' '),
      isPrivate: action == _RoomAction.joinPrivate.value,
    );
  }

  // ── 内部实现 ──────────────────────────────────────────────────────

  /// 拆解「6 字节密文 + 房间 ID 后缀」，还原明文 buffer 并校验校验和。
  static ({Uint8List buffer, String roomId})? _decode(
    String password,
    int secret,
  ) {
    final text = password.trim();
    if (text.length < 8) return null;
    final Uint8List buffer;
    try {
      buffer = base64Decode(text.substring(0, 8));
    } on FormatException {
      return null;
    }
    if (buffer.length != 6) return null;
    // 只做 XOR（不能复用 _encrypt：它会把校验和重新写进 buffer[0]）。
    final encryptSecret = (secret % 65535) + 1;
    for (var i = 0; i < buffer.length; i += 2) {
      _writeUint16LE(buffer, i, _readUint16LE(buffer, i) ^ encryptSecret);
    }
    var checksum = 0;
    for (var i = 1; i < buffer.length; i++) {
      checksum -= buffer[i] & 0xff;
    }
    if ((checksum & 0xff) != buffer[0]) return null;
    return (buffer: buffer, roomId: text.substring(8));
  }

  /// XOR 加密 6 字节 buffer（对齐 neos-ts encryptBuffer）。
  static void _encrypt(Uint8List buffer, int secret) {
    var checksum = 0;
    for (var i = 1; i < buffer.length; i++) {
      checksum -= buffer[i] & 0xff;
    }
    buffer[0] = checksum & 0xff;

    final encryptSecret = (secret % 65535) + 1;
    for (var i = 0; i < buffer.length; i += 2) {
      final value = _readUint16LE(buffer, i);
      _writeUint16LE(buffer, i, value ^ encryptSecret);
    }
  }

  static int _readUint16LE(Uint8List buffer, int offset) {
    return ((buffer[offset + 1] & 0xff) << 8) | (buffer[offset] & 0xff);
  }

  static void _writeUint16LE(Uint8List buffer, int offset, int value) {
    buffer[offset] = value & 0xff;
    buffer[offset + 1] = (value >> 8) & 0xff;
  }
}
