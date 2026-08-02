import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ygo_card/card_info.dart';
import '../shared/card_image.dart';

class CardDetailDrawer extends StatelessWidget {
  final CardInfo? cardInfo;
  final int? cardCode;
  final String? titleOverride;
  final List<String>? extraLines;
  final VoidCallback? onClose;

  const CardDetailDrawer({
    super.key,
    this.cardInfo,
    this.cardCode,
    this.titleOverride,
    this.extraLines,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const panelDark = Color(0xEF080C14); // rgba(8, 12, 20, 0.94)
    const panelBorder = Color(0x5900F0FF); // rgba(0, 240, 255, 0.35)

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 250,
          decoration: const BoxDecoration(
            color: panelDark,
            border: Border(
              right: BorderSide(color: panelBorder, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                blurRadius: 30,
                offset: Offset(6, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Inspector Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x3300F0FF))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '❖ CARD INSPECTOR',
                      style: TextStyle(
                        color: cyanGlow,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1,
                      ),
                    ),
                    if (onClose != null)
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(Icons.keyboard_arrow_left, color: cyanGlow, size: 18),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Hologram Frame
                      Center(
                        child: Container(
                          width: 150,
                          height: 218,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1624),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: cyanGlow, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: cyanGlow.withOpacity(0.4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CardImage(
                            code: cardInfo?.code ?? cardCode ?? 0,
                            width: 150,
                            height: 218,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card Title
                      Text(
                        titleOverride ??
                            cardInfo?.name ??
                            (cardCode != null ? 'Card #$cardCode' : 'Unknown'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Rajdhani',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (extraLines != null && extraLines!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: extraLines!
                                  .map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        line,
                                        style: const TextStyle(
                                          color: Color(0xFF8B9BB4),
                                          fontSize: 11,
                                          height: 1.5,
                                          fontFamily: 'Noto Sans SC',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ] else if (cardInfo != null) ...[
                        // Badges
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _buildBadge(cardInfo!.kindLabel, const Color(0xFFFFD700)),
                            if (cardInfo!.isMonster) ...[
                              _buildBadge('★ ${cardInfo!.level}', const Color(0xFFFFD700)),
                              _buildBadge('${cardInfo!.attributeText} / ${cardInfo!.raceText}', const Color(0xFFFFD700)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stats Dashboard
                        if (cardInfo!.isMonster)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatText('ATK', '${cardInfo!.attack < 0 ? '?' : cardInfo!.attack}', const Color(0xFFFF0055)),
                                if (!cardInfo!.isLink)
                                  _buildStatText('DEF', '${cardInfo!.defense < 0 ? '?' : cardInfo!.defense}', cyanGlow),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Description
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: Text(
                              cardInfo!.desc,
                              style: const TextStyle(
                                color: Color(0xFF8B9BB4),
                                fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
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
          TextSpan(text: value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
