import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/card_image.dart';

class ZoneBrowserModal extends StatelessWidget {
  final String title;
  final List<int> cardCodes;
  final int? selectedCardCode;
  final ValueChanged<int> onCardTap;
  final VoidCallback onClose;
  final String Function(int code)? cardNameBuilder;

  const ZoneBrowserModal({
    super.key,
    required this.title,
    required this.cardCodes,
    required this.selectedCardCode,
    required this.onCardTap,
    required this.onClose,
    this.cardNameBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withOpacity(0.76),
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
                        color: const Color(0xFF00F0FF).withOpacity(0.26),
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
                              title,
                              style: const TextStyle(
                                color: Color(0xFF00F0FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                          Text(
                            '${cardCodes.length} 张',
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
                        child: cardCodes.isEmpty
                            ? const Center(
                                child: Text(
                                  '该区域当前没有卡片',
                                  style: TextStyle(
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
                                itemCount: cardCodes.length,
                                itemBuilder: (context, index) {
                                  final code = cardCodes[index];
                                  final isSelected = selectedCardCode == code;
                                  return _ZoneBrowserCardTile(
                                    code: code,
                                    name:
                                        cardNameBuilder?.call(code) ??
                                        'Card #$code',
                                    isSelected: isSelected,
                                    onTap: () => onCardTap(code),
                                  );
                                },
                              ),
                      ),
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
          color: Colors.white.withOpacity(isSelected ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00F0FF)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withOpacity(0.32),
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
