import '../../duelink.dart';

/// 房间内玩家信息。
class PlayerInfo {
  /// 玩家昵称
  final String name;
  /// 座位号 (0-3)
  final int pos;
  /// 是否已准备
  final bool ready;
  /// 是否为房主
  final bool host;

  const PlayerInfo({required this.name, this.pos = 0, this.ready = false, this.host = false});

  PlayerInfo copyWith({String? name, int? pos, bool? ready, bool? host}) {
    return PlayerInfo(
      name: name ?? this.name,
      pos: pos ?? this.pos,
      ready: ready ?? this.ready,
      host: host ?? this.host,
    );
  }

  @override
  String toString() => 'RoomPlayer($name pos:$pos ready:$ready)';
}

/// 玩家在房间中的身份。
enum PlayerType {
  unknown(-1),
  player1(0),
  player2(1),
  observer(7);

  final int slot;

  const PlayerType(this.slot);

  static PlayerType of(int value) {
    switch (value) {
      case 0:
        return PlayerType.player1;
      case 1:
        return PlayerType.player2;
      case 7:
        return PlayerType.observer;
      default:
        return PlayerType.unknown;
    }
  }
}
enum PlayerChange {
  unknown,
  move,
  ready,
  notReady,
  leave,
  toObserver;

  static PlayerChange of(int action) {
    switch (action) {
      case HS_PLAYER_STATE_MOVE:
        return PlayerChange.move;
      case HS_PLAYER_STATE_READY:
      case 9:
        return PlayerChange.ready;
      case HS_PLAYER_STATE_NO_READY:
      case 10:
        return PlayerChange.notReady;
      case HS_PLAYER_STATE_LEAVE:
      case 11:
        return PlayerChange.leave;
      case HS_PLAYER_STATE_TO_OBSERVER:
      case 8:
        return PlayerChange.toObserver;
      default:
        return PlayerChange.unknown;
    }
  }
}


