import 'package:flutter/material.dart';

import '../../models/SelectState.dart';

class CardSelector extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> sequences) onSelect;
  final VoidCallback onCancel;

  const CardSelector({super.key, required this.select, required this.onSelect, required this.onCancel});

  @override
  State<CardSelector> createState() => _CardSelectorState();
}

class _CardSelectorState extends State<CardSelector> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('选择 ${select.min}-${select.max} 张卡', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        SizedBox(height: 100, child: ListView.builder(
          scrollDirection: Axis.horizontal, itemCount: select.options.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _toggleSelection(i, select),
            child: Container(
              width: 70, height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _selectedIndices.contains(i) ? Colors.green.shade300 : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
                border: _selectedIndices.contains(i) ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Center(child: Text('${select.options[i].code}', style: const TextStyle(fontSize: 10))),
            ),
          ),
        )),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (select.cancelable)
            TextButton(onPressed: widget.onCancel, child: const Text('取消', style: TextStyle(color: Colors.red))),
          if (_selectedIndices.length >= select.min)
            ElevatedButton(
              onPressed: _confirmSelection,
              child: const Text('确认'),
            ),
        ]),
      ]),
    );
  }

  void _toggleSelection(int index, SelectState select) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length < select.max) {
        _selectedIndices.add(index);
      }
    });
  }

  void _confirmSelection() {
    final sequences = _selectedIndices
        .map((i) => widget.select.options[i].sequence)
        .toList();
    widget.onSelect(sequences);
  }
}
