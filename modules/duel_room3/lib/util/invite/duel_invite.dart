/// 房间邀请的深链编解码（等候厅二维码 / 扫码加入共用）。
library;

/// 一次邀请：房间邀码 + 可选的房主服务器提示。
///
/// 深链：`uniygo://duel?room=<邀码>&h=<host>&p=<port>`
/// - `room` 必填：MyCard 为派生私密房 ID，233 为房间串（`token#房名`），
///   408 为 6 位邀码。
/// - `h`/`p` 可选：房主所连服务器地址，扫码方据此选出同一环境再进房；
///   老二维码只有 `room`，解析时允许缺失。
class DuelInvite {
  const DuelInvite({required this.roomId, this.host, this.port});

  /// 邀码：进房凭证（233 房间串本身即完整凭证）。
  final String roomId;

  /// 房主所在服务器 host（可选，用于推断环境）。
  final String? host;

  /// 房主所在服务器端口（可选）。
  final int? port;

  static const String scheme = 'uniygo';
  static const String linkHost = 'duel';

  /// 裸邀码长度上限：233 房间串最长 20，MyCard/408 为纯数字。
  static const int maxRoomIdLength = 64;

  /// 是否带了服务器提示（可用于精确匹配环境）。
  bool get hasServerHint => host != null && port != null;

  /// 生成深链；[host]/[port] 有值时写入，扫码方可用它推断环境。
  static String buildLink(String roomId, {String? host, int? port}) {
    final params = <String, String>{'room': roomId};
    if (host != null && host.isNotEmpty) params['h'] = host;
    if (port != null && port > 0) params['p'] = '$port';
    return Uri(
      scheme: scheme,
      host: linkHost,
      queryParameters: params,
    ).toString();
  }

  /// 解析扫码 / 粘贴到的文本，无法识别返回 null。
  ///
  /// 支持三种输入：
  /// - 深链 `uniygo://duel?room=...&h=...&p=...`（也接受任意带 `room` 查询参数的链接）
  /// - 裸邀码：`462890`
  /// - 233 房间串：`M,MR5#BO3-123456`
  static DuelInvite? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    if (text.contains('://')) {
      final uri = Uri.tryParse(text);
      final room = uri?.queryParameters['room']?.trim();
      if (room == null || room.isEmpty) return null;
      final host = uri!.queryParameters['h']?.trim();
      final port = int.tryParse(uri.queryParameters['p']?.trim() ?? '');
      return DuelInvite(
        roomId: room,
        host: (host == null || host.isEmpty) ? null : host,
        port: (port == null || port <= 0) ? null : port,
      );
    }

    if (text.length > maxRoomIdLength) return null;
    return DuelInvite(roomId: text);
  }

  @override
  String toString() => 'DuelInvite(room: $roomId, host: $host, port: $port)';
}
