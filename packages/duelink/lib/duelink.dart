library duelink;

export 'src/base_duel_service.dart' show BaseDuelService;
export 'src/model/player.dart';
export 'src/model/room_options.dart';
export 'src/model/room_password.dart';
export 'src/model/room_tokens.dart';
export 'src/model/room_stage.dart';
export 'src/constants.dart';
export 'src/protocol/packet.dart';
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
export 'src/messages/game_msg/msg_retry.dart';
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
export 'src/messages/game_msg/msg_chained.dart';
export 'src/messages/game_msg/msg_chain_solving.dart';
export 'src/messages/game_msg/msg_chain_solved.dart';
export 'src/messages/game_msg/msg_chain_end.dart';
export 'src/messages/game_msg/msg_chain_negated.dart';
export 'src/messages/game_msg/msg_chain_disabled.dart';
export 'src/messages/game_msg/msg_attack_disable.dart';
export 'src/messages/game_msg/msg_become_target.dart';
export 'src/messages/game_msg/msg_random_selected.dart';
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
export 'src/messages/game_msg/msg_reverse_deck.dart';
export 'src/messages/game_msg/msg_deck_top.dart';
export 'src/messages/game_msg/msg_shuffle_set_card.dart';
export 'src/messages/game_msg/msg_hand_res.dart';
export 'src/messages/game_msg/msg_toss.dart';
export 'src/messages/game_msg/msg_rock_paper_scissors.dart';
export 'src/messages/game_msg/msg_announce_race.dart';
export 'src/messages/game_msg/msg_announce_attrib.dart';
export 'src/messages/game_msg/msg_announce_card.dart';
export 'src/messages/game_msg/msg_announce_number.dart';
export 'src/messages/game_msg/msg_confirm_cards.dart';
export 'src/messages/game_msg/msg_card_hint.dart';
export 'src/messages/game_msg/msg_tag_swap.dart';
export 'src/messages/game_msg/msg_reload_field.dart';
export 'src/messages/game_msg/msg_ai_name.dart';
export 'src/messages/game_msg/msg_show_hint.dart';
export 'src/messages/game_msg/msg_player_hint.dart';
export 'src/messages/game_msg/msg_match_kill.dart';
export 'src/messages/game_msg/msg_sibyl_name.dart';
export 'src/messages/game_msg/msg_add_counter.dart';
export 'src/messages/game_msg/msg_remove_counter.dart';
export 'src/messages/game_msg/msg_equip.dart';
export 'src/messages/game_msg/msg_card_target.dart';
export 'src/messages/game_msg/msg_cancel_target.dart';
export 'src/messages/game_msg/msg_battle.dart';
export 'src/messages/game_msg/msg_damage_step_start.dart';
export 'src/messages/game_msg/msg_damage_step_end.dart';
export 'src/messages/game_msg/msg_missed_effect.dart';
export 'src/messages/game_msg/msg_update_data.dart';
export 'src/messages/game_msg/msg_update_card.dart';
export 'src/messages/game_msg/msg_unimplemented.dart';
export 'src/model/duel_phase.dart';
export 'src/model/hand_type.dart';
export 'src/model/card.dart';
export 'src/model/connection_state.dart';
import 'dart:typed_data';

import 'package:service_loader/service_loader.dart';

import 'duelink.dart';

/// 决斗服务接口。
///
/// 方法按玩家动作语义分组，与 ygopro 底层协议解耦。
///
/// ## 连接生命周期
/// - [connect] → [disconnect]
///
/// ## 房间生命周期
/// ```
/// connect → setPlayerName → enterRoom → submitDeck → ready → startDuel
///                                    ↑___________________↓
///                                    (ready / unready 切换)
/// ```
///
/// ## 猜拳 / 先后攻
/// ```
/// [RoomSelectingHand] → chooseHand → [RoomSelectingTurn] → chooseTurnOrder
/// ```
///
/// ## 对局中
/// - [playGameResponse] 回复服务端交互
/// - [surrender] 投降
/// - [confirmTime] 确认时间限制
///
/// ## 事件流
/// - [onServerMessage] 服务端消息
/// - [onRoomStageChange] 房间状态变化
abstract class IDuelService implements IService {
  // ─── 连接 ──────────────────────────────────────────

  Future<void> connect(Uri address);

  Future<void> disconnect();

  ConnectionState get connectionState;

  // ─── 房间生命周期 ─────────────────────────────────

  /// 设置玩家名称（必须在 [enterRoom] 之前调用）。
  void setPlayerName(String name);

  /// 进入房间。
  ///
  /// [password] 由 [RoomPassword.encodeJoin] 或 [RoomPassword.encodeCreate] 生成。
  void enterRoom(String password);

  /// 提交卡组。
  ///
  /// [sideDeck] 可选：match 模式（三局两胜）换备后提交时携带副卡组。
  /// 不传时按空副卡组处理（兼容既有两参调用）。
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck, [Uint8List? sideDeck]);

  /// 准备就绪。
  void ready();

  /// 取消准备。
  void unready();

  /// 开始对局（房主可用）。
  void startDuel();

  /// 踢出指定座位的玩家（房主可用）。
  void kickPlayer(int pos);

  /// 切换到观战者身份。
  void becomeObserver();

  /// 切换到决斗者身份。
  void becomeDuelist();

  // ─── 猜拳 / 先后攻 ─────────────────────────────────

  /// 选择猜拳（剪刀/石头/布）。
  void chooseHand(HandType hand);

  /// 选择先后攻。
  ///
  /// [goFirst] — `true` 为先攻，`false` 为后攻。
  void chooseTurnOrder(bool goFirst);

  // ─── 对局中 ───────────────────────────────────────

  /// 回复服务端的游戏内交互请求。
  void playGameResponse(CtosGameMsgResponse response);

  /// 投降。
  void surrender();

  /// 确认时间限制。
  void confirmTime();

  // ─── 社交 ─────────────────────────────────────────

  /// 发送聊天消息。
  void sendChat(String message);

  // ─── 事件流 ───────────────────────────────────────

  /// 服务端消息流（包含所有 [ygo_stoc_msg.YgoStocMsg]）。
  Stream<YgoStocMsg> get onServerMessage;

  Stream<YgoStocMsg> get onChatServerMessage;

  /// 房间状态变化流（经过状态机解析后的高层语义）。
  Stream<RoomStage> get onRoomStageChange;
  Stream<DuelPhase> get onDuelPhaseMessage;
}

/// 传输层抽象 — 网络数据包的发送与接收。
///
/// 每种连接场景提供一个实现：
/// - [WebSocketConnection]（WebSocket）
/// - [AiConnection]（本地模拟）
/// - [SocketConnection]（TCP 直连）
abstract class DuelConnection {
  Future<void> connect(Uri address);

  void send(YgoCtosMsg data);

  Stream<YgoStocMsg> get messages;

  Future<void> disconnect();

  Stream<ConnectionState> get state;
}
