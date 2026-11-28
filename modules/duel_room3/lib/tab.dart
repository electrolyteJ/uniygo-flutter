/// 房间的七个页，对应 [TabBarView] 的七页。
///
/// 按实际流程排序：等候 → 猜拳 → 选先后攻 → 载入 → 场地 → 换备 → 结算。
/// 顺序即 tab 顺序，**不可重排**——[DuelRoomPage3D] 用 `.index` 驱动控制器。
enum DuelRoomTab {
  /// ① 等待大厅：RoomInLobby / RoomJoined，组卡、等对手、观战列表。
  lobby,

  /// ② 猜拳：RoomSelectingHand / RoomHandResult。
  hand,

  /// ③ 选择先后攻：RoomSelectingTurn。
  turn,

  /// ④ 载入页：入场演出（Seamless Loading Screen），不持有 3D。
  loading,

  /// ⑤ 场地页：真正的决斗场地与 HUD。
  field,

  /// ⑥ 换备页：match 局间调整副卡组（Ardot 531:1）。
  sideDecking,

  /// ⑦ 结束页：本局结算（胜/负/平 + 双方 LP + 结束原因）。
  end,
}
