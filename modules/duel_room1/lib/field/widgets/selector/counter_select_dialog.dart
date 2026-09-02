import 'package:flutter/material.dart';

import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

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
  late List<int> _counts = List.filled(widget.select.options.length, 0);

  int get _sum => _counts.fold(0, (a, b) => a + b);

  @override
  void didUpdateWidget(covariant CounterSelectDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.select, widget.select)) {
      _counts = List.filled(widget.select.options.length, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final select = widget.select;
    final required = select.counterRequired;
    final satisfied = _sum == required;
    return ResponsivePanel(
      maxWidth: 520,
      maxHeight: 560,
      header: Text(
        '选择要移除的指示物（合计 $_sum/$required）',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: ListView.separated(
        itemCount: select.options.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildRow(index, select),
      ),
      actions: Center(
        child: ElevatedButton(
          onPressed: satisfied
              ? () => widget.onSelect(List<int>.of(_counts))
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: satisfied
                ? const Color(0xFF00F0FF)
                : Colors.grey.shade800,
            foregroundColor: satisfied ? Colors.black : Colors.grey.shade500,
            disabledBackgroundColor: Colors.grey.shade800,
            disabledForegroundColor: Colors.grey.shade500,
            minimumSize: const Size(44, 44),
          ),
          child: const Text('确认'),
        ),
      ),
    );
  }

  Widget _buildRow(int index, SelectState select) {
    final option = select.options[index];
    final max = option.level ?? 0;
    final count = _counts[index];
    final compact = DuelRoomLayout.of(context).isCompact;
    return Row(
      children: [
        Semantics(
          key: ValueKey('counter-inspect-$index'),
          button: true,
          label: '查看卡片',
          excludeSemantics: true,
          onTap: () => widget.onInspectCard(option.code),
          child: InkWell(
            onTap: () => widget.onInspectCard(option.code),
            child: SizedBox(
              width: 44,
              height: compact ? 52 : 64,
              child: Center(
                child: CardImage(
                  code: option.code,
                  width: compact ? 36 : 44,
                  height: compact ? 52 : 64,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '可用指示物 $max 个',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Semantics(
          key: ValueKey('counter-decrease-$index'),
          button: true,
          enabled: count > 0,
          label: '减少该卡指示物',
          excludeSemantics: true,
          onTap: count > 0
              ? () => setState(() => _counts[index] = count - 1)
              : null,
          child: IconButton(
            tooltip: '减少该卡指示物',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: Colors.white70,
            disabledColor: Colors.white24,
            onPressed: count > 0
                ? () => setState(() => _counts[index] = count - 1)
                : null,
          ),
        ),
        SizedBox(
          key: ValueKey('counter-count-$index'),
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
        Semantics(
          key: ValueKey('counter-increase-$index'),
          button: true,
          enabled: count < max && _sum < select.counterRequired,
          label: '增加该卡指示物',
          excludeSemantics: true,
          onTap: count < max && _sum < select.counterRequired
              ? () => setState(() => _counts[index] = count + 1)
              : null,
          child: IconButton(
            tooltip: '增加该卡指示物',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: Colors.white70,
            disabledColor: Colors.white24,
            // 单卡上限 = 该卡可用指示物数；全局合计不得超过需移除总数
            // （超过的回包会被本地校验与服务端双双拒绝）。
            onPressed: count < max && _sum < select.counterRequired
                ? () => setState(() => _counts[index] = count + 1)
                : null,
          ),
        ),
      ],
    );
  }
}
