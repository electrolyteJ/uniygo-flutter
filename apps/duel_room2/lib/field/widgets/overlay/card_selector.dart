import 'dart:math' as math;

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/widgets/card_image.dart';
import 'package:biz/duel/models/select_state.dart';

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
      myController: 0,
    );

class CardSelector extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> indices) onSelect;
  final VoidCallback onCancel;
  final void Function(int code) onInspectCard;

  /// 当前玩家（响应方）在引擎侧的 controller 编号（0/1）。
  /// 用于把选项的 controller 翻译成「我/对」区域徽章，
  /// 避免硬编码 controller 0 为「我方」。
  final int myController;

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
    required this.myController,
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
    // 引擎下发的选择提示优先（如「请选择攻击对象」）；多选时附推进度。
    final hint = select.hint;
    if (hint != null && hint.isNotEmpty) {
      return select.max > 1
          ? '$hint (${_selectedIndices.length}/${select.max})'
          : hint;
    }
    if (select.min == select.max) {
      return select.max == 1
          ? '请选择 1 张卡'
          : '请选择 ${select.max} 张卡'
              ' (${_selectedIndices.length}/${select.max})';
    }
    return '请选择 ${select.min}-${select.max} 张卡'
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
              _buildFaceDownPlaceholder(),
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
              _buildFaceDownPlaceholder(),
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
            // 区域徽章：区分卡组/手牌/怪兽区/魔陷区/墓地/除外/额外等来源。
            Positioned(
              top: 2,
              right: 2,
              child: _buildLocationBadge(option),
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

  /// 区域徽章：展示该卡来自哪个区域（卡组/手牌/怪兽区/魔陷区/墓地/除外等）。
  Widget _buildLocationBadge(SelectOption option) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x3300F0FF)),
      ),
      child: Text(
        _optionLocationLabel(option, widget.myController),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 8,
          fontWeight: FontWeight.w700,
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

  /// 里侧表示卡（code == 0，客户端拿不到卡码）的卡背占位：
  /// 深色卡背 + 「里侧」标签，避免被误认为空槽位。
  Widget _buildFaceDownPlaceholder() {
    return Container(
      width: 92,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D5A73), Color(0xFF1E2F45)],
        ),
        border: Border.all(color: const Color(0x6600F0FF), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.help_outline, color: Colors.white38, size: 22),
            SizedBox(height: 3),
            Text(
              '里侧',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选项来源区域文案：把 [SelectOption] 的 controller/zone 翻译成可读标签。
///
/// controller 与 [myController] 相等即为「我方」，否则「对方」；
/// zone 用 ygopro CARD_ZONE_* 常量区分卡组/手牌/怪兽区/魔陷区/墓地/除外/额外等。
String _optionLocationLabel(SelectOption option, int myController) {
  final prefix = option.controller == myController ? '我' : '对';
  final zone = option.zone;
  if (zone == CARD_ZONE_DECK) return '$prefix 卡组';
  if (zone == CARD_ZONE_HAND) return '$prefix 手牌';
  if (zone == CARD_ZONE_MZONE) return '$prefix 怪兽区';
  if (zone == CARD_ZONE_SZONE) return '$prefix 魔陷区';
  if (zone == CARD_ZONE_GRAVE) return '$prefix 墓地';
  if (zone == CARD_ZONE_REMOVED) return '$prefix 除外';
  if (zone == CARD_ZONE_EXTRA) return '$prefix 额外';
  if (zone == LOCATION_OVERLAY) return '$prefix 素材';
  if (zone == CARD_ZONE_FZONE) return '$prefix 场地';
  if (zone == CARD_ZONE_PZONE) return '$prefix 灵摆';
  return '$prefix 区域$zone';
}
