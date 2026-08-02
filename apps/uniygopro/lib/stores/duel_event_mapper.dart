import 'package:duelink/duelink.dart';

import '../models/duel_event.dart';

class DuelEventMapper {
  const DuelEventMapper();

  DuelEvent? map(YgoStocMsg msg) {
    final gameMsg = msg.gameMsg;
    if (gameMsg == null || gameMsg.innerMsg == null) {
      return const DuelIgnoredEvent('No game message payload');
    }
    final innerMsg = gameMsg.innerMsg as Object;
    switch (gameMsg.func) {
      case MSG_START:
      case MSG_NEW_TURN:
      case MSG_NEW_PHASE:
      case MSG_WAITING:
      case MSG_ATTACK:
      case MSG_DAMAGE:
      case MSG_PAY_LP_COST:
      case MSG_CHAINING:
      case MSG_CHAIN_END:
      case MSG_SUMMONING:
      case MSG_BATTLE:
      case MSG_HINT:
      case MSG_WIN:
        return DuelFlowMessageEvent(func: gameMsg.func, innerMsg: innerMsg);
      case MSG_DRAW:
      case MSG_UPDATE_DATA:
      case MSG_UPDATE_CARD:
      case MSG_RELOAD_FIELD:
      case MSG_MOVE:
      case MSG_FIELD_DISABLED:
      case MSG_POS_CHANGE:
      case MSG_SHUFFLE_HAND:
      case MSG_SET:
        return DuelBoardMessageEvent(func: gameMsg.func, innerMsg: innerMsg);
      case MSG_SELECT_IDLE_CMD:
      case MSG_SELECT_BATTLE_CMD:
      case MSG_SELECT_CARD:
      case MSG_SELECT_CHAIN:
      case MSG_SELECT_EFFECTYN:
      case MSG_SELECT_YES_NO:
      case MSG_SELECT_PLACE:
      case MSG_SELECT_POSITION:
      case MSG_SELECT_TRIBUTE:
      case MSG_SELECT_COUNTER:
      case MSG_SELECT_SUM:
      case MSG_SORT_CARD:
      case MSG_SELECT_OPTION:
      case MSG_SELECT_UNSELECT_CARD:
      case MSG_SELECT_DISFIELD:
        return DuelSelectionMessageEvent(func: gameMsg.func, innerMsg: innerMsg);
      default:
        return DuelFlowMessageEvent(func: gameMsg.func, innerMsg: innerMsg);
    }
  }
}
