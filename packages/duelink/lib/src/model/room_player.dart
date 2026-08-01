/// 房间内玩家信息。
class RoomPlayer {
  /// 玩家昵称
  final String name;
  /// 座位号 (0-3)
  final int pos;
  /// 是否已准备
  final bool ready;
  /// 是否为房主
  final bool host;

  const RoomPlayer({required this.name, this.pos = 0, this.ready = false, this.host = false});

  RoomPlayer copyWith({String? name, int? pos, bool? ready, bool? host}) {
    return RoomPlayer(
      name: name ?? this.name,
      pos: pos ?? this.pos,
      ready: ready ?? this.ready,
      host: host ?? this.host,
    );
  }

  @override
  String toString() => 'RoomPlayer($name pos:$pos ready:$ready)';
}
