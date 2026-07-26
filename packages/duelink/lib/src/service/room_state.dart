import 'package:duelink/src/service/room_options.dart';
import 'PlayerInfo.dart';

enum RoomStage {
  waiting,
  duelStart,
  handSelecting,
  handSelected,
  tpSelecting,
  tpSelected,
  dueling,
  duelEnd,
}

enum SelfType { unknown, player1, player2, observer }

class RoomState {
  final bool joined;
  final RoomStage stage;
  final SelfType selfType;
  final bool isHost;
  final List<PlayerInfo> players;
  final int observerCount;
  final RoomOptions? roomOptions;
  final int? myHandResult;
  final int? opponentHandResult;
  final bool? isFirstTurn;

  const RoomState({
    this.joined = false,
    this.stage = RoomStage.waiting,
    this.selfType = SelfType.unknown,
    this.isHost = false,
    this.players = const [],
    this.observerCount = 0,
    this.roomOptions,
    this.myHandResult,
    this.opponentHandResult,
    this.isFirstTurn,
  });

  RoomState copyWith({
    bool? joined,
    RoomStage? stage,
    SelfType? selfType,
    bool? isHost,
    List<PlayerInfo>? players,
    int? observerCount,
    RoomOptions? roomOptions,
    int? myHandResult,
    int? opponentHandResult,
    bool? isFirstTurn,
  }) {
    return RoomState(
      joined: joined ?? this.joined,
      stage: stage ?? this.stage,
      selfType: selfType ?? this.selfType,
      isHost: isHost ?? this.isHost,
      players: players ?? this.players,
      observerCount: observerCount ?? this.observerCount,
      roomOptions: roomOptions ?? this.roomOptions,
      myHandResult: myHandResult ?? this.myHandResult,
      opponentHandResult: opponentHandResult ?? this.opponentHandResult,
      isFirstTurn: isFirstTurn ?? this.isFirstTurn,
    );
  }

  @override
  String toString() => 'RoomState($stage joined:$joined host:$isHost)';
}
