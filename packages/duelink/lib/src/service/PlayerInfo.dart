class PlayerInfo {
  final String name;
  final int pos;
  final bool ready;

  const PlayerInfo({required this.name, this.pos = 0, this.ready = false});

  PlayerInfo copyWith({String? name, int? pos, bool? ready}) {
    return PlayerInfo(
      name: name ?? this.name,
      pos: pos ?? this.pos,
      ready: ready ?? this.ready,
    );
  }

  @override
  String toString() => 'PlayerInfo($name pos:$pos ready:$ready)';
}
