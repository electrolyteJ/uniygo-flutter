import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/confirm_cards.dart';

/// 卡片确认状态：服务端要求「展示给玩家看」的确认，只展示、不回包。
///
/// 覆盖 MSG_CONFIRM_CARDS / MSG_CONFIRM_DECKTOP / MSG_CONFIRM_EXTRATOP
/// 的三种呈现（与 duel_room1 保持逐字节一致）：
/// - 场上/手牌高亮（confirmed*，1.5s 后自动消退）；
/// - 确认面板（confirmPanel，多张卡组/额外卡，用户点击关闭）；
/// - 卡组/额外顶部浮动预览（floatPreview*，按卡数计时自动关闭）。
///
/// 「只展示不回包」是与选择窗口（SelectWindowState，必须作答回包）的
/// 本质区别：确认消息不阻塞对局，服务端不需要任何响应。
class CardConfirmState {
  /// 状态变更通知，由 [CardConfirmNotifier] 注入（ref.notifyListeners）。
  void Function() emit = () {};

  /// MSG_CONFIRM_CARDS 多张卡组/额外卡的弹窗（panel_confirm）。
  ConfirmPanel? confirmPanel;

  /// 卡组顶部 / 额外卡组顶部浮动预览的卡密列表。
  List<int> floatPreviewCodes = [];
  int floatPreviewOwner = 0;
  bool floatPreviewIsExtra = false;

  /// field_confirm 阶段需要高亮的场上卡槽 key 集合。
  Set<String> confirmedFieldSlotKeys = {};

  /// field_confirm 阶段需要高亮的手牌序列号集合。
  Set<int> confirmedHandSequences = {};

  /// confirmedHandSequences 对应的玩家编号 (0=己方, 1=对方)。
  int confirmedHandOwner = 0;

  Timer? _confirmTimer;

  /// 是否处于 decktop/extratop 浮动预览阶段（区别于 field_confirm）。
  bool get isFloatPreview => floatPreviewCodes.isNotEmpty;

  /// 取消尚未触发的确认计时器（新的确认消息到达时由协调器调用）。
  void cancelTimer() {
    _confirmTimer?.cancel();
  }

  /// 卡组顶部/额外顶部的浮动预览，按卡数计算总时长后自动关闭。
  void showFloatPreview(
    List<int> codes,
    int owner, {
    required bool isExtra,
  }) {
    _confirmTimer?.cancel();
    floatPreviewCodes = codes;
    floatPreviewOwner = owner;
    floatPreviewIsExtra = isExtra;
    emit();

    final count = floatPreviewCodes.length;
    final interval = count > 5 ? 200 : 750;
    final totalMs = count * interval + 500;
    _confirmTimer = Timer(Duration(milliseconds: totalMs), () {
      floatPreviewCodes = [];
      emit();
    });
  }

  /// 场上/手牌确认高亮：先高亮 1.5s，消退后若还有卡组/额外的卡
  /// 需要展示，再弹出确认面板。
  void scheduleConfirmedReveal({
    required Set<String> fieldSlotKeys,
    required Set<int> handSequences,
    required int handOwner,
    required Set<int> panelCodes,
    required String title,
  }) {
    _confirmTimer?.cancel();
    confirmedFieldSlotKeys = fieldSlotKeys;
    confirmedHandSequences = handSequences;
    confirmedHandOwner = handOwner;
    emit();

    _confirmTimer = Timer(const Duration(milliseconds: 1500), () {
      confirmedFieldSlotKeys = {};
      confirmedHandSequences = {};
      confirmedHandOwner = 0;
      emit();

      if (panelCodes.isNotEmpty) {
        confirmPanel = ConfirmPanel(
          title: title,
          codes: panelCodes.toList(),
        );
        emit();
      }
    });
  }

  /// 直接弹出确认面板（无场上/手牌高亮前置时）。
  void showConfirmPanel({required String title, required List<int> codes}) {
    confirmPanel = ConfirmPanel(title: title, codes: codes);
    emit();
  }

  /// 关闭确认弹窗（服务端已在收到消息时自动确认）。
  void dismissConfirmPanel() {
    _confirmTimer?.cancel();
    confirmPanel = null;
    confirmedFieldSlotKeys = {};
    confirmedHandSequences = {};
    confirmedHandOwner = 0;
    floatPreviewCodes = [];
    emit();
  }

  /// 清空确认状态。与 duel_room1 保持一致：仅关闭面板并取消计时器，
  /// 不清浮动预览与高亮集合（原 ChangeNotifier 版 reset 的行为）。
  void reset() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    confirmPanel = null;
  }

  /// Provider 销毁时兜底取消计时器。
  void dispose() {
    _confirmTimer?.cancel();
  }
}

/// 卡片确认的 Notifier：仅负责持有状态与生命周期，
/// 确认呈现逻辑全部在 [CardConfirmState] 内，与 duel_room1 逐字节一致。
class CardConfirmNotifier extends Notifier<CardConfirmState> {
  @override
  CardConfirmState build() {
    final state = CardConfirmState();
    state.emit = ref.notifyListeners;
    ref.onDispose(state.dispose);
    return state;
  }
}

/// 卡片确认状态的 provider，按房间 ProviderScope override 隔离。
final cardConfirmProvider =
    NotifierProvider<CardConfirmNotifier, CardConfirmState>(
  CardConfirmNotifier.new,
);
