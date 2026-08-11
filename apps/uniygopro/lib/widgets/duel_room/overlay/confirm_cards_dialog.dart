import 'package:flutter/material.dart';

import '../../card_image.dart';

/// 居中展示服务端要求查看的卡牌（MSG_CONFIRM_CARDS 多张非场上卡）。
///
/// 参考经典 ygopro C++ 客户端 behavior：卡组/额外卡组中的多张卡
/// 通过弹窗展示，玩家点击任意处关闭（`actionSignal.Wait`）。
class ConfirmCardsDialog extends StatelessWidget {
  final String title;
  final List<int> codes;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;

  const ConfirmCardsDialog({
    super.key,
    required this.title,
    required this.codes,
    required this.cardNameBuilder,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Center(
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 720,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xF2080C14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00F0FF), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.26),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.visibility,
                  color: Color(0xFF00F0FF),
                  size: 20,
                ),
                const SizedBox(width: 10),
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
                  '${codes.length} 张',
                  style: const TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Orbitron',
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF8B9BB4),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: codes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        '没有可查看的卡片',
                        style: TextStyle(
                          color: Color(0xFF8B9BB4),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Noto Sans SC',
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: codes.length,
                      itemBuilder: (context, index) {
                        final code = codes[index];
                        return _ConfirmCardTile(
                          code: code,
                          name: cardNameBuilder(code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _ConfirmCardTile extends StatelessWidget {
  final int code;
  final String name;

  const _ConfirmCardTile({required this.code, required this.name});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = constraints.maxWidth.clamp(0.0, 150.0);
        final maxCardHeight = (constraints.maxHeight - 36).clamp(0.0, 215.0);
        final cardScale = [
          maxCardWidth / 150,
          maxCardHeight / 215,
          1.0,
        ].reduce((value, element) => value < element ? value : element);
        final cardWidth = 150 * cardScale;
        final cardHeight = 215 * cardScale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CardImage(
                    code: code,
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD7E3F2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Sans SC',
                height: 1.25,
              ),
            ),
          ],
        );
      },
    );
  }
}
