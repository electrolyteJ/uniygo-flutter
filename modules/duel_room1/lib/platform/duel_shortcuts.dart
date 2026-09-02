import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duel_room1/platform/platform_adaptive.dart';

/// 决斗房间页级键盘意图：ESC 用于关闭当前浮层，Enter 用于确认当前弹窗。
class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _ConfirmIntent extends Intent {
  const _ConfirmIntent();
}

/// 包裹决斗房间内容，提供桌面/Web 快捷键：
/// - ESC：按优先级关闭 inspector / 区域浏览器 / 阶段菜单 / 手牌菜单 /
///   场上菜单 / inline 选择 / 卡片确认面板；最终若无可关闭浮层不处理
///   （避免拦截系统返回）。
/// - Enter：确认当前模态选择窗口（yesNo/effectYn 视为确认，
///   card/option 等多选在有合法选项时确认）。
///
/// 快捷键仅在桌面/Web 平台启用；移动端不引入 Focus/Shortcuts 开销。
class DuelShortcuts extends ConsumerWidget {
  final Widget child;

  const DuelShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adaptive = PlatformAdaptive.of(context);
    if (!adaptive.supportsScrollWheel && !adaptive.isDesktop) {
      // 移动端直接透传，不包 Focus/Shortcuts。
      return child;
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _ConfirmIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _ConfirmIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) => _handleEscape(ref),
          ),
          _ConfirmIntent: CallbackAction<_ConfirmIntent>(
            onInvoke: (_) => _handleConfirm(ref),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  /// ESC 关闭优先级：越上层的浮层越先关闭。
  /// 返回 true 表示消费了事件。
  bool _handleEscape(WidgetRef ref) {
    final overlay = ref.read(fieldOverlayProvider);
    final overlayN = ref.read(fieldOverlayProvider.notifier);
    final select = ref.read(selectWindowProvider);
    final selectN = ref.read(selectWindowProvider.notifier);

    // 1. 卡详情抽屉
    if (overlay.showInspector) {
      overlayN.dismissInspector();
      return true;
    }

    // 2. 区域浏览器
    if (overlay.openZoneBrowserKey != null) {
      overlayN.closeZoneBrowser();
      return true;
    }

    // 3. 阶段动作菜单
    if (overlay.showPhaseMenu) {
      overlayN.setPhaseMenuVisible(false);
      return true;
    }

    // 4. 手牌或场上操作菜单：统一清掉本地弹层。
    if (overlay.selectedHandSequence != null || overlay.selectedFieldCard != null) {
      overlayN.clearLocalUi();
      return true;
    }

    // 5. 模态选择窗口：可取消的优先取消。
    if (select.currentSelect != null) {
      if (select.currentSelect!.cancelable) {
        selectN.cancelInlineSelect();
      }
      return true;
    }

    // 6. 卡片确认展示面板（含确认高亮）
    final confirm = ref.read(cardConfirmProvider);
    if (confirm.confirmPanel != null ||
        confirm.confirmedFieldSlotKeys.isNotEmpty ||
        confirm.confirmedHandSequences.isNotEmpty) {
      ref.read(cardConfirmProvider.notifier).dismissConfirmPanel();
      return true;
    }

    // 7. 无可关闭浮层：不消费，让系统返回键/浏览器返回继续处理。
    return false;
  }

  /// Enter 确认当前模态窗口。
  bool _handleConfirm(WidgetRef ref) {
    final select = ref.read(selectWindowProvider);
    final selectN = ref.read(selectWindowProvider.notifier);
    final current = select.currentSelect;
    if (current == null) return false;

    switch (current.type) {
      case SelectType.yesNo:
      case SelectType.effectYn:
        selectN.respondSelectYesNo(true);
        return true;
      case SelectType.card:
      case SelectType.tribute:
      case SelectType.option:
      case SelectType.sort:
      case SelectType.sum:
        // 多选/单选：走确认逻辑（与 inline 的「确认」按钮一致）。
        if (select.inlineSelectCanConfirm) {
          selectN.confirmInlineSelect();
          return true;
        }
        return false;
      case SelectType.unselect:
        if (select.inlineSelectCanConfirm) {
          selectN.finishInlineUnselect();
          return true;
        }
        return false;
      case SelectType.chain:
        // 连锁窗口默认不自动确认，防止误发动。
        return false;
      default:
        return false;
    }
  }
}
