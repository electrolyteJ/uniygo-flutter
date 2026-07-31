/// 房间内玩家信息。
class RoomPlayer {
  /// 玩家昵称
  final String name;
  /// 座位号 (0-3)
  final int pos;
  /// 是否已准备
  final bool ready;

  const RoomPlayer({required this.name, this.pos = 0, this.ready = false});

  RoomPlayer copyWith({String? name, int? pos, bool? ready}) {
    return RoomPlayer(
      name: name ?? this.name,
      pos: pos ?? this.pos,
      ready: ready ?? this.ready,
    );
  }

  @override
  String toString() => 'RoomPlayer($name pos:$pos ready:$ready)';
}
