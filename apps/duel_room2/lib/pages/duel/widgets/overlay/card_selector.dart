import 'dart:developer' as console;

import 'package:flutter/material.dart';

import '../../../../widgets/card_image.dart';
import '../../models/select_state.dart';

class CardSelector extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> indices) onSelect;
  final VoidCallback onCancel;
  final void Function(int code) onInspectCard;

  const CardSelector({
    super.key,
    required this.select,
    required this.onSelect,
    required this.onCancel,
    required this.onInspectCard,
  });

  @override
  State<CardSelector> createState() => _CardSelectorState();
}

class _CardSelectorState extends State<CardSelector> {
  final List<int> _selectedIndices = [];

  @override
  void initState() {
    super.initState();
    _resetSelectionFromWidget();
  }

  @override
  void didUpdateWidget(covariant CardSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.select, widget.select)) {
      _resetSelectionFromWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    console.log(
      'CardSelector build: ${select.options.length} options, min=${select.min}, max=${select.max}',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 108.0;
        final count = select.options.length;
        final panelWidth = (itemWidth * count + 32.0)
            .clamp(itemWidth * 3 + 32.0, constraints.maxWidth);
        return Container(
          width: panelWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                select.immediateSingleToggle
                    ? '已选择 ${_selectedIndices.length} 张卡'
                        '，继续点卡切换，满足条件后完成'
                    : '选择 ${select.min}-${select.max} 张卡'
                        ' (${_selectedIndices.length}/${select.max})',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 144,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(
                    child: Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          _buildCardItem(i, select),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (select.cancelable)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  if (!select.immediateSingleToggle) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _selectedIndices.length >= select.min
                          ? _confirmSelection
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndices.length >= select.min
                            ? const Color(0xFF00F0FF)
                            : Colors.grey.shade800,
                        foregroundColor: _selectedIndices.length >= select.min
                            ? Colors.black
                            : Colors.grey.shade500,
                        disabledBackgroundColor: Colors.grey.shade800,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                      child: const Text('确认'),
                    ),
                  ],
                  if (select.immediateSingleToggle && select.finishable) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _selectedIndices.length >= select.min
                          ? _finishImmediateSelection
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndices.length >= select.min
                            ? const Color(0xFF00F0FF)
                            : Colors.grey.shade800,
                        foregroundColor: _selectedIndices.length >= select.min
                            ? Colors.black
                            : Colors.grey.shade500,
                        disabledBackgroundColor: Colors.grey.shade800,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                      child: const Text('完成'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardItem(int index, SelectState select) {
    final option = select.options[index];
    final selected = _selectedIndices.contains(index);
    return GestureDetector(
      onTap: () {
        widget.onInspectCard(option.code);
        if (select.immediateSingleToggle) {
          widget.onSelect([index]);
          return;
        }
        _toggleSelection(index, select);
      },
      child: Container(
        width: 100,
        height: 144,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            if (option.code > 0)
              CardImage(code: option.code, width: 92, height: 132)
            else
              _buildEmptySlotPlaceholder(),
            if (!selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF00F0FF),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x6600F0FF),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (option.label != null &&
                option.label!.isNotEmpty &&
                select.type == SelectType.option)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}. ${option.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
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
    widget.onSelect(List<int>.of(_selectedIndices));
  }

  void _finishImmediateSelection() {
    widget.onSelect(const []);
  }

  void _resetSelectionFromWidget() {
    _selectedIndices
      ..clear()
      ..addAll(widget.select.initialSelectedIndices);
  }

  Widget _buildEmptySlotPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade700, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
        ),
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.white24, size: 24),
      ),
    );
  }
}
