// ────────────────────────────────────────────────────────────
// Environment selector (used inside free room sheet)
// ────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/servers.dart';
import '../shared/create_room.dart';

/// Shared env selector row for both join and create forms.
class EnvSelector extends StatelessWidget {
  final DuelEnvironment value;
  final ValueChanged<DuelEnvironment> onChanged;

  const EnvSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return dropdownRow<DuelEnvironment>(
      label: '对战环境',
      value: value,
      items: DuelEnvironment.values.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}
