import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../models/SelectState.dart';

class PositionSelector extends StatelessWidget {
  final SelectState? select;
  final void Function(int position) onSelect;
  const PositionSelector({super.key, this.select, required this.onSelect});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton(onPressed: () => onSelect(0x1), child: const Text('表侧攻击')),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: () => onSelect(0x4), child: const Text('表侧守备')),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: () => onSelect(0x8), child: const Text('里侧守备')),
    ],
  );
}

@Preview(name: 'PositionSelector', size: Size(360, 60))
Widget positionSelectorPreview() => PositionSelector(onSelect: _noop);

void _noop(int position) {}
