import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../models/duel_menu.dart';
import 'hand_action_popover.dart';

class FieldActionPopover extends StatelessWidget {
  final List<ActionMenuEntry> actions;

  /// 锚点在 popover 坐标系内的 x 位置（用于对齐底部箭头）。
  final double? arrowDx;

  const FieldActionPopover({super.key, required this.actions, this.arrowDx});

  @override
  Widget build(BuildContext context) {
    return HandActionPopover(actions: actions, arrowDx: arrowDx);
  }
}

@Preview(name: 'FieldActionPopover', size: Size(240, 200), brightness: Brightness.dark)
Widget previewFieldActionPopover() => FieldActionPopover(
      actions: [
        ActionMenuEntry(label: '发动效果', onTap: () {}),
        ActionMenuEntry(label: '查看详情', onTap: () {}),
      ],
    );

