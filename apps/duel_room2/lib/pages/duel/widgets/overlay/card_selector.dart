import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/widgets/card_image.dart';
import '../../models/select_state.dart';

@Preview(name: 'CardSelector', size: Size(500, 320), brightness: Brightness.dark)
Widget previewCardSelector() => CardSelector(
      select: const SelectState(
        type: SelectType.card,
        player: 0,
        options: [
          SelectOption(code: 89631139),
          SelectOption(code: 46986414),
          SelectOption(code: 15025844),
        ],
        min: 1,
        max: 2,
        cancelable: true,
      ),
      onSelect: (_) {},
      onCancel: () {},
      onInspectCard: (_) {},
    );

class CardSelector extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> indices) onSelect;
  final VoidCallback onCancel;
  final void Function(int code) onInspectCard;

  /// SUM 窗口的选择合法性判定（业务侧注入
  /// SelectWindowNotifier.isSumSelectionValid）。为 null 时回退
  /// 「已选数量非空」。仅 [SelectType.sum] 使用。
  final bool Function(Set<int> selectedIndices)? isSumSelectionValid;

  const CardSelector({
    super.key,
    required this.select,
    required this.onSelect,
    required this.onCancel,
    required this.onInspectCard,
    this.isSumSelectionValid,
  });

  @override
  State<CardSelector> createState() => _CardSelectorState();
}

class _CardSelectorState extends State<CardSelector> {
  final List<int> _selectedIndices = [];

  bool get _isSum => widget.select.type == SelectType.sum;

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

  /// 确认按钮可用性：SUM 窗口由 isSumSelectionValid 判定（合计语义），
  /// 其余类型沿用数量 >= min 判定。
  bool get _canConfirm {
    if (_isSum) {
      return widget.isSumSelectionValid?.call(_selectedIndices.toSet()) ??
          _selectedIndices.isNotEmpty;
    }
    return _selectedIndices.length >= widget.select.min;
  }

  /// SUM 窗口当前合计：必选卡与已选卡的参数 1（level）之和。
  /// level2 仅在选项徽章上展示（引擎两种合计模式都探索），
  /// 提示行以参数 1 为准。
  int _sumCurrentTotal() {
    final select = widget.select;
    var total = 0;
    for (final option in select.mustOptions) {
      total += option.level ?? 0;
    }
    for (final index in _selectedIndices) {
      if (index >= 0 && index < select.options.length) {
        total += select.options[index].level ?? 0;
      }
    }
    return total;
  }

  String _headerText(SelectState select) {
    if (select.immediateSingleToggle) {
      return '已选择 ${_selectedIndices.length} 张卡'
          '，继续点卡切换，满足条件后完成';
    }
    if (_isSum) {
      final total = _sumCurrentTotal();
      return select.sumExact
          ? '当前合计 $total / 目标 ${select.sumTarget}'
          : '当前合计 $total（目标 ${select.sumTarget}）';
    }
    return '选择 ${select.min}-${select.max} 张卡'
        ' (${_selectedIndices.length}/${select.max})';
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    final mustOptions = _isSum ? select.mustOptions : const <SelectOption>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 108.0;
        final count = math.max(select.options.length, mustOptions.length);
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
                _headerText(select),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (mustOptions.isNotEmpty) ...[
                _buildMustSection(mustOptions),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 144,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(
                    child: Row(
                      children: [
                        for (var i = 0; i < select.options.length; i++)
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
                      onPressed: _canConfirm ? _confirmSelection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canConfirm
                            ? const Color(0xFF00F0FF)
                            : Colors.grey.shade800,
                        foregroundColor: _canConfirm
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
                      onPressed: _canConfirm ? _finishImmediateSelection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canConfirm
                            ? const Color(0xFF00F0FF)
                            : Colors.grey.shade800,
                        foregroundColor: _canConfirm
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

  /// SUM 窗口的必选卡区：锁定、不可切换勾选，仅支持点击查看。
  Widget _buildMustSection(List<SelectOption> mustOptions) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              '必选卡（已锁定，共 ${mustOptions.length} 张）',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 144,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center(
              child: Row(
                children: [
                  for (final option in mustOptions) _buildMustCardItem(option),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMustCardItem(SelectOption option) {
    return GestureDetector(
      onTap: () => widget.onInspectCard(option.code),
      child: Container(
        width: 100,
        height: 144,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            if (option.code > 0)
              CardImage(code: option.code, width: 92, height: 132)
            else
              _buildEmptySlotPlaceholder(),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.lock, size: 12, color: Color(0xFFFFD700)),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: _buildLevelBadge(option),
            ),
          ],
        ),
      ),
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
            if (_isSum)
              Positioned(
                top: 4,
                left: 4,
                child: _buildLevelBadge(option),
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

  /// SUM 选项的数值徽章：展示参数 1（level）；
  /// 参数 2（level2）存在且与参数 1 不同时以 `level/level2` 展示。
  Widget _buildLevelBadge(SelectOption option) {
    final level = option.level;
    if (level == null) return const SizedBox.shrink();
    final level2 = option.level2;
    final showSecond = level2 != null && level2 != 0 && level2 != level;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        showSecond ? '$level/$level2' : 'Lv $level',
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _toggleSelection(int index, SelectState select) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_isSum || _selectedIndices.length < select.max) {
        // SUM 窗口按合计判定（isSumSelectionValid），不做数量上限约束；
        // 其余类型保留 max 数量上限。
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
