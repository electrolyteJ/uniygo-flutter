import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

/// 表示形式选择弹窗（MSG_SELECT_POSITION）。
///
/// 无状态单选：把引擎下发的可选表示形式渲染为卡片预览横排
///（守备旋转 90°、里侧显示卡背），点选即经 [onSelect] 回传位置位
///（POS_* 位掩码，如表侧攻击 0x1 / 表侧守备 0x4 / 里侧守备 0x8）。
///
/// 与 [CardSelector] 不合并的原因见 CardSelector 的类注释。
class PositionSelector extends StatelessWidget {
  final SelectState? select;
  final void Function(int position) onSelect;
  const PositionSelector({super.key, this.select, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = select?.options ?? const <SelectOption>[];
    return ResponsivePanel(
      maxWidth: 520,
      maxHeight: 250,
      header: const Text(
        '选择表示形式',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final option in options)
                  _buildPositionItem(option, constraints.maxHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionItem(SelectOption option, double availableHeight) {
    final position = option.position ?? 0;
    final itemHeight = math.max(44.0, math.min(184.0, availableHeight));
    return InkWell(
      onTap: () => onSelect(position),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        height: itemHeight,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: 100,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.55),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300F0FF),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: _buildPreviewCard(option.code, position),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (itemHeight >= 88) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: Text(
                  option.label ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isFacedown(int position) => (position & 0x0A) != 0;

  bool _isDefense(int position) => (position & 0x0C) != 0;

  Widget _buildPreviewCard(int code, int position) {
    const cardWidth = 92.0;
    const cardHeight = 132.0;
    final isFacedown = _isFacedown(position);
    final isDefense = _isDefense(position);
    final card = isFacedown
        ? Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF31475E), Color(0xFF0A1020)],
              ),
            ),
          )
        : const SizedBox.shrink();
    final child = isFacedown
        ? card
        : CardImage(
            code: code,
            width: cardWidth,
            height: cardHeight,
            showCodeFallback: false,
          );
    if (!isDefense) return child;
    return Transform.rotate(
      angle: math.pi / 2,
      child: SizedBox(
        width: cardHeight * 0.74,
        height: cardWidth * 0.74,
        child: FittedBox(fit: BoxFit.contain, child: child),
      ),
    );
  }
}

@Preview(name: 'PositionSelector', size: Size(420, 240))
Widget positionSelectorPreview() => PositionSelector(
  select: const SelectState(
    type: SelectType.position,
    player: 0,
    options: [
      SelectOption(code: 46986414, position: 0x1, label: '表侧攻击'),
      SelectOption(code: 46986414, position: 0x4, label: '表侧守备'),
      SelectOption(code: 46986414, position: 0x8, label: '里侧守备'),
    ],
  ),
  onSelect: _noop,
);

void _noop(int position) {}
