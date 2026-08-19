import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../models/field_card.dart';

const Object _undefined = Object();

/// 场地浮层状态：玩家自己打开的本地查看 UI，不可变快照。
///
/// 与服务器协议无关、不需要回包，随时可被更高优先级的选择窗口挤掉。
/// 卡片检视抽屉（inspector）、区域浏览器（zone browser，墓地/除外/额外）、
/// 阶段菜单（phase menu），以及手牌/场上卡/浏览器卡片的选中态。
///
/// 「玩家自己开的查看浮层」是与对局事实（DuelFieldState，服务器写入）
/// 的本质区别：这些状态完全由本地交互驱动，不来自任何 MSG_* 消息。
class FieldOverlayState {
  const FieldOverlayState({
    this.inspectedCardCode,
    this.inspectedCardInfo,
    this.selectedHandSequence,
    this.selectedZoneBrowserSequence,
    this.selectedFieldCard,
    this.openZoneBrowserKey,
    this.showInspector = false,
    this.showPhaseMenu = false,
  });

  /// 当前检视的卡片（详情抽屉数据源）。
  final int? inspectedCardCode;
  final pkg.CardInfo? inspectedCardInfo;

  /// 当前选中的手牌下标（手牌操作菜单的锚点）。
  final int? selectedHandSequence;

  /// 区域浏览器中选中的卡片下标（浏览器操作菜单的锚点）。
  final int? selectedZoneBrowserSequence;

  /// 当前选中的场上卡（场上操作菜单的锚点）。
  final FieldCard? selectedFieldCard;

  /// 当前打开的区域浏览器 key（`self_grave` / `opp_extra` 等）。
  final String? openZoneBrowserKey;

  final bool showInspector;
  final bool showPhaseMenu;

  /// 是否有任何本地弹层处于打开/选中状态。
  bool get hasAnyOverlayOpen =>
      selectedHandSequence != null ||
      selectedZoneBrowserSequence != null ||
      selectedFieldCard != null ||
      openZoneBrowserKey != null ||
      showPhaseMenu;

  FieldOverlayState copyWith({
    Object? inspectedCardCode = _undefined,
    Object? inspectedCardInfo = _undefined,
    Object? selectedHandSequence = _undefined,
    Object? selectedZoneBrowserSequence = _undefined,
    Object? selectedFieldCard = _undefined,
    Object? openZoneBrowserKey = _undefined,
    bool? showInspector,
    bool? showPhaseMenu,
  }) {
    return FieldOverlayState(
      inspectedCardCode: identical(inspectedCardCode, _undefined)
          ? this.inspectedCardCode
          : inspectedCardCode as int?,
      inspectedCardInfo: identical(inspectedCardInfo, _undefined)
          ? this.inspectedCardInfo
          : inspectedCardInfo as pkg.CardInfo?,
      selectedHandSequence: identical(selectedHandSequence, _undefined)
          ? this.selectedHandSequence
          : selectedHandSequence as int?,
      selectedZoneBrowserSequence:
          identical(selectedZoneBrowserSequence, _undefined)
          ? this.selectedZoneBrowserSequence
          : selectedZoneBrowserSequence as int?,
      selectedFieldCard: identical(selectedFieldCard, _undefined)
          ? this.selectedFieldCard
          : selectedFieldCard as FieldCard?,
      openZoneBrowserKey: identical(openZoneBrowserKey, _undefined)
          ? this.openZoneBrowserKey
          : openZoneBrowserKey as String?,
      showInspector: showInspector ?? this.showInspector,
      showPhaseMenu: showPhaseMenu ?? this.showPhaseMenu,
    );
  }
}

/// 场地浮层的 Notifier：持有全部本地交互（点选/检视/开关浮层）逻辑。
class FieldOverlayNotifier extends Notifier<FieldOverlayState> {
  @override
  FieldOverlayState build() => const FieldOverlayState();

