import 'dart:math' as math;

import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// MSG_SELECT_COUNTER 模态弹窗：为每张候选卡分配要移除的指示物数量。
///
/// 移植自 modules/duel_room2/.../counter_allocator_dialog.dart（对齐功能，
/// 样式换 HudTheme）：仅当分配总数恰好等于 [SelectState.counterRequired]
/// 时才允许确认，确认后经 [onSubmit] 回传与 options 等长的分配数组。
class CounterAllocatorDialog extends StatefulWidget {
  const CounterAllocatorDialog({
    super.key,
    required this.select,
    required this.cardNameBuilder,
    required this.onSubmit,
    this.onCancel,
  });

  final SelectState select;
  final String Function(int code) cardNameBuilder;

  /// 确认时回传每张卡的分配数量（下标与 [SelectState.options] 对齐）。
  final void Function(List<int> counts) onSubmit;

  /// 取消回调；为 null 时不显示取消按钮（计数器窗口通常不可取消）。
  final VoidCallback? onCancel;

  @override
  State<CounterAllocatorDialog> createState() =>
      _CounterAllocatorDialogState();
}

class _CounterAllocatorDialogState extends State<CounterAllocatorDialog> {
  late List<int> _counts;

  @override
  void initState() {
    super.initState();
    _resetCounts();
  }

  @override
  void didUpdateWidget(covariant CounterAllocatorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.select, widget.select)) {
      _resetCounts();
    }
  }

  void _resetCounts() {
    _counts = List<int>.filled(widget.select.options.length, 0);
  }

  int _maxCountFor(int index) =>
      math.max(0, widget.select.options[index].level ?? 0);

  int get _allocatedTotal => _counts.fold(0, (sum, value) => sum + value);

  void _changeCount(int index, int delta) {
    setState(() {
      _counts[index] = (_counts[index] + delta).clamp(0, _maxCountFor(index));
    });
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    final required = select.counterRequired;
    final total = _allocatedTotal;
    final canConfirm = total == required;

    return Container(
      width: 460,
      constraints: const BoxConstraints(maxHeight: 420),
      padding: const EdgeInsets.all(16),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            select.hint ?? '移除指示物',
            textAlign: TextAlign.center,
            style: HudTheme.title,
          ),
          const SizedBox(height: 4),
          Text(
            '为每张卡分配要移除的指示物数量',
            textAlign: TextAlign.center,
            style: HudTheme.caption,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: select.options.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: HudTheme.panelBorder, height: 1),
              itemBuilder: (context, index) =>
                  _buildOptionRow(index, select.options[index]),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '已分配 $total / 需 $required',
              style: HudTheme.body.copyWith(
                color: canConfirm ? HudTheme.cyan : HudTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    '取消',
                    style: TextStyle(color: HudTheme.danger),
                  ),
                ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HudTheme.cyanDim,
                  disabledBackgroundColor: Colors.grey.shade800,
                ),
                onPressed: canConfirm
                    ? () => widget.onSubmit(List<int>.of(_counts))
                    : null,
                child: const Text('确认'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(int index, SelectOption option) {
    final count = _counts[index];
    final maxCount = _maxCountFor(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CardImage(code: option.code, width: 48, height: 68),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cardNameBuilder(option.code),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HudTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('可用指示物：$maxCount', style: HudTheme.caption),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count > 0 ? () => _changeCount(index, -1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: HudTheme.danger,
            disabledColor: Colors.grey.shade700,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: HudTheme.body.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count < maxCount ? () => _changeCount(index, 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: HudTheme.cyan,
            disabledColor: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}
