import 'dart:typed_data';
import '../constants.dart';
import 'ctos/ctos_player_info.dart';
import 'ctos/ctos_join_game.dart';
import 'ctos/ctos_update_deck.dart';
import 'ctos/ctos_hand_result.dart';
import 'ctos/ctos_tp_result.dart';
import 'ctos/ctos_game_msg_response.dart';
import 'ctos/ctos_chat.dart';
import 'ctos/ctos_hs_ready.dart';
import 'ctos/ctos_hs_not_ready.dart';
import 'ctos/ctos_hs_kick.dart';
import 'ctos/ctos_hs_start.dart';
import 'ctos/ctos_hs_to_duelist.dart';
import 'ctos/ctos_hs_to_observer.dart';
import 'ctos/ctos_time_confirm.dart';
import 'ctos/ctos_surrender.dart';

class YgoCtosMsg {
  final CtosPlayerInfo? playerInfo;
  final CtosJoinGame? joinGame;
  final CtosUpdateDeck? updateDeck;
  final CtosHandResult? handResult;
  final CtosTpResult? tpResult;
  final CtosGameMsgResponse? response;
  final CtosChat? chat;
  final CtosHsReady? hsReady;
  final CtosHsNotReady? hsNotReady;
  final CtosHsStart? hsStart;
  final CtosHsKick? hsKick;
  final CtosHsToDuelist? hsToDuelist;
  final CtosHsToObserver? hsToObserver;
  final CtosTimeConfirm? timeConfirm;
  final CtosSurrender? surrender;

  const YgoCtosMsg._({
    this.playerInfo,
    this.joinGame,
    this.updateDeck,
    this.handResult,
    this.tpResult,
    this.response,
    this.chat,
    this.hsReady,
    this.hsNotReady,
    this.hsStart,
    this.hsKick,
    this.hsToDuelist,
    this.hsToObserver,
    this.timeConfirm,
    this.surrender,
  });

  factory YgoCtosMsg.playerInfo(CtosPlayerInfo m) =>
      YgoCtosMsg._(playerInfo: m);
  factory YgoCtosMsg.joinGame(CtosJoinGame m) => YgoCtosMsg._(joinGame: m);
  factory YgoCtosMsg.updateDeck(CtosUpdateDeck m) =>
      YgoCtosMsg._(updateDeck: m);
  factory YgoCtosMsg.handResult(CtosHandResult m) =>
      YgoCtosMsg._(handResult: m);
  factory YgoCtosMsg.tpResult(CtosTpResult m) => YgoCtosMsg._(tpResult: m);
  factory YgoCtosMsg.response(CtosGameMsgResponse m) =>
      YgoCtosMsg._(response: m);
  factory YgoCtosMsg.chat(CtosChat m) => YgoCtosMsg._(chat: m);
  factory YgoCtosMsg.hsReady() =>
      YgoCtosMsg._(hsReady: const CtosHsReady());
  factory YgoCtosMsg.hsNotReady() =>
      YgoCtosMsg._(hsNotReady: const CtosHsNotReady());
  factory YgoCtosMsg.hsStart() =>
      YgoCtosMsg._(hsStart: const CtosHsStart());
  factory YgoCtosMsg.hsKick(int pos) =>
      YgoCtosMsg._(hsKick: CtosHsKick(pos: pos));
  factory YgoCtosMsg.hsToDuelist() =>
      YgoCtosMsg._(hsToDuelist: const CtosHsToDuelist());
  factory YgoCtosMsg.hsToObserver() =>
      YgoCtosMsg._(hsToObserver: const CtosHsToObserver());
  factory YgoCtosMsg.timeConfirm() =>
      YgoCtosMsg._(timeConfirm: const CtosTimeConfirm());
  factory YgoCtosMsg.surrender() =>
      YgoCtosMsg._(surrender: const CtosSurrender());

  int get protoId {
    if (playerInfo != null) return CTOS_PLAYER_INFO;
    if (joinGame != null) return CTOS_JOIN_GAME;
    if (updateDeck != null) return CTOS_UPDATE_DECK;
    if (handResult != null) return CTOS_HAND_RESULT;
    if (tpResult != null) return CTOS_TP_RESULT;
    if (response != null) return CTOS_RESPONSE;
    if (chat != null) return CTOS_CHAT;
    if (hsReady != null) return CTOS_HS_READY;
    if (hsNotReady != null) return CTOS_HS_NOT_READY;
    if (hsStart != null) return CTOS_HS_START;
    if (hsKick != null) return CTOS_HS_KICK;
    if (hsToDuelist != null) return CTOS_HS_TO_DUELIST;
    if (hsToObserver != null) return CTOS_HS_TO_OBSERVER;
    if (timeConfirm != null) return CTOS_TIME_CONFIRM;
    if (surrender != null) return CTOS_SURRENDER;
    return 0;
  }

  Uint8List encode() {
    if (playerInfo != null) return playerInfo!.encode();
    if (joinGame != null) return joinGame!.encode();
    if (updateDeck != null) return updateDeck!.encode();
    if (handResult != null) return handResult!.encode();
    if (tpResult != null) return tpResult!.encode();
    if (response != null) return response!.encode();
    if (chat != null) return chat!.encode();
    if (hsKick != null) return hsKick!.encode();
    return Uint8List(0);
  }

  static YgoCtosMsg decode(int protoId, Uint8List data) {
    switch (protoId) {
      case CTOS_PLAYER_INFO:
        return YgoCtosMsg.playerInfo(CtosPlayerInfo.decode(data));
      case CTOS_JOIN_GAME:
        return YgoCtosMsg.joinGame(CtosJoinGame.decode(data));
      case CTOS_UPDATE_DECK:
        return YgoCtosMsg.updateDeck(CtosUpdateDeck.decode(data));
      case CTOS_HAND_RESULT:
        return YgoCtosMsg.handResult(CtosHandResult.decode(data));
      case CTOS_TP_RESULT:
        return YgoCtosMsg.tpResult(CtosTpResult.decode(data));
      case CTOS_RESPONSE:
        return YgoCtosMsg.response(CtosGameMsgResponse.decode(data));
      case CTOS_CHAT:
        return YgoCtosMsg.chat(CtosChat.decode(data));
      case CTOS_HS_READY:
        return YgoCtosMsg.hsReady();
      case CTOS_HS_NOT_READY:
        return YgoCtosMsg.hsNotReady();
      case CTOS_HS_START:
        return YgoCtosMsg.hsStart();
      case CTOS_HS_KICK:
        return YgoCtosMsg.hsKick(CtosHsKick.decode(data).pos);
      case CTOS_HS_TO_DUELIST:
        return YgoCtosMsg.hsToDuelist();
      case CTOS_HS_TO_OBSERVER:
        return YgoCtosMsg.hsToObserver();
      case CTOS_TIME_CONFIRM:
        return YgoCtosMsg.timeConfirm();
      case CTOS_SURRENDER:
        return YgoCtosMsg.surrender();
      default:
        throw ArgumentError('Unknown CTOS protoId: $protoId');
    }
  }

  @override
  String toString() => 'YgoCtosMsg(protoId:$protoId)';
}
