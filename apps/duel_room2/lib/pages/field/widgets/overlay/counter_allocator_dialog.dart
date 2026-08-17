import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/widgets/card_image.dart';
import '../../models/select_state.dart';

/// MSG_SELECT_COUNTER 模态弹窗：为每张候选卡分配要移除的指示物数量。
///
/// 约定（与状态层契约一致）：
/// - [SelectState.options] 为全部候选卡，[SelectOption.level] 为该卡
///   当前可用的指示物数（每张卡可分配 0..level 个）；
/// - [SelectState.counterRequired] 为需要移除的指示物总数；
/// - 仅当已分配总数恰好等于 [SelectState.counterRequired] 时才允许确认，
///   确认后经 [onSubmit] 回传与 options 等长的分配数组，
///   由页面调用 `respondSelectCounter(counts, generation: ...)`。
@Preview(name: 'CounterAllocatorDialog', size: Size(560, 400), brightness: Brightness.dark)
Widget previewCounterAllocatorDialog() => CounterAllocatorDialog(
      select: const SelectState(
        type: SelectType.counter,
        player: 0,
        options: [
          SelectOption(code: 89631139, level: 3),
          SelectOption(code: 46986414, level: 2),
        ],
        counterRequired: 2,
      ),
      cardNameBuilder: (code) => 'Card #$code',
      onSubmit: (_) {},
    );

class CounterAllocatorDialog extends StatefulWidget {
  final SelectState select;
  final String Function(int code) cardNameBuilder;
  final void Function(int code)? onInspectCard;

  /// 确认时回传每张卡的分配数量（下标与 [SelectState.options] 对齐）。
  final void Function(List<int> counts) onSubmit;

  /// 取消回调；为 null 时不显示取消按钮（计数器窗口通常不可取消）。
  final VoidCallback? onCancel;

  const CounterAllocatorDialog({
    super.key,
    required this.select,
    required this.cardNameBuilder,
    required this.onSubmit,
    this.onInspectCard,
    this.onCancel,
  });

  @override
  State<CounterAllocatorDialog> createState() => _CounterAllocatorDialogState();
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

  int _maxCountFor(int index) {
    final option = widget.select.options[index];
    return math.max(0, option.level ?? 0);
  }

  int get _allocatedTotal => _counts.fold(0, (sum, value) => sum + value);

  void _changeCount(int index, int delta) {
    final maxCount = _maxCountFor(index);
    setState(() {
      _counts[index] = (_counts[index] + delta).clamp(0, maxCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    final options = select.options;
    final required = select.counterRequired;
    final total = _allocatedTotal;
    final canConfirm = total == required;

    return LayoutBuilder(
      builder: (context, constraints) {
        const rowHeight = 84.0;
        final listHeight = math.min(
          rowHeight * options.length,
          math.max(160.0, constraints.maxHeight * 0.5),
        );
        final panelWidth = math.min(560.0, constraints.maxWidth);
        return Container(
          width: panelWidth,
          constraints: BoxConstraints(maxWidth: panelWidth),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '移除指示物',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '为每张卡分配要移除的指示物数量',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) =>
                      _buildOptionRow(index, options[index]),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '已分配 $total / 需 $required',
                    style: TextStyle(
                      color: canConfirm
                          ? const Color(0xFF00F0FF)
                          : const Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canConfirm
                        ? () => widget.onSubmit(List<int>.of(_counts))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canConfirm
                          ? const Color(0xFF00F0FF)
                          : Colors.grey.shade800,
                      foregroundColor: canConfirm
                          ? Colors.black
                          : Colors.grey.shade500,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    child: const Text('确认'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionRow(int index, SelectOption option) {
    final count = _counts[index];
    final maxCount = _maxCountFor(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onInspectCard == null
                ? null
                : () => widget.onInspectCard!(option.code),
            child: CardImage(
              code: option.code,
              width: 48,
              height: 68,
              showCodeFallback: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cardNameBuilder(option.code),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '可用指示物：$maxCount',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count > 0 ? () => _changeCount(index, -1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: const Color(0xFFFF6193),
            disabledColor: Colors.grey.shade700,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed:
                count < maxCount ? () => _changeCount(index, 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: const Color(0xFF00F0FF),
            disabledColor: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}
