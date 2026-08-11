/// 服务端要求展示的卡牌（MSG_CONFIRM_CARDS / MSG_CONFIRM_DECKTOP /
/// MSG_CONFIRM_EXTRATOP）。
///
/// 参考经典 ygopro C++ 桌面端行为：
/// - DECKTOP/EXTRATOP：卡片在卡组/额外原位偏移+旋转动画，自动结束。
/// - CONFIRM_CARDS：先高亮场上/手牌卡 (field_confirm, 1.5s auto)，
///   再弹窗展示卡组/额外多张卡 (panel_confirm, 用户点击关闭)。
class ConfirmPanel {
  final String title;
  final List<int> codes;

  const ConfirmPanel({required this.title, required this.codes});
}
