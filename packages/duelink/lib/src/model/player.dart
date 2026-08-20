import '../../duelink.dart';

/// 房间内玩家信息。
class PlayerInfo {
  /// 玩家昵称
  final String name;
  /// 座位号 (0-3)
  final int pos;
  /// 是否已准备
  final bool ready;

  /// 是否为房主。
  ///
  /// YGOPro 协议没有对局内的房主标识信号（STOC_TYPE_CHANGE 的 isHost
  /// 只描述自己），该字段由 `BaseDuelService._onPlayerEnter` 按
  /// 「座位 0 == 建房者/房主」的惯例填充（`host: pos == 0`）。
  /// 局限：房主中途离开后服务器可能静默转移房主且不通知客户端，
  /// 此字段可能过期；消费方如需稳妥可自行保留 pos==0 兜底。
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

  /// tag（双打）模式的 2/3 号决斗位。YGOPro 协议在 tag 模式下
  /// 直接以下标 2/3 上报座位，曾落入 [unknown] 导致这两个座位
  /// 被各 UI 误判为非决斗者。
  player3(2),
  player4(3),
  observer(7);

  final int slot;

  const PlayerType(this.slot);

  /// 是否为决斗位（非观战、非未知）。
  bool get isDuelist =>
      this == PlayerType.player1 ||
      this == PlayerType.player2 ||
      this == PlayerType.player3 ||
      this == PlayerType.player4;

  static PlayerType of(int value) {
    switch (value) {
      case 0:
        return PlayerType.player1;
      case 1:
        return PlayerType.player2;
      case 2:
        return PlayerType.player3;
      case 3:
        return PlayerType.player4;
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


