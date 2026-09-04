import 'package:flutter/material.dart';

/// 自动化开关：带语义标签的「文字 + Switch」行（最小高 44、最大宽 190）。
class AutomationSwitch extends StatelessWidget {
  const AutomationSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
    return Semantics(
      container: true,
      label: label,
      enabled: enabled,
      toggled: value,
      onTap: enabled ? () => onChanged(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, maxWidth: 190),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade200,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  thumbColor: thumbColor,
                  trackColor: trackColor,
                  overlayColor: overlayColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
