import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../widgets/card_image.dart';
import '../../../../widgets/cyber_button.dart';
import '../../models/duel_menu.dart';


String _zoneTitle(String zoneKey) {
  switch (zoneKey) {
    case 'self_grave':
      return '己方墓地';
    case 'opp_grave':
      return '对手墓地';
    case 'self_removed':
      return '己方除外';
    case 'opp_removed':
      return '对手除外';
    case 'self_extra':
      return '己方额外';
    case 'opp_extra':
      return '对手额外';
    default:
      return '区域详情';
  }
}

class ZoneBrowserModal extends StatelessWidget {
  final String zoneBrowserKey;
  final List<ZoneBrowserCardEntry> cards;
  final int? selectedCardSequence;
  final void Function(int sequence, int code) onCardTap;
  final VoidCallback onClose;
  final String Function(int code)? cardNameBuilder;
  final List<ActionMenuEntry> selectedActions;

  /// 该区域服务端记录的卡片总数。
  /// 当列表为空但总数大于 0 时（例如对手额外卡组为里侧），
  /// 空态会提示“里侧不可见”而不是“没有卡片”。
  final int hiddenCount;

  const ZoneBrowserModal({
    super.key,
    required this.zoneBrowserKey,
    required this.cards,
    required this.selectedCardSequence,
    required this.onCardTap,
    required this.onClose,
    this.cardNameBuilder,
    this.selectedActions = const [],
    this.hiddenCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 左侧留出 inspector 区域（18 边距 + 324 面板 + 18 间隔），
    // 保证浏览区域时点击卡片能实时看到 inspector 更新。
    return Positioned.fill(
      left: 360,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.76),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 720,
                  constraints: const BoxConstraints(
                    maxWidth: 720,
                    maxHeight: 560,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xF2080C14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00F0FF),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.26),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _zoneTitle(zoneBrowserKey),
                              style: const TextStyle(
                                color: Color(0xFF00F0FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                          Text(
                            '${cards.length} 张',
                            style: const TextStyle(
                              color: Color(0xFF8B9BB4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onClose,
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFF00F0FF),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: cards.isEmpty
                            ? Center(
                                child: Text(
                                  hiddenCount > 0
                                      ? '该区域有 $hiddenCount 张里侧卡片，无法查看'
                                      : '该区域当前没有卡片',
                                  style: const TextStyle(
                                    color: Color(0xFF8B9BB4),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Noto Sans SC',
                                  ),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.72,
                                    ),
                                itemCount: cards.length,
                                itemBuilder: (context, index) {
                                  final entry = cards[index];
                                  final code = entry.code;
                                  final isSelected =
                                      selectedCardSequence == entry.sequence;
                                  return _ZoneBrowserCardTile(
                                    code: code,
                                    name:
                                        cardNameBuilder?.call(code) ??
                                        'Card #$code',
                                    isSelected: isSelected,
                                    onTap: () =>
                                        onCardTap(entry.sequence, code),
                                  );
                                },
                              ),
                      ),
                      if (selectedActions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '可直接执行的动作',
                                style: TextStyle(
                                  color: Color(0xFF00F0FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Orbitron',
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (
                                var index = 0;
                                index < selectedActions.length;
                                index++
                              ) ...[
                                CyberButton(
                                  label: selectedActions[index].label,
                                  width: double.infinity,
                                  onTap: selectedActions[index].onTap,
                                ),
                                if (index != selectedActions.length - 1)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneBrowserCardTile extends StatelessWidget {
  final int code;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoneBrowserCardTile({
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSelected ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00F0FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.32),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CardImage(code: code, width: 120, height: 170),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFD7E3F2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Sans SC',
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

