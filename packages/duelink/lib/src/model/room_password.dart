import 'dart:convert';
import 'dart:typed_data';
import 'room_options.dart';
import 'room_tokens.dart';

/// 房间操作类型
enum _RoomAction {
  createPublic(1),
  createPrivate(2),
  joinPublic(3),
  joinPrivate(5);

  final int value;
  const _RoomAction(this.value);
}

/// 房间密码编码工具。
///
/// 对齐 neos-ts room.ts，将房间参数编码为 6 字节 buffer，
/// XOR 加密后 Base64 编码，供 CTOS_JOIN_GAME 使用。
class RoomPassword {
  /// MyCard 私密房间 ID 派生：external_id ^ 0x54321。
  ///
  /// 对齐 neos-ts getPrivateRoomID（src/api/mycard/room.ts）：MyCard 私密房
  /// 的房间 ID 固定由房主 external_id 派生，同一用户恒定；朋友输入这个数字
  /// ID 即可加入（配合 joinPrivate 编码密码）。
  static int privateRoomId(int externalId) => externalId ^ 0x54321;

  /// 编码创建房间密码。
  ///
  /// [options] 房间规则参数
  /// [roomId] 房间 ID 字符串（MyCard 私密房为 [privateRoomId] 派生的数字 ID）
  /// [secret] 加密密钥：优先使用 u16Secret（时间轮换密钥，**每次操作前需
  ///   重新获取**，见 account_mycard），没有则使用 external_id
  ///   （neos-ts room.ts:22 的 secret 语义注释）
  /// [isPrivate] 是否为私密房间（MyCard 建房固定为 true）
  static String encodeCreate({
    required RoomOptions options,
    String roomId = '',
    int secret = 0,
    bool isPrivate = false,
  }) {
    final buf = Uint8List(6);
    buf[1] = ((isPrivate ? _RoomAction.createPrivate.value : _RoomAction.createPublic.value) << 4) |
        (options.duelRule.value << 1) |
        (options.autoDeath ? 0x1 : 0);

    buf[2] = (options.rule << 5) |
        (options.mode.value << 3) |
        (options.noCheckDeck ? 1 << 1 : 0) |
        (options.noShuffleDeck ? 1 : 0);

    _writeUint16LE(buf, 3, options.startLp);
    buf[5] = (options.startHand << 4) | options.drawCount;

    _encrypt(buf, secret);
    final b64 = base64Encode(buf);
    return '$b64$roomId';
  }

  /// 编码加入房间密码。
  ///
  /// [roomId] 朋友告知的私密房间 ID（数字字符串，由房主 external_id 派生）
  /// [secret] 加密密钥，语义同 [encodeCreate]（优先 u16Secret）
  /// [isPrivate] MyCard 私密房固定为 true（joinPrivate=5）
  static String encodeJoin({
    String roomId = '',
    int secret = 0,
    bool isPrivate = false,
  }) {
    final buf = Uint8List(6);
    buf[1] = (isPrivate ? _RoomAction.joinPrivate.value : _RoomAction.joinPublic.value) << 4;
    _encrypt(buf, secret);
    String suffix = roomId.replaceFirst("\\s", "\ufeff");
    final b64 = base64Encode(buf);
    return '$b64$suffix';
  }

  // ── 233 服（明文房间串）────────────────────────────────────────────

  /// 233 服房间串最大长度（服务器解析上限，超出会被拒绝）。
  static const int mercury233MaxLength = 20;

  /// 编码 233 服建房密码（房间串）。
  ///
  /// 233 服的「密码」不是加密 buffer，而是明文房间串
  /// `MR5,LP4000,NC#房间名`：服务器按串解析房间规则，同一串即同一间房，
  /// 因此它同时是建房凭证与加入凭证（好友复制粘贴即可）。
  ///
  /// token 由 [RoomTokens.build] 生成——与 AI 主机密码共用同一套定义，
  /// 不在别处手拼；禁限 token（LF<n>/NF）不属于 [RoomOptions]（协议层只有
  /// lflist hash），由 [banlistToken] 传入并按顺序插在 DR 之后。
  /// 没有任何 token 时只返回房间名（单局 + 默认规则的最短形态）。
  ///
  /// 空房间名、超长截断属展示层文案，调用方用 [mercury233MaxLength] 判断。
  static String encodeMercury233({
    required RoomOptions options,
    String roomName = '',
    String banlistToken = '',
  }) {
    final tokens = RoomTokens.build(options, banlistToken: banlistToken);
    final name = roomName.trim();
    return tokens.isEmpty ? name : '${tokens.join(',')}#$name';
  }

  /// XOR 加密 6 字节 buffer（对齐 neos-ts encryptBuffer）
  static void _encrypt(Uint8List buffer, int secret) {
    int checksum = 0;
    for (int i = 1; i < buffer.length; i++) {
      checksum -= buffer[i] & 0xff;
    }
    buffer[0] = checksum & 0xff;

    final encryptSecret = (secret % 65535) + 1;
    for (int i = 0; i < buffer.length; i += 2) {
      final value = _readUint16LE(buffer, i);
      final xorResult = value ^ encryptSecret;
      _writeUint16LE(buffer, i, xorResult);
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
