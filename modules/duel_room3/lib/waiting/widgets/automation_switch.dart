import 'package:flutter/material.dart';

import '../../hud/hud_theme.dart';

/// 自动化开关（赛博暗色配色版），布局对齐 duel_room1 的 automation_switch。
///
/// 值开启时用金色滑块 + 青色轨道强调；关闭/禁用时回落到面板描边色，
/// 与 room3 的 HudTheme 一致。
class AutomationSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const AutomationSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final thumbColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return HudTheme.textSecondary;
      return value ? HudTheme.gold : HudTheme.textSecondary;
    });
    final trackColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return HudTheme.panelBorder;
      return value ? HudTheme.cyanDim : HudTheme.panelBorder;
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
          style: HudTheme.caption.copyWith(color: HudTheme.textPrimary),
        ),
        const SizedBox(width: 6),
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
}
