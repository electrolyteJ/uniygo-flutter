import 'dart:typed_data';
import '../../constants.dart';
import '../game_msg/msg_start.dart';
import '../game_msg/msg_draw.dart';
import '../game_msg/msg_new_turn.dart';
import '../game_msg/msg_new_phase.dart';
import '../game_msg/msg_win.dart';
import '../game_msg/msg_wait.dart';
import '../game_msg/msg_hint.dart';
import '../game_msg/msg_move.dart';
import '../game_msg/msg_select_idle_cmd.dart';
import '../game_msg/msg_select_card.dart';
import '../game_msg/msg_select_battle_cmd.dart';
import '../game_msg/msg_select_option.dart';
import '../game_msg/msg_select_chain.dart';
import '../game_msg/msg_select_effect_yn.dart';
import '../game_msg/msg_select_position.dart';
import '../game_msg/msg_select_place.dart';
import '../game_msg/msg_select_yes_no.dart';
import '../game_msg/msg_select_unselect_card.dart';
import '../game_msg/msg_select_tribute.dart';
import '../game_msg/msg_select_sum.dart';
import '../game_msg/msg_select_counter.dart';
import '../game_msg/msg_sort_card.dart';
import '../game_msg/msg_damage.dart';
import '../game_msg/msg_recover.dart';
import '../game_msg/msg_lp_update.dart';
import '../game_msg/msg_pay_lp_cost.dart';
import '../game_msg/msg_summoning.dart';
import '../game_msg/msg_summoned.dart';
import '../game_msg/msg_sp_summoning.dart';
import '../game_msg/msg_sp_summoned.dart';
import '../game_msg/msg_flip_summoning.dart';
import '../game_msg/msg_flip_summoned.dart';
import '../game_msg/msg_chaining.dart';
import '../game_msg/msg_chain_solved.dart';
import '../game_msg/msg_chain_end.dart';
import '../game_msg/msg_attack.dart';
import '../game_msg/msg_attack_disable.dart';
import '../game_msg/msg_become_target.dart';
import '../game_msg/msg_field_disabled.dart';
import '../game_msg/msg_pos_change.dart';
import '../game_msg/msg_set.dart';
import '../game_msg/msg_swap.dart';
import '../game_msg/msg_shuffle_deck.dart';
import '../game_msg/msg_shuffle_hand.dart';
import '../game_msg/msg_shuffle_extra.dart';
import '../game_msg/msg_swap_grave_deck.dart';
import '../game_msg/msg_shuffle_set_card.dart';
import '../game_msg/msg_hand_res.dart';
import '../game_msg/msg_toss.dart';
import '../game_msg/msg_rock_paper_scissors.dart';
import '../game_msg/msg_announce_race.dart';
import '../game_msg/msg_announce_attrib.dart';
import '../game_msg/msg_announce_card.dart';
import '../game_msg/msg_announce_number.dart';
import '../game_msg/msg_confirm_cards.dart';
import '../game_msg/msg_reload_field.dart';
import '../game_msg/msg_sibyl_name.dart';
import '../game_msg/msg_add_counter.dart';
import '../game_msg/msg_remove_counter.dart';
import '../game_msg/msg_update_data.dart';
import '../game_msg/msg_update_card.dart';
import '../../protocol/buffer_io.dart';

/// Server-to-client game message wrapper.
/// First byte of exData is the func (MSG_* constant).
class StocGameMessage {
  final int func;
  final dynamic innerMsg;

  const StocGameMessage({required this.func, required this.innerMsg});

  int get protoId => STOC_GAME_MSG;

  Uint8List encode() {
    final innerBytes = _encodeInner();
    final w = BufferWriter();
    w.writeUint8(func);
    w.writeBytes(innerBytes);
    return w.toBytes();
  }

