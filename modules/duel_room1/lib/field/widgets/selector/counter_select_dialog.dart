import 'package:flutter/material.dart';

import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';

/// 指示物移除选择弹窗（MSG_SELECT_COUNTER）。
///
/// 不与 CardSelector 共用的原因：引擎（playerop.cpp select_counter）要求的
/// 应答是「每卡一个移除计数」——窗口顺序的完整 int16 列表、各值 ≤ 该卡
/// 可用指示物数（[SelectOption.level]）、总和恰好等于
/// [SelectState.counterRequired]，而不是「选哪几张卡」的下标列表。
/// 每张卡一行：卡图 + 步进器（0..该卡指示物数），实时显示合计，
/// 合计达标才允许确认。引擎的 counter 窗口不可取消，故无取消按钮。
class CounterSelectDialog extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> counts) onSelect;
  final void Function(int code) onInspectCard;

  const CounterSelectDialog({
    super.key,
    required this.select,
    required this.onSelect,
    required this.onInspectCard,
  });

  @override
  State<CounterSelectDialog> createState() => _CounterSelectDialogState();
}

class _CounterSelectDialogState extends State<CounterSelectDialog> {
  late final List<int> _counts = List.filled(widget.select.options.length, 0);

  int get _sum => _counts.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    final required = select.counterRequired;
    final satisfied = _sum == required;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF09111A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x5500F0FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择要移除的指示物（合计 $_sum/$required）',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: select.options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _buildRow(index, select),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: satisfied
                    ? () => widget.onSelect(List<int>.of(_counts))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: satisfied
                      ? const Color(0xFF00F0FF)
                      : Colors.grey.shade800,
                  foregroundColor: satisfied
                      ? Colors.black
                      : Colors.grey.shade500,
                  disabledBackgroundColor: Colors.grey.shade800,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('确认'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int index, SelectState select) {
    final option = select.options[index];
    final max = option.level ?? 0;
    final count = _counts[index];
    return Row(
      children: [
        GestureDetector(
          onTap: () => widget.onInspectCard(option.code),
          child: CardImage(code: option.code, width: 44, height: 64),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '可用指示物 $max 个',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          color: Colors.white70,
          disabledColor: Colors.white24,
          onPressed: count > 0
              ? () => setState(() => _counts[index] = count - 1)
              : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          color: Colors.white70,
          disabledColor: Colors.white24,
          // 单卡上限 = 该卡可用指示物数；全局合计不得超过需移除总数
          // （超过的回包会被本地校验与服务端双双拒绝）。
          onPressed: count < max && _sum < select.counterRequired
              ? () => setState(() => _counts[index] = count + 1)
              : null,
        ),
      ],
    );
  }
}
