import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

Widget buildAutomationSwitch({
  required String label,
  required bool value,
  required bool enabled,
  required ValueChanged<bool> onChanged,
}) {
  final thumbColor = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.blueGrey.shade500;
    }
    return value ? Colors.amber.shade400 : Colors.blueGrey.shade100;
  });
  final trackColor = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.blueGrey.shade700;
    }
    return value ? Colors.amber.shade700 : Colors.blueGrey.shade600;
  });
  final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed)) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.transparent;
  });
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12),
      ),
      const SizedBox(width: 4),
      Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        thumbColor: thumbColor,
        trackColor: trackColor,
        overlayColor: overlayColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}

@Preview(name: 'AutomationSwitch', size: Size(220, 48), brightness: Brightness.dark)
Widget previewAutomationSwitch() => buildAutomationSwitch(
      label: '自动猜拳',
      value: true,
      enabled: true,
      onChanged: (_) {},
    );
