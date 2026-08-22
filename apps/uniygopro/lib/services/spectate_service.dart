import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:duelink/duelink.dart' show RoomMode;
import 'package:duelink_websocket/duelink_websocket.dart' show WebSocketConnection;
import 'package:web_socket_channel/web_socket_channel.dart';

/// 观战房间里的一名玩家。
class SpectatePlayer {
  final String username;
  final int position;

  const SpectatePlayer({required this.username, required this.position});

  factory SpectatePlayer.fromJson(Map<String, dynamic> json) => SpectatePlayer(
        username: json['username'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? -1,
      );
}

/// 一个正在进行中的观战房间。
class SpectateRoom {
  final String id;
  final String title;
  final List<SpectatePlayer> users;

  /// 对战模式（复用 duelink 的 [RoomMode]）。
  final RoomMode mode;

  const SpectateRoom({
    required this.id,
    required this.title,
    required this.users,
    required this.mode,
  });

  factory SpectateRoom.fromJson(Map<String, dynamic> json) {
    final users = (json['users'] as List? ?? const [])
        .map((u) => SpectatePlayer.fromJson(u as Map<String, dynamic>))
        .toList();
    final options = json['options'] as Map<String, dynamic>? ?? const {};
    return SpectateRoom(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      users: users,
      mode: RoomMode.of((options['mode'] as num?)?.toInt() ?? 0),
    );
  }

  /// 模式展示名。
  String get modeLabel => switch (mode) {
        RoomMode.match => '比赛',
        RoomMode.tag => '双打',
        RoomMode.single => '单局',
      };

  /// 玩家对局标签（按座位号排序；1v1 为「A vs B」，2v2 为「A·B vs C·D」）。
  String get playersLabel {
    final sorted = [...users]..sort((a, b) => a.position.compareTo(b.position));
    final names = sorted
        .map((u) => u.username.isEmpty ? '?' : u.username)
        .toList(growable: false);
    if (names.length == 2) return '${names[0]}  vs  ${names[1]}';
    if (names.length == 4) {
      return '${names[0]}·${names[1]}  vs  ${names[2]}·${names[3]}';
    }
    return names.isEmpty ? '(空)' : names.join(' · ');
  }
}

/// 观战列表 WebSocket 客户端。
///
/// 连到 wss://host:port/?filter=started，服务端推送事件：
/// - init：连接后收到全量房间列表
/// - create：新房间创建
/// - update：房间状态变更
/// - delete：房间结束/删除
///
/// 对外以 [rooms] 暴露实时列表（本类为 [ChangeNotifier]，供 UI 订阅）。
class SpectateService extends ChangeNotifier {
  final String host;
  final int port;

  SpectateService({required this.host, required this.port});
  WebSocketChannel? _conn;
  bool _connecting = false;

  final List<SpectateRoom> _rooms = [];

  /// 当前房间列表（只读视图）。
  List<SpectateRoom> get rooms => List.unmodifiable(_rooms);

  /// 连接错误信息；null 表示无错误。
  String? error;

  bool get isConnecting => _connecting;

  Uri get _uri => Uri.parse('wss://$host:$port/?filter=started');

  /// 建立连接并开始接收事件；重复调用为无操作。
  void connect() {
    if (_conn != null) return;
    _connecting = true;
    error = null;
    notifyListeners();
    _conn = WebSocketChannel.connect(_uri);
    _conn?.ready.then((_) {
      _connecting = false;
      notifyListeners();
      _conn?.stream.listen(
            (data) {
          if (data is String) {
            _onMessage(data);
          } else {
            _onError('Unexpected data type: ${data.runtimeType}');
          }
        },
        onError: (Object e) => _onError('$e'),
        onDone: _onDone,
      );
    }).catchError((e) {
      _onError('Connection failed: $e');
    });

  }

  void _onMessage(String data) {
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final event = map['event'] as String? ?? '';
      final payload = map['data'];
      switch (event) {
        case 'init':
          _rooms
            ..clear()
            ..addAll(_parseList(payload));
          break;
        case 'create':
          final room = _parseRoom(payload);
          if (room != null) _rooms.insert(0, room);
          break;
        case 'update':
          final room = _parseRoom(payload);
          if (room != null) {
            final i = _rooms.indexWhere((r) => r.id == room.id);
            if (i >= 0) _rooms[i] = room;
          }
          break;
        case 'delete':
          final id = payload is Map<String, dynamic> ? payload['id'] : payload;
          _rooms.removeWhere((r) => r.id == id);
          break;
      }
      _connecting = false;
      notifyListeners();
    } catch (_) {
      // 单条坏消息不应拖垮整个列表。
    }
  }

  List<SpectateRoom> _parseList(dynamic data) {
    if (data is! List) return const [];
    return data.map(_parseRoom).whereType<SpectateRoom>().toList();
  }

  SpectateRoom? _parseRoom(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    return SpectateRoom.fromJson(data);
  }

  void _onError(String message) {
    _connecting = false;
    error = message;
    notifyListeners();
  }

  void _onDone() {
    _connecting = false;
    _conn = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _conn?.sink.close();
    _conn = null;
    super.dispose();
  }
}