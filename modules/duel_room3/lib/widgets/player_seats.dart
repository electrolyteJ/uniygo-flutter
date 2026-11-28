import 'package:biz/duel/field/duel_field_state.dart' show teamOfSeat;
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' show PlayerInfo;

/// 等待阶段左右两侧的玩家席位（与大厅同一套 pos%2 分队规则）。
class PlayerSeats {
  const PlayerSeats({
    required this.selfSeat,
    required this.left,
    required this.right,
  });

  final int? selfSeat;
  final List<PlayerInfo> left;
  final List<PlayerInfo> right;

  factory PlayerSeats.of(DuelRoomState room) {
    final selfSeat = room.selfType.isDuelist ? room.selfType.slot : null;
    final leftTeam = selfSeat == null ? 0 : teamOfSeat(selfSeat);
    return PlayerSeats(
      selfSeat: selfSeat,
      left: _sideSeats(room, leftTeam, selfFirst: selfSeat),
      right: _sideSeats(room, 1 - leftTeam),
    );
  }

  static List<PlayerInfo> _sideSeats(
    DuelRoomState room,
    int team, {
    int? selfFirst,
  }) {
    final seats = <PlayerInfo>[
      for (final p in room.players)
        if (p.pos >= 0 && p.pos <= 3 && teamOfSeat(p.pos) == team) p,
    ]..sort((a, b) => a.pos.compareTo(b.pos));
    if (selfFirst == null) return seats;
    final mineIndex = seats.indexWhere((p) => p.pos == selfFirst);
    if (mineIndex > 0) {
      final mine = seats.removeAt(mineIndex);
      seats.insert(0, mine);
    }
    return seats;
  }
}
