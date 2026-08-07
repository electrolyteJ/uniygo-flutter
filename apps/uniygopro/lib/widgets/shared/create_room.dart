
// ────────────────────────────────────────────────────────────
// Shared UI helpers
// ────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget sheetContainer({required Widget child}) {
  // 用 Material 而非 DecoratedBox：ListTile 家族（ListTile/SwitchListTile/
  // ExpansionTile 等）会把背景与 ink 水波绘制在最近的 Material 祖先上，
  // 中间夹 DecoratedBox 会遮挡这些效果并触发框架断言。
  return Material(
    color: const Color(0xFF1E2A38),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.blueGrey.shade600, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
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
      labelText: label, hintText: hintText,
      hintStyle: TextStyle(color: Colors.blueGrey.shade500),
      labelStyle: TextStyle(color: Colors.blueGrey.shade300),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey.shade400) : null,
      filled: true, fillColor: Colors.blueGrey.shade800,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
    onSubmitted: onSubmitted,
  );
}





Widget connectButton({required String label, required bool connecting, required VoidCallback onPressed}) {
  return SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: connecting ? null : onPressed,
      icon: connecting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

Widget numberRow(String label, int value, ValueChanged<int> onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14))),
      IconButton(icon: Icon(Icons.remove_circle_outline, color: Colors.blueGrey.shade300, size: 22),
          onPressed: value > 0 ? () => onChanged(value - 1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)),
      SizedBox(width: 48, child: Text('$value', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
      IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.amber, size: 22),
          onPressed: () => onChanged(value + 1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)),
    ]),
  );
}

Widget dropdownRow<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14))),
      const SizedBox(width: 12),
      Expanded(
        child: DropdownButtonFormField<T>(
          isExpanded: true,
          value: value, items: items, onChanged: onChanged,
          dropdownColor: Colors.blueGrey.shade800,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            filled: true, fillColor: Colors.blueGrey.shade800,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ),
    ]),
  );
}

Widget checkRow(String label, bool value, ValueChanged<bool?> onChanged) {
  return Expanded(
    child: Row(children: [
      SizedBox(width: 24, height: 24, child: Checkbox(value: value, onChanged: onChanged,
          activeColor: Colors.amber, checkColor: Colors.blueGrey.shade900, side: BorderSide(color: Colors.blueGrey.shade400))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13)),
    ]),
  );
}

