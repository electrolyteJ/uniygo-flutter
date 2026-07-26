import 'dart:typed_data';
import '../constants.dart';
import 'stoc/stoc_join_game.dart';
import 'stoc/stoc_type_change.dart';
import 'stoc/stoc_hs_player_enter.dart';
import 'stoc/stoc_hs_player_change.dart';
import 'stoc/stoc_hs_watch_change.dart';
import 'stoc/stoc_chat.dart';
import 'stoc/stoc_hand_result.dart';
import 'stoc/stoc_select_hand.dart';
import 'stoc/stoc_select_tp.dart';
import 'stoc/stoc_deck_count.dart';
import 'stoc/stoc_duel_start.dart';
import 'stoc/stoc_duel_end.dart';
import 'stoc/stoc_time_limit.dart';
import 'stoc/stoc_error_msg.dart';
import 'stoc/stoc_change_side.dart';
import 'stoc/stoc_waiting_side.dart';
import 'stoc/stoc_game_msg.dart';

class YgoStocMsg {
  final StocJoinGame? joinGame;
  final StocChat? chat;
  final StocHsPlayerEnter? hsPlayerEnter;
  final StocTypeChange? typeChange;
  final StocHsPlayerChange? hsPlayerChange;
  final StocHsWatchChange? hsWatchChange;
  final StocSelectHand? selectHand;
  final StocHandResult? handResult;
  final StocSelectTp? selectTp;
  final StocDeckCount? deckCount;
  final StocDuelStart? duelStart;
  final StocGameMessage? gameMsg;
  final StocTimeLimit? timeLimit;
  final StocErrorMsg? errorMsg;
  final StocChangeSide? changeSide;
  final StocWaitingSide? waitingSide;
  final StocDuelEnd? duelEnd;

  const YgoStocMsg._({
    this.joinGame,
    this.chat,
    this.hsPlayerEnter,
    this.typeChange,
    this.hsPlayerChange,
    this.hsWatchChange,
    this.selectHand,
    this.handResult,
    this.selectTp,
    this.deckCount,
    this.duelStart,
    this.gameMsg,
    this.timeLimit,
    this.errorMsg,
    this.changeSide,
    this.waitingSide,
    this.duelEnd,
  });

  factory YgoStocMsg.joinGame(StocJoinGame m) => YgoStocMsg._(joinGame: m);
  factory YgoStocMsg.chat(StocChat m) => YgoStocMsg._(chat: m);
  factory YgoStocMsg.hsPlayerEnter(StocHsPlayerEnter m) =>
      YgoStocMsg._(hsPlayerEnter: m);
  factory YgoStocMsg.typeChange(StocTypeChange m) =>
      YgoStocMsg._(typeChange: m);
  factory YgoStocMsg.hsPlayerChange(StocHsPlayerChange m) =>
      YgoStocMsg._(hsPlayerChange: m);
  factory YgoStocMsg.hsWatchChange(StocHsWatchChange m) =>
      YgoStocMsg._(hsWatchChange: m);
  factory YgoStocMsg.selectHand() =>
      YgoStocMsg._(selectHand: const StocSelectHand());
  factory YgoStocMsg.handResult(StocHandResult m) =>
      YgoStocMsg._(handResult: m);
  factory YgoStocMsg.selectTp() =>
      YgoStocMsg._(selectTp: const StocSelectTp());
  factory YgoStocMsg.deckCount(StocDeckCount m) =>
      YgoStocMsg._(deckCount: m);
  factory YgoStocMsg.duelStart() =>
      YgoStocMsg._(duelStart: const StocDuelStart());
  factory YgoStocMsg.gameMsg(StocGameMessage m) =>
      YgoStocMsg._(gameMsg: m);
  factory YgoStocMsg.timeLimit(StocTimeLimit m) =>
      YgoStocMsg._(timeLimit: m);
  factory YgoStocMsg.errorMsg(StocErrorMsg m) =>
      YgoStocMsg._(errorMsg: m);
  factory YgoStocMsg.changeSide() =>
      YgoStocMsg._(changeSide: const StocChangeSide());
  factory YgoStocMsg.waitingSide() =>
      YgoStocMsg._(waitingSide: const StocWaitingSide());
  factory YgoStocMsg.duelEnd() =>
      YgoStocMsg._(duelEnd: const StocDuelEnd());

