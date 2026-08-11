import 'package:flutter/material.dart';

import '../../../models/select_state.dart';

/// 选择提示层：放置提示横幅、就地选择操作栏或模态弹窗（三者互斥）。
///
/// 纯 UI 组件：呈现方式与业务数据均由页面组装后通过 props 传入，
/// 交互结果通过回调交还业务侧处理。
/// 页面在 Stack 中以 Positioned.fill 插入本层；modal 阻断全屏点击，
/// place/inline 仅局部区域响应。
class SelectPromptLayer extends StatelessWidget {
  final SelectPromptMode mode;

  /// place 模式：可放置槽位数（仅用于文案提示）。
  final int placeTargetCount;

  /// inline 模式：操作栏数据与回调。
  final String inlineHint;
  final String? inlineCancelLabel;
  final bool inlineShowFinish;
  final bool inlineShowConfirm;
  final bool inlineCanConfirm;
  final VoidCallback? onInlineCancel;
  final VoidCallback? onInlineFinish;
  final VoidCallback? onInlineConfirm;

  /// modal 模式：页面组装好的选择弹窗。
  final Widget? modalChild;

  const SelectPromptLayer({
    super.key,
    required this.mode,
    this.placeTargetCount = 0,
    this.inlineHint = '',
    this.inlineCancelLabel,
    this.inlineShowFinish = false,
    this.inlineShowConfirm = false,
    this.inlineCanConfirm = false,
    this.onInlineCancel,
    this.onInlineFinish,
    this.onInlineConfirm,
    this.modalChild,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case SelectPromptMode.none:
        return const SizedBox.shrink();
      case SelectPromptMode.place:
        return _buildPlaceHint();
      case SelectPromptMode.inline:
        return _buildInlineBar();
      case SelectPromptMode.modal:
        return _buildModalOverlay();
    }
  }

  static const double _placeHintTop = 136.0;

  /// 放置选择（MSG_SELECT_PLACE）的提示横幅；可放置槽位的高亮与点击
  /// 已下沉到场地槽位组件本身，此处仅保留文案提示，不拦截点击。
  Widget _buildPlaceHint() {
    return Stack(
      children: [
        Positioned(
          top: _placeHintTop,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: _panelDecoration,
                child: Text(
                  '请选择放置区域${placeTargetCount == 1 ? '' : '（可选 $placeTargetCount 处）'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 就地选择的操作栏：提示文案 + 取消/确认/完成，置于手牌栏上方。
  Widget _buildInlineBar() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 126,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: _panelDecoration,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inlineHint,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (inlineCancelLabel != null) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onInlineCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(inlineCancelLabel!),
                    ),
                  ],
                  if (inlineShowFinish) ...[
                    const SizedBox(width: 4),
                    _actionButton(
                      label: '完成',
                      enabled: inlineCanConfirm,
                      onPressed: onInlineFinish,
                    ),
                  ] else if (inlineShowConfirm) ...[
                    const SizedBox(width: 4),
                    _actionButton(
                      label: '确认',
                      enabled: inlineCanConfirm,
                      onPressed: onInlineConfirm,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 模态弹窗：遮罩全屏并居中展示页面组装好的选择组件。
  Widget _buildModalOverlay() {
    final child = modalChild;
    if (child == null) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  static final _panelDecoration = BoxDecoration(
    color: const Color(0xE6111722),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  );

  Widget _actionButton({
    required String label,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00F0FF),
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.grey.shade500,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label),
    );
  }
}
