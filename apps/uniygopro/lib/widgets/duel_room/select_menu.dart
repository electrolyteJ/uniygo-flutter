import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';

class SelectMenu extends StatelessWidget {
  final List<IdleAction> actions;
  final void Function(IdleAction action) onSelect;
  const SelectMenu({super.key, required this.actions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1722).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.shade600, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 6),
              Text(
                '请选择行动',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final action in actions)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade900.withOpacity(0.8),
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => onSelect(action),
                  child: Text(
                    _labelFor(action),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _labelFor(IdleAction action) {
    switch (action.type) {
      case 1:
        return '召唤';
      case 2:
        return '盖放';
      case 3:
        return '发动效果';
      case 4:
        return '特殊召唤';
      case 5:
        return '改变表示形式';
      default:
        return '行动 #${action.sequence}';
    }
  }
}
