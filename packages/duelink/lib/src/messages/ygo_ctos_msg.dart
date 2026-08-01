import 'dart:typed_data';
import '../constants.dart';

/// CtoS 消息的联合容器。
///
/// 每个工厂方法对应一种客户端到服务端的消息类型，
/// [protoId] 返回对应的协议标识号（见 constants.dart 中的 CTOS_* 常量）。
///
/// 参考 neos-ts 中 ocgAdapter/ctos/ 目录下的各个 CTOS 消息定义。

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

  // ---- 工厂构造函数 ----

  /// CTOS_PLAYER_INFO (16): 告知服务端当前玩家的昵称。
  factory YgoCtosMsg.playerInfo(CtosPlayerInfo m) =>
      YgoCtosMsg._(playerInfo: m);
  /// CTOS_JOIN_GAME (18): 加入房间。
  factory YgoCtosMsg.joinGame(CtosJoinGame m) => YgoCtosMsg._(joinGame: m);
  /// CTOS_UPDATE_DECK (2): 更新对局卡组信息。
  factory YgoCtosMsg.updateDeck(CtosUpdateDeck m) =>
      YgoCtosMsg._(updateDeck: m);
  /// CTOS_HAND_RESULT (3): 告知服务端当前玩家的猜拳选择。
  factory YgoCtosMsg.handResult(CtosHandResult m) =>
      YgoCtosMsg._(handResult: m);
  /// CTOS_TP_RESULT (4): 告知服务端当前玩家的先后攻选择。
  factory YgoCtosMsg.tpResult(CtosTpResult m) => YgoCtosMsg._(tpResult: m);
  /// CTOS_RESPONSE (1): 回复服务端的各种游戏内交互请求（选卡、选项、位置等）。
  factory YgoCtosMsg.response(CtosGameMsgResponse m) =>
      YgoCtosMsg._(response: m);
  /// CTOS_CHAT (22): 发送聊天消息。
  factory YgoCtosMsg.chat(CtosChat m) => YgoCtosMsg._(chat: m);
  /// CTOS_HS_READY (34): 告知服务端当前玩家准备完毕。
  factory YgoCtosMsg.hsReady() =>
      YgoCtosMsg._(hsReady: const CtosHsReady());
  /// CTOS_HS_NOT_READY (35): 告知服务端当前玩家取消准备。
  factory YgoCtosMsg.hsNotReady() =>
      YgoCtosMsg._(hsNotReady: const CtosHsNotReady());
  /// CTOS_HS_START (37): 开始游戏对局。
  factory YgoCtosMsg.hsStart() =>
      YgoCtosMsg._(hsStart: const CtosHsStart());
  /// CTOS_HS_KICK (36): 踢出指定位置的玩家。
  ///
  /// 这是原始 ygopro 二进制协议里的房间管理消息，`ocgcore.proto` 当前未建模。
  factory YgoCtosMsg.hsKick(int pos) =>
      YgoCtosMsg._(hsKick: CtosHsKick(pos: pos));
  /// CTOS_HS_TO_DUELIST (32): 告知服务端当前玩家进入决斗者行列。
  ///
  /// 命名差异：原始协议常叫 `HsToDuelist`，而 `ocgcore.proto` / `neos-ts`
  /// 中的 protobuf 语义名是 `CtosHsToDuelList`。两者协议号相同。
  factory YgoCtosMsg.hsToDuelist() =>
      YgoCtosMsg._(hsToDuelist: const CtosHsToDuelist());
  /// CTOS_HS_TO_OBSERVER (33): 告知服务端当前玩家进入观战者行列。
  factory YgoCtosMsg.hsToObserver() =>
      YgoCtosMsg._(hsToObserver: const CtosHsToObserver());
  /// CTOS_TIME_CONFIRM (21): 确认计时。
  factory YgoCtosMsg.timeConfirm() =>
      YgoCtosMsg._(timeConfirm: const CtosTimeConfirm());
  /// CTOS_SURRENDER (20 / 0x14): 告知服务端当前玩家投降。
  factory YgoCtosMsg.surrender() =>
      YgoCtosMsg._(surrender: const CtosSurrender());

  /// 从非空字段反查协议标识号。
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

  bool get isPlayerInfo => playerInfo != null;

  bool get isJoinGame => joinGame != null;

  bool get isUpdateDeck => updateDeck != null;

  bool get isHandResult => handResult != null;

  bool get isTpResult => tpResult != null;

  bool get isResponse => response != null;

  bool get isChat => chat != null;

  bool get isHsReady => hsReady != null;

  bool get isHsNotReady => hsNotReady != null;

  bool get isHsStart => hsStart != null;

  bool get isHsKick => hsKick != null;

  bool get isHsToDuelist => hsToDuelist != null;

  bool get isHsToObserver => hsToObserver != null;

  bool get isTimeConfirm => timeConfirm != null;

  bool get isSurrender => surrender != null;

  String get variantType {
    if (isPlayerInfo) return 'playerInfo';
    if (isJoinGame) return 'joinGame';
    if (isUpdateDeck) return 'updateDeck';
    if (isHandResult) return 'handResult';
    if (isTpResult) return 'tpResult';
    if (isResponse) return 'response';
    if (isChat) return 'chat';
    if (isHsReady) return 'hsReady';
    if (isHsNotReady) return 'hsNotReady';
    if (isHsStart) return 'hsStart';
    if (isHsKick) return 'hsKick';
    if (isHsToDuelist) return 'hsToDuelist';
    if (isHsToObserver) return 'hsToObserver';
    if (isTimeConfirm) return 'timeConfirm';
    if (isSurrender) return 'surrender';
    return 'unknown';
  }

  /// 编码为网络传输格式的字节数组。
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

  /// 从原始字节数据中解码（通常在调试/回放时使用）。
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
