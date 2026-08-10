/// 服务端要求展示的卡牌（MSG_CONFIRM_CARDS / MSG_CONFIRM_DECKTOP /
/// MSG_CONFIRM_EXTRATOP），由场地页居中弹窗展示，确认后回复空响应。
class ConfirmCards {
  final String title;
  final List<int> codes;

  const ConfirmCards({required this.title, required this.codes});
}
