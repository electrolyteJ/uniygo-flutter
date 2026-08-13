import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/confirm_cards.dart';

const Object _undefined = Object();

/// 卡片确认状态：服务端要求「展示给玩家看」的确认，只展示、不回包，不可变快照。
///
/// 覆盖 MSG_CONFIRM_CARDS / MSG_CONFIRM_DECKTOP / MSG_CONFIRM_EXTRATOP
/// 的三种呈现：
/// - 场上/手牌高亮（confirmed*，1.5s 后自动消退）；
/// - 确认面板（confirmPanel，多张卡组/额外卡，用户点击关闭）；
/// - 卡组/额外顶部浮动预览（floatPreview*，按卡数计时自动关闭）。
///
/// 「只展示不回包」是与选择窗口（SelectWindowState，必须作答回包）的
/// 本质区别：确认消息不阻塞对局，服务端不需要任何响应。
class CardConfirmState {
  const CardConfirmState({
    this.confirmPanel,
    this.floatPreviewCodes = const [],
    this.floatPreviewOwner = 0,
    this.floatPreviewIsExtra = false,
    this.confirmedFieldSlotKeys = const {},
    this.confirmedHandSequences = const {},
    this.confirmedHandOwner = 0,
  });

  /// MSG_CONFIRM_CARDS 多张卡组/额外卡的弹窗（panel_confirm）。
  final ConfirmPanel? confirmPanel;

  /// 卡组顶部 / 额外卡组顶部浮动预览的卡密列表。
  final List<int> floatPreviewCodes;
  final int floatPreviewOwner;
  final bool floatPreviewIsExtra;

  /// field_confirm 阶段需要高亮的场上卡槽 key 集合。
  final Set<String> confirmedFieldSlotKeys;

  /// field_confirm 阶段需要高亮的手牌序列号集合。
  final Set<int> confirmedHandSequences;

  /// confirmedHandSequences 对应的玩家编号 (0=己方, 1=对方)。
  final int confirmedHandOwner;

  /// 是否处于 decktop/extratop 浮动预览阶段（区别于 field_confirm）。
  bool get isFloatPreview => floatPreviewCodes.isNotEmpty;

  CardConfirmState copyWith({
    Object? confirmPanel = _undefined,
    List<int>? floatPreviewCodes,
    int? floatPreviewOwner,
    bool? floatPreviewIsExtra,
    Set<String>? confirmedFieldSlotKeys,
    Set<int>? confirmedHandSequences,
    int? confirmedHandOwner,
  }) {
    return CardConfirmState(
      confirmPanel: identical(confirmPanel, _undefined)
          ? this.confirmPanel
          : confirmPanel as ConfirmPanel?,
      floatPreviewCodes: floatPreviewCodes ?? this.floatPreviewCodes,
      floatPreviewOwner: floatPreviewOwner ?? this.floatPreviewOwner,
      floatPreviewIsExtra: floatPreviewIsExtra ?? this.floatPreviewIsExtra,
      confirmedFieldSlotKeys:
          confirmedFieldSlotKeys ?? this.confirmedFieldSlotKeys,
      confirmedHandSequences:
          confirmedHandSequences ?? this.confirmedHandSequences,
      confirmedHandOwner: confirmedHandOwner ?? this.confirmedHandOwner,
    );
  }
}

/// 卡片确认的 Notifier：持有确认呈现逻辑与自动消退计时器。
class CardConfirmNotifier extends Notifier<CardConfirmState> {
  Timer? _confirmTimer;

  @override
  CardConfirmState build() {
    ref.onDispose(() => _confirmTimer?.cancel());
    return const CardConfirmState();
  }

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
    state = state.copyWith(
      floatPreviewCodes: codes,
      floatPreviewOwner: owner,
      floatPreviewIsExtra: isExtra,
    );

    final count = state.floatPreviewCodes.length;
    final interval = count > 5 ? 200 : 750;
    final totalMs = count * interval + 500;
    _confirmTimer = Timer(Duration(milliseconds: totalMs), () {
      state = state.copyWith(floatPreviewCodes: const []);
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
    state = state.copyWith(
      confirmedFieldSlotKeys: fieldSlotKeys,
      confirmedHandSequences: handSequences,
      confirmedHandOwner: handOwner,
    );

    _confirmTimer = Timer(const Duration(milliseconds: 1500), () {
      state = state.copyWith(
        confirmedFieldSlotKeys: const {},
        confirmedHandSequences: const {},
        confirmedHandOwner: 0,
      );

      if (panelCodes.isNotEmpty) {
        state = state.copyWith(
          confirmPanel: ConfirmPanel(
            title: title,
            codes: panelCodes.toList(),
          ),
        );
      }
    });
  }

  /// 直接弹出确认面板（无场上/手牌高亮前置时）。
  void showConfirmPanel({required String title, required List<int> codes}) {
    state = state.copyWith(
      confirmPanel: ConfirmPanel(title: title, codes: codes),
    );
  }

  /// 关闭确认弹窗（服务端已在收到消息时自动确认）。
  void dismissConfirmPanel() {
    _confirmTimer?.cancel();
    state = state.copyWith(
      confirmPanel: null,
      confirmedFieldSlotKeys: const {},
      confirmedHandSequences: const {},
      confirmedHandOwner: 0,
      floatPreviewCodes: const [],
    );
  }

  /// 清空确认状态：仅关闭面板并取消计时器，
  /// 不清浮动预览与高亮集合（与原实现一致）。
  void reset() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    state = state.copyWith(confirmPanel: null);
  }
}

/// 卡片确认状态的 provider，按房间 ProviderScope override 隔离。
final cardConfirmProvider =
    NotifierProvider<CardConfirmNotifier, CardConfirmState>(
  CardConfirmNotifier.new,
);
