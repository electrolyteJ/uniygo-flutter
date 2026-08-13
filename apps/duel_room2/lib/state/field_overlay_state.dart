import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../models/field_card.dart';

/// 场地浮层状态：玩家自己打开的本地查看 UI，
/// 与服务器协议无关、不需要回包，随时可被更高优先级的选择窗口挤掉。
///
/// 卡片检视抽屉（inspector）、区域浏览器（zone browser，墓地/除外/额外）、
/// 阶段菜单（phase menu），以及手牌/场上卡/浏览器卡片的选中态。
///
/// 「玩家自己开的查看浮层」是与对局事实（DuelFieldState，服务器写入）
/// 的本质区别：这些状态完全由本地交互驱动，不来自任何 MSG_* 消息。
class FieldOverlayState {
  /// 状态变更通知，由 [FieldOverlayNotifier] 注入（ref.notifyListeners）。
  void Function() emit = () {};

  /// 当前检视的卡片（详情抽屉数据源）。
  int? inspectedCardCode;
  pkg.CardInfo? inspectedCardInfo;

  /// 当前选中的手牌下标（手牌操作菜单的锚点）。
  int? selectedHandSequence;

  /// 区域浏览器中选中的卡片下标（浏览器操作菜单的锚点）。
  int? selectedZoneBrowserSequence;

  /// 当前选中的场上卡（场上操作菜单的锚点）。
  FieldCard? selectedFieldCard;

  /// 当前打开的区域浏览器 key（`self_grave` / `opp_extra` 等）。
  String? openZoneBrowserKey;

  bool showInspector = false;
  bool showPhaseMenu = false;

  /// 是否有任何本地弹层处于打开/选中状态。
  bool get hasAnyOverlayOpen =>
      selectedHandSequence != null ||
      selectedZoneBrowserSequence != null ||
      selectedFieldCard != null ||
      openZoneBrowserKey != null ||
      showPhaseMenu;

  /// 打开/切换卡片检视。卡信息的异步加载由协调器负责
  /// （卡片缓存收敛在战场状态的 dataService）。
  void applyInspect(
    int code,
    pkg.CardInfo? info, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code <= 0) return;
    inspectedCardCode = code;
    inspectedCardInfo = info;
    if (!preserveHandSelection) {
      selectedHandSequence = null;
    }
    if (!preserveZoneBrowser) {
      openZoneBrowserKey = null;
      selectedZoneBrowserSequence = null;
    }
    showInspector = true;
  }

  void dismissInspector() {
    if (!showInspector) return;
    showInspector = false;
    emit();
  }

  /// 手牌单击：选中该手牌并检视（清掉浏览器/场上选中与阶段菜单）。
  void applyHandCardTap(int sequence, int code, pkg.CardInfo? info) {
    selectedHandSequence = sequence;
    openZoneBrowserKey = null;
    selectedZoneBrowserSequence = null;
    selectedFieldCard = null;
    showPhaseMenu = false;
    applyInspect(code, info, preserveHandSelection: true);
    emit();
  }

  /// 手牌双击（快捷指令）前的选中态清理。
  void clearSelectionsForHandDoubleTap() {
    selectedHandSequence = null;
    openZoneBrowserKey = null;
    selectedZoneBrowserSequence = null;
    selectedFieldCard = null;
    showPhaseMenu = false;
    emit();
  }

  /// 场上卡点击后的选中态（无可执行动作时传 null 清除选中）。
  void applyFieldCardSelection(FieldCard? card) {
    selectedFieldCard = card;
    selectedHandSequence = null;
    selectedZoneBrowserSequence = null;
    showPhaseMenu = false;
    emit();
  }

  /// 打开区域浏览器（墓地/除外/额外）。
  void openZoneBrowser(String key) {
    selectedHandSequence = null;
    openZoneBrowserKey = key;
    selectedZoneBrowserSequence = null;
    selectedFieldCard = null;
    showPhaseMenu = false;
    emit();
  }

  /// 关闭区域浏览器；原本就未打开时返回 false
  /// （协调器据此决定是否播关闭音效）。
  bool closeZoneBrowser() {
    if (openZoneBrowserKey == null && selectedZoneBrowserSequence == null) {
      return false;
    }
    openZoneBrowserKey = null;
    selectedZoneBrowserSequence = null;
    emit();
    return true;
  }

  /// 区域浏览器内点卡：选中并检视（保留浏览器打开状态）。
  void applyZoneBrowserCardInspect(
    int sequence,
    int code,
    pkg.CardInfo? info,
  ) {
    selectedZoneBrowserSequence = sequence;
    selectedFieldCard = null;
    applyInspect(code, info, preserveZoneBrowser: true);
    emit();
  }

  /// 阶段菜单开关（打开时清掉手牌/场上选中，避免菜单互相遮挡）。
  void setPhaseMenuVisible(bool visible) {
    showPhaseMenu = visible;
    if (visible) {
      selectedHandSequence = null;
      selectedFieldCard = null;
    }
    emit();
  }

  void closePhaseMenu() {
    showPhaseMenu = false;
    emit();
  }

  /// 手牌动作菜单条目触发后的选中态清理。
  void clearHandSelectionAndClosePhaseMenu() {
    selectedHandSequence = null;
    showPhaseMenu = false;
    emit();
  }

  /// 指令响应成功后的选中态清理；[closeZoneBrowser] 为 true 时
  /// 连同区域浏览器一起关闭（浏览器内发动效果的场景）。
  void clearAfterResolvedAction({bool closeZoneBrowser = false}) {
    selectedHandSequence = null;
    selectedFieldCard = null;
    showPhaseMenu = false;
    if (closeZoneBrowser) {
      openZoneBrowserKey = null;
      selectedZoneBrowserSequence = null;
    }
    emit();
  }

  /// 更高优先级窗口出现时的统一让位：清空全部本地弹层选中态
  /// （保留检视抽屉，与原 ChangeNotifier 版一致）。
  void clearLocalUi() {
    selectedHandSequence = null;
    selectedZoneBrowserSequence = null;
    selectedFieldCard = null;
    openZoneBrowserKey = null;
    showPhaseMenu = false;
    emit();
  }

  /// 清空全部浮层状态（离开房间或新对局开始时）。
  void reset() {
    inspectedCardCode = null;
    inspectedCardInfo = null;
    selectedHandSequence = null;
    selectedZoneBrowserSequence = null;
    selectedFieldCard = null;
    openZoneBrowserKey = null;
    showInspector = false;
    showPhaseMenu = false;
  }
}

/// 场地浮层的 Notifier：仅负责持有状态，
/// 交互逻辑全部在 [FieldOverlayState] 内，与 duel_room1 逐字节一致。
class FieldOverlayNotifier extends Notifier<FieldOverlayState> {
  @override
  FieldOverlayState build() {
    final state = FieldOverlayState();
    state.emit = ref.notifyListeners;
    return state;
  }
}

/// 场地浮层状态的 provider，按房间 ProviderScope override 隔离。
final fieldOverlayProvider =
    NotifierProvider<FieldOverlayNotifier, FieldOverlayState>(
  FieldOverlayNotifier.new,
);
