import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../models/SelectState.dart';
import '../../../image/card_image.dart';

class PositionSelector extends StatelessWidget {
  final SelectState? select;
  final void Function(int position) onSelect;
  const PositionSelector({super.key, this.select, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = select?.options ?? const [];
    final code = options.isNotEmpty ? options.first.code : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 108.0;
        const horizontalPadding = 32.0;
        const minCardCount = 3;
        final count = options.isEmpty ? 3 : options.length;
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
              const Text('选择表示形式', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              SizedBox(
                height: 174,
                child: wrapsContent
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final option in options)
                            _buildPositionItem(option, code),
                        ],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final option in options)
                              _buildPositionItem(option, code),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionItem(SelectOption option, int code) {
    final position = option.position ?? 0;
    return GestureDetector(
      onTap: () => onSelect(position),
      child: Container(
        width: 100,
        height: 168,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 144,
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
                    child: Center(child: _buildPreviewCard(code, position)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
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