  Uint8List _encodeInner() {
    switch (func) {
      case MSG_START:
        return (innerMsg as MsgStart).encode();
      case MSG_DRAW:
        return (innerMsg as MsgDraw).encode();
      case MSG_NEW_TURN:
        return (innerMsg as MsgNewTurn).encode();
      case MSG_NEW_PHASE:
        return (innerMsg as MsgNewPhase).encode();
      case MSG_WIN:
        return (innerMsg as MsgWin).encode();
      case MSG_WAITING:
        return (innerMsg as MsgWait).encode();
      case MSG_HINT:
        return (innerMsg as MsgHint).encode();
      case MSG_MOVE:
        return (innerMsg as MsgMove).encode();
      case MSG_SELECT_IDLE_CMD:
        return (innerMsg as MsgSelectIdleCmd).encode();
      case MSG_SELECT_CARD:
        return (innerMsg as MsgSelectCard).encode();
      case MSG_SELECT_BATTLE_CMD:
        return (innerMsg as MsgSelectBattleCmd).encode();
      case MSG_SELECT_OPTION:
        return (innerMsg as MsgSelectOption).encode();
      case MSG_SELECT_CHAIN:
        return (innerMsg as MsgSelectChain).encode();
      case MSG_SELECT_EFFECTYN:
        return (innerMsg as MsgSelectEffectYn).encode();
      case MSG_SELECT_POSITION:
        return (innerMsg as MsgSelectPosition).encode();
      case MSG_SELECT_PLACE:
        return (innerMsg as MsgSelectPlace).encode();
      case MSG_SELECT_YES_NO:
        return (innerMsg as MsgSelectYesNo).encode();
      case MSG_SELECT_UNSELECT_CARD:
        return (innerMsg as MsgSelectUnselectCard).encode();
      case MSG_SELECT_TRIBUTE:
        return (innerMsg as MsgSelectTribute).encode();
      case MSG_SELECT_SUM:
        return (innerMsg as MsgSelectSum).encode();
      case MSG_SELECT_COUNTER:
        return (innerMsg as MsgSelectCounter).encode();
      case MSG_SORT_CARD:
        return (innerMsg as MsgSortCard).encode();
      case MSG_DAMAGE:
        return (innerMsg as MsgDamage).encode();
      case MSG_RECOVER:
        return (innerMsg as MsgRecover).encode();
      case MSG_LP_UPDATE:
        return (innerMsg as MsgLpUpdate).encode();
      case MSG_PAY_LP_COST:
        return (innerMsg as MsgPayLpCost).encode();
      case MSG_SUMMONING:
        return (innerMsg as MsgSummoning).encode();
      case MSG_SUMMONED:
        return (innerMsg as MsgSummoned).encode();
      case MSG_SP_SUMMONING:
        return (innerMsg as MsgSpSummoning).encode();
      case MSG_SP_SUMMONED:
        return (innerMsg as MsgSpSummoned).encode();
      case MSG_FLIP_SUMMONING:
        return (innerMsg as MsgFlipSummoning).encode();
      case MSG_FLIP_SUMMONED:
        return (innerMsg as MsgFlipSummoned).encode();
      case MSG_CHAINING:
        return (innerMsg as MsgChaining).encode();
      case MSG_CHAIN_SOLVED:
        return (innerMsg as MsgChainSolved).encode();
      case MSG_CHAIN_END:
        return (innerMsg as MsgChainEnd).encode();
      case MSG_ATTACK:
        return (innerMsg as MsgAttack).encode();
      case MSG_ATTACK_DISABLE:
        return (innerMsg as MsgAttackDisable).encode();
      case MSG_BECOME_TARGET:
        return (innerMsg as MsgBecomeTarget).encode();
      case MSG_FIELD_DISABLED:
        return (innerMsg as MsgFieldDisabled).encode();
      case MSG_POS_CHANGE:
        return (innerMsg as MsgPosChange).encode();
      case MSG_SET:
        return (innerMsg as MsgSet).encode();
      case MSG_SWAP:
        return (innerMsg as MsgSwap).encode();
      case MSG_SHUFFLE_DECK:
        return (innerMsg as MsgShuffleDeck).encode();
      case MSG_SHUFFLE_HAND:
        return (innerMsg as MsgShuffleHand).encode();
      case MSG_SHUFFLE_EXTRA:
        return (innerMsg as MsgShuffleExtra).encode();
      case MSG_SWAP_GRAVE_DECK:
        return (innerMsg as MsgSwapGraveDeck).encode();
      case MSG_SHUFFLE_SET_CARD:
        return (innerMsg as MsgShuffleSetCard).encode();
      case MSG_HAND_RES:
        return (innerMsg as MsgHandRes).encode();
      case MSG_TOSS_COIN:
        return (innerMsg as MsgToss).encode();
      case MSG_TOSS_DICE:
        return (innerMsg as MsgToss).encode();
      case MSG_ROCK_PAPER_SCISSORS:
        return (innerMsg as MsgRockPaperScissors).encode();
      case MSG_ANNOUNCE_RACE:
        return (innerMsg as MsgAnnounceRace).encode();
      case MSG_ANNOUNCE_ATTRIB:
        return (innerMsg as MsgAnnounceAttrib).encode();
      case MSG_ANNOUNCE_CARD:
        return (innerMsg as MsgAnnounceCard).encode();
      case MSG_ANNOUNCE_NUMBER:
        return (innerMsg as MsgAnnounceNumber).encode();
      case MSG_CONFIRM_CARDS:
        return (innerMsg as MsgConfirmCards).encode();
      case MSG_RELOAD_FIELD:
        return (innerMsg as MsgReloadField).encode();
      case MSG_SIBYL_NAME:
        return (innerMsg as MsgSibylName).encode();
      case MSG_ADD_COUNTER:
        return (innerMsg as MsgAddCounter).encode();
      case MSG_REMOVE_COUNTER:
        return (innerMsg as MsgRemoveCounter).encode();
      case MSG_UPDATE_DATA:
        return (innerMsg as MsgUpdateData).encode();
      case MSG_UPDATE_CARD:
        return (innerMsg as MsgUpdateCard).encode();
      default:
        return Uint8List(0);
    }
  }