  /// 打开/切换卡片检视。卡信息的异步加载由协调器负责
  /// （卡片缓存收敛在战场状态的 dataService）。
  void applyInspect(
    int code,
    pkg.CardInfo? info, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code <= 0) return;
    var next = state.copyWith(
      inspectedCardCode: code,
      inspectedCardInfo: info,
      showInspector: true,
    );
    if (!preserveHandSelection) {
      next = next.copyWith(selectedHandSequence: null);
    }
    if (!preserveZoneBrowser) {
      next = next.copyWith(
        openZoneBrowserKey: null,
        selectedZoneBrowserSequence: null,
      );
    }
    state = next;
  }

  void dismissInspector() {
    if (!state.showInspector) return;
    state = state.copyWith(showInspector: false);
  }

  /// 手牌单击：选中该手牌并检视（清掉浏览器/场上选中与阶段菜单）。
  void applyHandCardTap(int sequence, int code, pkg.CardInfo? info) {
    var next = state.copyWith(
      selectedHandSequence: sequence,
      openZoneBrowserKey: null,
      selectedZoneBrowserSequence: null,
      selectedFieldCard: null,
      showPhaseMenu: false,
    );
    if (code > 0) {
      next = next.copyWith(
        inspectedCardCode: code,
        inspectedCardInfo: info,
        showInspector: true,
      );
    }
    state = next;
  }

  /// 手牌双击（快捷指令）前的选中态清理。
  void clearSelectionsForHandDoubleTap() {
    state = state.copyWith(
      selectedHandSequence: null,
      openZoneBrowserKey: null,
      selectedZoneBrowserSequence: null,
      selectedFieldCard: null,
      showPhaseMenu: false,
    );
  }

  /// 场上卡点击后的选中态（无可执行动作时传 null 清除选中）。
  void applyFieldCardSelection(FieldCard? card) {
    state = state.copyWith(
      selectedFieldCard: card,
      selectedHandSequence: null,
      selectedZoneBrowserSequence: null,
      showPhaseMenu: false,
    );
  }

  /// 打开区域浏览器（墓地/除外/额外）。
  void openZoneBrowser(String key) {
    state = state.copyWith(
      selectedHandSequence: null,
      openZoneBrowserKey: key,
      selectedZoneBrowserSequence: null,
      selectedFieldCard: null,
      showPhaseMenu: false,
    );
  }

  /// 关闭区域浏览器；原本就未打开时返回 false
  /// （协调器据此决定是否播关闭音效）。
  bool closeZoneBrowser() {
    if (state.openZoneBrowserKey == null &&
        state.selectedZoneBrowserSequence == null) {
      return false;
    }
    state = state.copyWith(
      openZoneBrowserKey: null,
      selectedZoneBrowserSequence: null,
    );
    return true;
  }

  /// 区域浏览器内点卡：选中并检视（保留浏览器打开状态）。
  void applyZoneBrowserCardInspect(int sequence, int code, pkg.CardInfo? info) {
    var next = state.copyWith(
      selectedZoneBrowserSequence: sequence,
      selectedFieldCard: null,
    );
    if (code > 0) {
      next = next.copyWith(
        inspectedCardCode: code,
        inspectedCardInfo: info,
        showInspector: true,
      );
    }
    state = next;
  }

  /// 阶段菜单开关（打开时清掉手牌/场上选中，避免菜单互相遮挡）。
  void setPhaseMenuVisible(bool visible) {
    state = state.copyWith(
      showPhaseMenu: visible,
      selectedHandSequence: visible ? null : state.selectedHandSequence,
      selectedFieldCard: visible ? null : state.selectedFieldCard,
    );
  }

  void closePhaseMenu() {
    state = state.copyWith(showPhaseMenu: false);
  }

  /// 手牌动作菜单条目触发后的选中态清理。
  void clearHandSelectionAndClosePhaseMenu() {
    state = state.copyWith(selectedHandSequence: null, showPhaseMenu: false);
  }

  /// 指令响应成功后的选中态清理；[closeZoneBrowser] 为 true 时
  /// 连同区域浏览器一起关闭（浏览器内发动效果的场景）。
  void clearAfterResolvedAction({bool closeZoneBrowser = false}) {
    state = state.copyWith(
      selectedHandSequence: null,
      selectedFieldCard: null,
      showPhaseMenu: false,
      openZoneBrowserKey: closeZoneBrowser ? null : state.openZoneBrowserKey,
      selectedZoneBrowserSequence: closeZoneBrowser
          ? null
          : state.selectedZoneBrowserSequence,
    );
  }

  /// 更高优先级窗口出现时的统一让位：清空全部本地弹层选中态
  /// （保留检视抽屉，与原实现一致）。
  void clearLocalUi() {
    state = state.copyWith(
      selectedHandSequence: null,
      selectedZoneBrowserSequence: null,
      selectedFieldCard: null,
      openZoneBrowserKey: null,
      showPhaseMenu: false,
    );
  }
}

/// 场地浮层状态的 provider，按房间 ProviderScope override 隔离。
final fieldOverlayProvider =
    NotifierProvider<FieldOverlayNotifier, FieldOverlayState>(
      FieldOverlayNotifier.new,
    );
