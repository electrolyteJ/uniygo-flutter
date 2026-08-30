import 'package:flutter/material.dart';

import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duelink/duelink.dart'
    show
        CARD_ZONE_DECK,
        CARD_ZONE_EXTRA,
        CARD_ZONE_GRAVE,
        CARD_ZONE_HAND,
        CARD_ZONE_MZONE,
        CARD_ZONE_REMOVED,
        CARD_ZONE_SZONE;

/// 选卡弹窗（MSG_SELECT_CARD / TRIBUTE / UNSELECT 等卡选窗口）。
///
/// 横滚卡片列表多选：点卡切换勾选（带来源徽标/选中描边），满足 min~max
/// 后「确认」回传下标列表 [onSelect]；[SelectState.immediateSingleToggle]
/// 模式（解除选择类窗口）点卡即回传单卡、「完成」回传空列表结束。
///
/// 与 [PositionSelector] 不合并的原因：本组件是有状态的多选确认流，
/// PositionSelector 是无状态的单选即回传，选择语义、回调签名
/// （`List<int>` vs `int position`）、卡片呈现（徽标/描边 vs 旋转/卡背
/// 预览）均不同构；可共用的仅面板外壳样式，强行合并只会得到两套
/// 互斥参数的 union API。
class CardSelector extends StatefulWidget {
  final SelectState select;
  final void Function(List<int> indices) onSelect;
  final VoidCallback onCancel;
  final void Function(int code) onInspectCard;

  /// 自定义确认门槛（SUM 窗口按引擎 sum_check 判定合计合法性）；
  /// null 时回退到「勾选数 >= [SelectState.min]」。
  final bool Function(Set<int> selectedIndices)? selectionValidator;

  const CardSelector({
    super.key,
    required this.select,
    required this.onSelect,
    required this.onCancel,
    required this.onInspectCard,
    this.selectionValidator,
  });

  @override
  State<CardSelector> createState() => _CardSelectorState();
}

class _CardSelectorState extends State<CardSelector> {
  final List<int> _selectedIndices = [];

  /// 确认按钮门槛：有自定义校验（SUM 合计）走校验，否则按张数下限。
  bool get _canConfirm {
    final validator = widget.selectionValidator;
    if (validator != null) return validator(_selectedIndices.toSet());
    return _selectedIndices.length >= widget.select.min;
  }

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
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
                _title(select),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              // 网格布局（参考 CardGridSelectDialog）：多行自适应排列，
              // 替代旧的单行横滚——卡多时一目了然。
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 104,
                    childAspectRatio: 100 / 150,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: select.options.length,
                  itemBuilder: (context, index) =>
                      _buildCardItem(index, select),
                ),
              ),
              const SizedBox(height: 12),
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
            // 卡片来源徽标（墓地/卡组/场上…）：选卡弹窗里多张同名/陌生卡
            // 并列时，玩家无法分辨每张卡来自哪里（如「活死人的呼声」选墓地、
            // 「增援」选卡组）。option 的 zone/controller 即线格式位置。
            if (select.type != SelectType.option)
              Positioned(
                top: 2,
                left: 2,
                child: _buildSourceBadge(option, select),
              ),
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

  String _title(SelectState select) {
    if (select.immediateSingleToggle) {
      return '已选择 ${_selectedIndices.length} 张卡，继续点卡切换，满足条件后完成';
    }
    // SUM 窗口按合计数值选卡而非张数：max==0（精确合计）时没有张数上限，
    // 展示「min-max 张」会误导。
    if (select.type == SelectType.sum) {
      return select.sumExact
          ? '选择合计恰为 ${select.sumTarget} 的卡（已选 ${_selectedIndices.length} 张）'
          : '选择合计达到 ${select.sumTarget} 的卡（已选 ${_selectedIndices.length} 张）';
    }
    return '选择 ${select.min}-${select.max} 张卡 (${_selectedIndices.length}/${select.max})';
  }

  void _toggleSelection(int index, SelectState select) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        // max<=0（SUM 精确合计窗口）表示无张数上限，不能按 0 上限拦截，
        // 否则一张都选不了、窗口又不可取消，对局卡死。
      } else if (select.max <= 0 || _selectedIndices.length < select.max) {
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

  /// 卡片来源徽标：区域名（墓地/卡组/…），卡属于对方时加「对方」前缀。
  Widget _buildSourceBadge(SelectOption option, SelectState select) {
    final label = _sourceLabel(option, select);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x5500F0FF), width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9AEFFF),
          fontSize: 8,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// zone（CARD_ZONE_* 位掩码）+ controller → 中文来源标签。
  /// 位置未知（zone==0，如部分 option/chain 回退形状）时返回 null 不显示。
  static String? _sourceLabel(SelectOption option, SelectState select) {
    final zone = switch (option.zone) {
      CARD_ZONE_DECK => '卡组',
      CARD_ZONE_HAND => '手牌',
      CARD_ZONE_MZONE => '怪兽区',
      CARD_ZONE_SZONE => '魔陷区',
      CARD_ZONE_GRAVE => '墓地',
      CARD_ZONE_REMOVED => '除外',
      CARD_ZONE_EXTRA => '额外',
      _ => null,
    };
    if (zone == null) return null;
    // controller 与选择者不同 = 对方的卡（select.player 是选择发起方）。
    return option.controller != select.player ? '对方$zone' : zone;
  }
}
