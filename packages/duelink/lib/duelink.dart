library duelink;

import 'dart:typed_data';

import 'package:service_loader/service_loader.dart';

import 'duelink.dart';

export 'src/protocol/packet.dart';
export 'src/types.dart';
export 'src/service/PlayerInfo.dart';
export 'src/service/room_options.dart';
export 'src/service/room_password.dart';
export 'src/service/room_state.dart';
export 'src/constants.dart';
export 'src/protocol/adapter.dart';
export 'src/protocol/buffer_io.dart';
export 'src/messages/ygo_ctos_msg.dart';
export 'src/messages/ygo_stoc_msg.dart';
export 'src/messages/ctos/ctos_player_info.dart';
export 'src/messages/ctos/ctos_join_game.dart';
export 'src/messages/ctos/ctos_update_deck.dart';
export 'src/messages/ctos/ctos_hand_result.dart';
export 'src/messages/ctos/ctos_tp_result.dart';
export 'src/messages/ctos/ctos_game_msg_response.dart';
export 'src/messages/ctos/ctos_chat.dart';
export 'src/messages/stoc/stoc_join_game.dart';
export 'src/messages/stoc/stoc_type_change.dart';
export 'src/messages/stoc/stoc_hs_player_enter.dart';
export 'src/messages/stoc/stoc_hs_player_change.dart';
export 'src/messages/stoc/stoc_hs_watch_change.dart';
export 'src/messages/stoc/stoc_chat.dart';
export 'src/messages/stoc/stoc_hand_result.dart';
export 'src/messages/stoc/stoc_select_hand.dart';
export 'src/messages/stoc/stoc_select_tp.dart';
export 'src/messages/stoc/stoc_deck_count.dart';
export 'src/messages/stoc/stoc_duel_start.dart';
export 'src/messages/stoc/stoc_duel_end.dart';
export 'src/messages/stoc/stoc_time_limit.dart';
export 'src/messages/stoc/stoc_error_msg.dart';
export 'src/messages/stoc/stoc_change_side.dart';
export 'src/messages/stoc/stoc_waiting_side.dart';
export 'src/messages/stoc/stoc_game_msg.dart';
export 'src/messages/game_msg/msg_start.dart';
export 'src/messages/game_msg/msg_draw.dart';
export 'src/messages/game_msg/msg_new_turn.dart';
export 'src/messages/game_msg/msg_new_phase.dart';
export 'src/messages/game_msg/msg_win.dart';
export 'src/messages/game_msg/msg_wait.dart';
export 'src/messages/game_msg/msg_hint.dart';
export 'src/messages/game_msg/msg_move.dart';
export 'src/messages/game_msg/msg_attack.dart';
export 'src/messages/game_msg/msg_damage.dart';
export 'src/messages/game_msg/msg_recover.dart';
export 'src/messages/game_msg/msg_lp_update.dart';
export 'src/messages/game_msg/msg_pay_lp_cost.dart';
export 'src/messages/game_msg/msg_summoning.dart';
export 'src/messages/game_msg/msg_summoned.dart';
export 'src/messages/game_msg/msg_sp_summoning.dart';
export 'src/messages/game_msg/msg_sp_summoned.dart';
export 'src/messages/game_msg/msg_flip_summoning.dart';
export 'src/messages/game_msg/msg_flip_summoned.dart';
export 'src/messages/game_msg/msg_chaining.dart';
export 'src/messages/game_msg/msg_chain_solved.dart';
export 'src/messages/game_msg/msg_chain_end.dart';
export 'src/messages/game_msg/msg_attack_disable.dart';
export 'src/messages/game_msg/msg_become_target.dart';
export 'src/messages/game_msg/msg_pos_change.dart';
export 'src/messages/game_msg/msg_set.dart';
export 'src/messages/game_msg/msg_swap.dart';
export 'src/messages/game_msg/msg_field_disabled.dart';
export 'src/messages/game_msg/msg_select_idle_cmd.dart';
export 'src/messages/game_msg/msg_select_card.dart';
export 'src/messages/game_msg/msg_select_chain.dart';
export 'src/messages/game_msg/msg_select_effect_yn.dart';
export 'src/messages/game_msg/msg_select_yes_no.dart';
export 'src/messages/game_msg/msg_select_position.dart';
export 'src/messages/game_msg/msg_select_option.dart';
export 'src/messages/game_msg/msg_select_battle_cmd.dart';
export 'src/messages/game_msg/msg_select_place.dart';
export 'src/messages/game_msg/msg_select_unselect_card.dart';
export 'src/messages/game_msg/msg_select_tribute.dart';
export 'src/messages/game_msg/msg_select_sum.dart';
export 'src/messages/game_msg/msg_select_counter.dart';
export 'src/messages/game_msg/msg_sort_card.dart';
export 'src/messages/game_msg/msg_shuffle_deck.dart';
export 'src/messages/game_msg/msg_shuffle_hand.dart';
export 'src/messages/game_msg/msg_shuffle_extra.dart';
export 'src/messages/game_msg/msg_swap_grave_deck.dart';
export 'src/messages/game_msg/msg_shuffle_set_card.dart';
export 'src/messages/game_msg/msg_hand_res.dart';
export 'src/messages/game_msg/msg_toss.dart';
export 'src/messages/game_msg/msg_rock_paper_scissors.dart';
export 'src/messages/game_msg/msg_announce_race.dart';
export 'src/messages/game_msg/msg_announce_attrib.dart';
export 'src/messages/game_msg/msg_announce_card.dart';
export 'src/messages/game_msg/msg_announce_number.dart';
export 'src/messages/game_msg/msg_confirm_cards.dart';
export 'src/messages/game_msg/msg_reload_field.dart';
export 'src/messages/game_msg/msg_sibyl_name.dart';
export 'src/messages/game_msg/msg_add_counter.dart';
export 'src/messages/game_msg/msg_remove_counter.dart';
export 'src/messages/game_msg/msg_update_data.dart';
export 'src/messages/game_msg/msg_update_card.dart';

abstract class IDuelService implements IService {
  Future<void> connect(String address, int port);

  Future<void> disconnect();

  ConnectionState get connectionState;

  void sendPlayerInfo(String name);

  void sendJoinGame(int gameId, String? passwd);

  void sendUpdateDeck(Uint8List mainDeck, Uint8List extraDeck);

  void sendReady();

  void sendNotReady();

  void sendStart();

  void sendKick(int pos);

  void sendToObserver();

  void sendToDuelist();

  void sendChat(String message);

  void sendSurrender();

  void sendHandResult(HandType hand);

  void sendTpResult(bool first);

  void sendResponse(CtosGameMsgResponse response);

  void sendTimeConfirm();

  Stream<YgoStocMsg> get onMessage;

  Stream<RoomState> get onRoomStateChange;
}

IService createDuelService(int type) {
  return ServiceFactory.create(type);
}

enum ConnectionState { disconnected, connecting, connected, error }

abstract class DuelConnection {
  Future<void> connect(String address, int port);

  void send(Uint8List data);

  Stream<Uint8List> get messages;

  Future<void> disconnect();

  Stream<ConnectionState> get state;
}