  static StocGameMessage decode(Uint8List data) {
    final r = BufferReader(data);
    final func = r.readUint8();
    final innerData =
        Uint8List.view(data.buffer, data.offsetInBytes + 1, data.length - 1);

    switch (func) {
      case MSG_START:
        return StocGameMessage(func: func, innerMsg: MsgStart.decode(innerData));
      case MSG_DRAW:
        return StocGameMessage(func: func, innerMsg: MsgDraw.decode(innerData));
      case MSG_NEW_TURN:
        return StocGameMessage(func: func, innerMsg: MsgNewTurn.decode(innerData));
      case MSG_NEW_PHASE:
        return StocGameMessage(func: func, innerMsg: MsgNewPhase.decode(innerData));
      case MSG_WIN:
        return StocGameMessage(func: func, innerMsg: MsgWin.decode(innerData));
      case MSG_WAITING:
        return StocGameMessage(func: func, innerMsg: MsgWait.decode(innerData));
      case MSG_HINT:
        return StocGameMessage(func: func, innerMsg: MsgHint.decode(innerData));
      case MSG_MOVE:
        return StocGameMessage(func: func, innerMsg: MsgMove.decode(innerData));
      case MSG_SELECT_IDLE_CMD:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectIdleCmd.decode(innerData));
      case MSG_SELECT_CARD:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectCard.decode(innerData));
      case MSG_SELECT_BATTLE_CMD:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectBattleCmd.decode(innerData));
      case MSG_SELECT_OPTION:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectOption.decode(innerData));
      case MSG_SELECT_CHAIN:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectChain.decode(innerData));
      case MSG_SELECT_EFFECTYN:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectEffectYn.decode(innerData));
      case MSG_SELECT_POSITION:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectPosition.decode(innerData));
      case MSG_SELECT_PLACE:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectPlace.decode(innerData));
      case MSG_SELECT_YES_NO:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectYesNo.decode(innerData));
      case MSG_SELECT_UNSELECT_CARD:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectUnselectCard.decode(innerData));
      case MSG_SELECT_TRIBUTE:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectTribute.decode(innerData));
      case MSG_SELECT_SUM:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectSum.decode(innerData));
      case MSG_SELECT_COUNTER:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectCounter.decode(innerData));
      case MSG_SELECT_DISFIELD:
        return StocGameMessage(
            func: func, innerMsg: MsgSelectUnselectCard.decode(innerData));
      case MSG_SORT_CARD:
        return StocGameMessage(func: func, innerMsg: MsgSortCard.decode(innerData));
      case MSG_DAMAGE:
        return StocGameMessage(func: func, innerMsg: MsgDamage.decode(innerData));
      case MSG_RECOVER:
        return StocGameMessage(func: func, innerMsg: MsgRecover.decode(innerData));
      case MSG_LP_UPDATE:
        return StocGameMessage(
            func: func, innerMsg: MsgLpUpdate.decode(innerData));
      case MSG_PAY_LP_COST:
        return StocGameMessage(
            func: func, innerMsg: MsgPayLpCost.decode(innerData));
      case MSG_SUMMONING:
        return StocGameMessage(
            func: func, innerMsg: MsgSummoning.decode(innerData));
      case MSG_SUMMONED:
        return StocGameMessage(
            func: func, innerMsg: MsgSummoned.decode(innerData));
      case MSG_SP_SUMMONING:
        return StocGameMessage(
            func: func, innerMsg: MsgSpSummoning.decode(innerData));
      case MSG_SP_SUMMONED:
        return StocGameMessage(
            func: func, innerMsg: MsgSpSummoned.decode(innerData));
      case MSG_FLIP_SUMMONING:
        return StocGameMessage(
            func: func, innerMsg: MsgFlipSummoning.decode(innerData));
      case MSG_FLIP_SUMMONED:
        return StocGameMessage(
            func: func, innerMsg: MsgFlipSummoned.decode(innerData));
      case MSG_CHAINING:
        return StocGameMessage(
            func: func, innerMsg: MsgChaining.decode(innerData));
      case MSG_CHAIN_SOLVED:
        return StocGameMessage(
            func: func, innerMsg: MsgChainSolved.decode(innerData));
      case MSG_CHAIN_END:
        return StocGameMessage(
            func: func, innerMsg: MsgChainEnd.decode(innerData));
      case MSG_ATTACK:
        return StocGameMessage(func: func, innerMsg: MsgAttack.decode(innerData));
      case MSG_ATTACK_DISABLE:
        return StocGameMessage(
            func: func, innerMsg: MsgAttackDisable.decode(innerData));
      case MSG_BECOME_TARGET:
        return StocGameMessage(
            func: func, innerMsg: MsgBecomeTarget.decode(innerData));
      case MSG_FIELD_DISABLED:
        return StocGameMessage(
            func: func, innerMsg: MsgFieldDisabled.decode(innerData));
      case MSG_POS_CHANGE:
        return StocGameMessage(
            func: func, innerMsg: MsgPosChange.decode(innerData));
      case MSG_SET:
        return StocGameMessage(func: func, innerMsg: MsgSet.decode(innerData));
      case MSG_SWAP:
        return StocGameMessage(func: func, innerMsg: MsgSwap.decode(innerData));
      case MSG_SHUFFLE_DECK:
        return StocGameMessage(
            func: func, innerMsg: MsgShuffleDeck.decode(innerData));
      case MSG_SHUFFLE_HAND:
        return StocGameMessage(
            func: func, innerMsg: MsgShuffleHand.decode(innerData));
      case MSG_SHUFFLE_EXTRA:
        return StocGameMessage(
            func: func, innerMsg: MsgShuffleExtra.decode(innerData));
      case MSG_SWAP_GRAVE_DECK:
        return StocGameMessage(
            func: func, innerMsg: MsgSwapGraveDeck.decode(innerData));
      case MSG_SHUFFLE_SET_CARD:
        return StocGameMessage(
            func: func, innerMsg: MsgShuffleSetCard.decode(innerData));
      case MSG_HAND_RES:
        return StocGameMessage(
            func: func, innerMsg: MsgHandRes.decode(innerData));
      case MSG_TOSS_COIN:
        return StocGameMessage(func: func, innerMsg: MsgToss.decode(innerData));
      case MSG_TOSS_DICE:
        return StocGameMessage(func: func, innerMsg: MsgToss.decode(innerData));
      case MSG_ROCK_PAPER_SCISSORS:
        return StocGameMessage(
            func: func, innerMsg: MsgRockPaperScissors.decode(innerData));
      case MSG_ANNOUNCE_RACE:
        return StocGameMessage(
            func: func, innerMsg: MsgAnnounceRace.decode(innerData));
      case MSG_ANNOUNCE_ATTRIB:
        return StocGameMessage(
            func: func, innerMsg: MsgAnnounceAttrib.decode(innerData));
      case MSG_ANNOUNCE_CARD:
        return StocGameMessage(
            func: func, innerMsg: MsgAnnounceCard.decode(innerData));
      case MSG_ANNOUNCE_NUMBER:
        return StocGameMessage(
            func: func, innerMsg: MsgAnnounceNumber.decode(innerData));
      case MSG_CONFIRM_CARDS:
        return StocGameMessage(
            func: func, innerMsg: MsgConfirmCards.decode(innerData));
      case MSG_RELOAD_FIELD:
        return StocGameMessage(
            func: func, innerMsg: MsgReloadField.decode(innerData));
      case MSG_SIBYL_NAME:
        return StocGameMessage(
            func: func, innerMsg: MsgSibylName.decode(innerData));
      case MSG_ADD_COUNTER:
        return StocGameMessage(
            func: func, innerMsg: MsgAddCounter.decode(innerData));
      case MSG_REMOVE_COUNTER:
        return StocGameMessage(
            func: func, innerMsg: MsgRemoveCounter.decode(innerData));
      case MSG_UPDATE_DATA:
        return StocGameMessage(
            func: func, innerMsg: MsgUpdateData.decode(innerData));
      case MSG_UPDATE_CARD:
        return StocGameMessage(
            func: func, innerMsg: MsgUpdateCard.decode(innerData));
      default:
        return StocGameMessage(func: func, innerMsg: MsgWait.decode(innerData));
    }
  }

  @override
  String toString() => 'StocGameMessage(func:$func)';
}