  int get protoId {
    if (joinGame != null) return STOC_JOIN_GAME;
    if (chat != null) return STOC_CHAT;
    if (hsPlayerEnter != null) return STOC_HS_PLAYER_ENTER;
    if (typeChange != null) return STOC_TYPE_CHANGE;
    if (hsPlayerChange != null) return STOC_HS_PLAYER_CHANGE;
    if (hsWatchChange != null) return STOC_HS_WATCH_CHANGE;
    if (selectHand != null) return STOC_SELECT_HAND;
    if (handResult != null) return STOC_HAND_RESULT;
    if (selectTp != null) return STOC_SELECT_TP;
    if (deckCount != null) return STOC_DECK_COUNT;
    if (duelStart != null) return STOC_DUEL_START;
    if (gameMsg != null) return STOC_GAME_MSG;
    if (timeLimit != null) return STOC_TIME_LIMIT;
    if (errorMsg != null) return STOC_ERROR_MSG;
    if (changeSide != null) return STOC_CHANGE_SIDE;
    if (waitingSide != null) return STOC_WAITING_SIDE;
    if (duelEnd != null) return STOC_DUEL_END;
    return 0;
  }

  Uint8List encode() {
    if (joinGame != null) return joinGame!.encode();
    if (chat != null) return chat!.encode();
    if (hsPlayerEnter != null) return hsPlayerEnter!.encode();
    if (typeChange != null) return typeChange!.encode();
    if (hsPlayerChange != null) return hsPlayerChange!.encode();
    if (hsWatchChange != null) return hsWatchChange!.encode();
    if (handResult != null) return handResult!.encode();
    if (deckCount != null) return deckCount!.encode();
    if (gameMsg != null) return gameMsg!.encode();
    if (timeLimit != null) return timeLimit!.encode();
    if (errorMsg != null) return errorMsg!.encode();
    return Uint8List(0);
  }

  static YgoStocMsg decode(int protoId, Uint8List data) {
    switch (protoId) {
      case STOC_JOIN_GAME:
        return YgoStocMsg.joinGame(StocJoinGame.decode(data));
      case STOC_CHAT:
        return YgoStocMsg.chat(StocChat.decode(data));
      case STOC_HS_PLAYER_ENTER:
        return YgoStocMsg.hsPlayerEnter(StocHsPlayerEnter.decode(data));
      case STOC_TYPE_CHANGE:
        return YgoStocMsg.typeChange(StocTypeChange.decode(data));
      case STOC_HS_PLAYER_CHANGE:
        return YgoStocMsg.hsPlayerChange(StocHsPlayerChange.decode(data));
      case STOC_HS_WATCH_CHANGE:
        return YgoStocMsg.hsWatchChange(StocHsWatchChange.decode(data));
      case STOC_SELECT_HAND:
        return YgoStocMsg.selectHand();
      case STOC_HAND_RESULT:
        return YgoStocMsg.handResult(StocHandResult.decode(data));
      case STOC_SELECT_TP:
        return YgoStocMsg.selectTp();
      case STOC_DECK_COUNT:
        return YgoStocMsg.deckCount(StocDeckCount.decode(data));
      case STOC_DUEL_START:
        return YgoStocMsg.duelStart();
      case STOC_GAME_MSG:
        return YgoStocMsg.gameMsg(StocGameMessage.decode(data));
      case STOC_TIME_LIMIT:
        return YgoStocMsg.timeLimit(StocTimeLimit.decode(data));
      case STOC_ERROR_MSG:
        return YgoStocMsg.errorMsg(StocErrorMsg.decode(data));
      case STOC_CHANGE_SIDE:
        return YgoStocMsg.changeSide();
      case STOC_WAITING_SIDE:
        return YgoStocMsg.waitingSide();
      case STOC_DUEL_END:
        return YgoStocMsg.duelEnd();
      default:
        return YgoStocMsg._();
    }
  }

  @override
  String toString() => 'YgoStocMsg(protoId:$protoId)';
}
