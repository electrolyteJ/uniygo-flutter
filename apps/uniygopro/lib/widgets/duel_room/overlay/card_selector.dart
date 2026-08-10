import 'dart:developer' as console;

import 'package:flutter/material.dart';

import '../../../models/SelectState.dart';
import '../../shared/card_image.dart';

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
        const horizontalPadding = 32.0;
        // 弹窗最小宽度按 3 张卡片计算，卡片少时居中展示而不缩窄。
        const minCardCount = 3;
        final count = select.options.length;
        final contentWidth = itemWidth * count;
        final wrapsContent =
            contentWidth <= constraints.maxWidth - horizontalPadding;
        final minWidth = itemWidth * minCardCount + horizontalPadding;
        final panelWidth = wrapsContent
            ? (contentWidth + horizontalPadding).clamp(
                minWidth,
                constraints.maxWidth,
              )
            : constraints.maxWidth;
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
                child: wrapsContent
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            _buildCardItem(i, select),
                        ],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              _buildCardItem(i, select),
                          ],
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
            CardImage(code: option.code, width: 92, height: 132),
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
}
