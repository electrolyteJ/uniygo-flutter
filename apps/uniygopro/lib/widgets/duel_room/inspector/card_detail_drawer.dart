import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ygo_data/card_info.dart';
import '../../shared/card_image.dart';

class CardDetailDrawer extends StatelessWidget {
  final CardInfo? cardInfo;
  final int? cardCode;
  final VoidCallback? onClose;

  const CardDetailDrawer({
    super.key,
    this.cardInfo,
    this.cardCode,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const goldGlow = Color(0xFFFFD700);
    const panelDark = Color(0xF1080C14);
    // 高度随窗口自适应，避免矮窗口溢出压到手牌栏
    final maxHeight = math.min(
      620.0,
      math.max(320.0, MediaQuery.of(context).size.height - 160),
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 324,
          constraints: BoxConstraints(
            minHeight: math.min(540.0, maxHeight),
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            color: panelDark,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x6600F0FF), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: cyanGlow.withValues(alpha: 0.12),
                blurRadius: 36,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 48,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x2200F0FF))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CARD DATA',
                      style: TextStyle(
                        color: cyanGlow,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 0.9,
                      ),
                    ),
                    const Text(
                      'LARGE',
                      style: TextStyle(
                        color: cyanGlow,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    if (onClose != null)
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(
                          Icons.close,
                          color: cyanGlow,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 206,
                          height: 294,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1624),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cyanGlow, width: 1.8),
                            boxShadow: [
                              BoxShadow(
                                color: cyanGlow.withValues(alpha: 0.26),
                                blurRadius: 26,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CardImage(
                            code: cardInfo?.code ?? cardCode ?? 0,
                            width: 206,
                            height: 294,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        cardInfo?.name ??
                            (cardCode != null ? 'Card #$cardCode' : 'Unknown'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Rajdhani',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (cardInfo != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildBadge(cardInfo!.kindLabel, goldGlow),
                            if (cardInfo!.isMonster) ...[
                              _buildBadge('${cardInfo!.level}星', goldGlow),
                              _buildBadge(cardInfo!.attributeText, goldGlow),
                              _buildBadge(cardInfo!.raceText, goldGlow),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (cardInfo!.isMonster)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatText(
                                  'ATK',
                                  '${cardInfo!.attack < 0 ? '?' : cardInfo!.attack}',
                                  const Color(0xFFFF5A94),
                                ),
                                if (!cardInfo!.isLink)
                                  _buildStatText(
                                    'DEF',
                                    '${cardInfo!.defense < 0 ? '?' : cardInfo!.defense}',
                                    cyanGlow,
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          constraints: const BoxConstraints(maxHeight: 190),
                          child: SingleChildScrollView(
                            child: Text(
                              cardInfo!.desc,
                              style: const TextStyle(
                                color: Color(0xFF8B9BB4),
                                fontSize: 12,
                                height: 1.5,
                                fontFamily: 'Noto Sans SC',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatText(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Colors.white,
        ),
        children: [
          TextSpan(text: '$label / '),
          TextSpan(
            text: value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
