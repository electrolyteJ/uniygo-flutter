// ────────────────────────────────────────────────────────────
// Environment selector (used inside free room sheet)
// ────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/servers.dart';
import '../create_room/room_dialog.dart';
import 'package:flutter/widget_previews.dart';

/// Shared env selector row for both join and create forms.
class EnvSelector extends StatelessWidget {
  final DuelEnvironment value;
  final ValueChanged<DuelEnvironment> onChanged;

  const EnvSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // AI 对决和残局挑战已作为独立服务器入口，不再出现在自由房的环境选择器里。
    final envs = DuelEnvironment.values.where((e) => !e.isAi && !e.isPuzzle).toList();
    return dropdownRow<DuelEnvironment>(
      label: '对战环境',
      value: value,
      items: envs.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}
@Preview(name: 'EnvSelector', size: Size(300, 60), brightness: Brightness.dark)
Widget _previewEnvSelector() => EnvSelector(value: DuelEnvironment.koishi, onChanged: (_) {});

