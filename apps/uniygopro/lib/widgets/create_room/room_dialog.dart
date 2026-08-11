// ────────────────────────────────────────────────────────────
// Shared UI helpers
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget sheetContainer({required Widget child}) {
  // 用 Material 而非 DecoratedBox：ListTile 家族（ListTile/SwitchListTile/
  // ExpansionTile 等）会把背景与 ink 水波绘制在最近的 Material 祖先上，
  // 中间夹 DecoratedBox 会遮挡这些效果并触发框架断言。
  // 居中弹窗样式：四角圆角，无底部弹窗的顶部拖拽条。
  return Material(
    color: const Color(0xFF1E2A38),
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

/// 以居中弹窗（Dialog）展示建房/加入房间面板，替代底部弹窗。
/// Dialog 背景透明，由内部 [sheetContainer] 提供实际背景与圆角。
Future<T?> showRoomDialog<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      final mediaQuery = MediaQuery.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: mediaQuery.size.height * 0.88,
          ),
          child: child,
        ),
      );
    },
  );
}

Widget darkTextField({
  required TextEditingController controller,
  required String label,
  String? hintText,
  IconData? icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.blueGrey.shade500),
      labelStyle: TextStyle(color: Colors.blueGrey.shade300),
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.blueGrey.shade400)
          : null,
      filled: true,
      fillColor: Colors.blueGrey.shade800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    onSubmitted: onSubmitted,
  );
}

Widget connectButton({
  Key? key,
  required String label,
  required bool connecting,
  required VoidCallback onPressed,
  VoidCallback? onTapFeedback,
}) {
  return SizedBox(
    height: 48,
    child: FilledButton.icon(
      key: key,
      onPressed: connecting
          ? null
          : () {
              onTapFeedback?.call();
              onPressed();
            },
      icon: connecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.play_arrow),
      label: Text(connecting ? '连接中...' : label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

Widget numberRow(
  String label,
  int value,
  ValueChanged<int> onChanged, {
  int min = 0,
  int max = 999999,
}) {
  return _NumberInputRow(
    label: label,
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
  );
}

class _NumberInputRow extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberInputRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberInputRow> createState() => _NumberInputRowState();
}

class _NumberInputRowState extends State<_NumberInputRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  int get _clampedValue => widget.value.clamp(widget.min, widget.max);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '$_clampedValue');
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _NumberInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = '$_clampedValue';
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    final nextValue = (parsed ?? widget.value).clamp(widget.min, widget.max);
    final nextText = '$nextValue';
    if (_controller.text != nextText) {
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '${widget.min}-${widget.max}',
                hintStyle: TextStyle(color: Colors.blueGrey.shade500),
                filled: true,
                fillColor: Colors.blueGrey.shade800,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ],
      ),
    );
  }
}

Widget dropdownRow<T>({
  required String label,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<T>(
            isExpanded: true,
            initialValue: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: Colors.blueGrey.shade800,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              filled: true,
              fillColor: Colors.blueGrey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget checkRow(String label, bool value, ValueChanged<bool?> onChanged) {
  return Expanded(
    child: Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.amber,
            checkColor: Colors.blueGrey.shade900,
            side: BorderSide(color: Colors.blueGrey.shade400),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13),
        ),
      ],
    ),
  );
}
