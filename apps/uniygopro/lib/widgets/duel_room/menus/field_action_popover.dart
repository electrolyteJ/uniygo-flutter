import 'package:flutter/material.dart';

import 'hand_action_menu.dart';
import 'hand_action_popover.dart';

class FieldActionPopover extends StatelessWidget {
  final List<HandActionMenuEntry> actions;

  /// 锚点在 popover 坐标系内的 x 位置（用于对齐底部箭头）。
  final double? arrowDx;

  const FieldActionPopover({super.key, required this.actions, this.arrowDx});

  @override
  Widget build(BuildContext context) {
    return HandActionPopover(actions: actions, arrowDx: arrowDx);
  }
}
