import 'package:flutter/material.dart';
import '../models/duel_card.dart';
import '../theme/duel_theme.dart';

class CardFace extends StatelessWidget {
  final DuelCard card;
  final double width;
  final bool faceDown;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;

  const CardFace({
    super.key,
    required this.card,
    this.width = 64,
    this.faceDown = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onHover,
  });

  double get height => width * DuelTheme.cardRatio;

  List<Color> get _frame => switch (card.type) {
        CardType.monster => const [Color(0xFFCAA64E), Color(0xFF8A6A2A), Color(0xFFA8843A)],
        CardType.spell => const [Color(0xFF4ECB92), Color(0xFF1D6C47), Color(0xFF2F9468)],
        CardType.trap => const [Color(0xFFD06AC0), Color(0xFF7A2468), Color(0xFFA84A96)],
      };

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: MouseRegion(
        onEnter: (_) => onHover?.call(true),
        onExit: (_) => onHover?.call(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.05),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _frame,
            ),
            border: Border.all(color: const Color(0xFF5E4818), width: 1),
            boxShadow: [
              if (selected)
                BoxShadow(color: DuelTheme.goldHi.withValues(alpha: .8), blurRadius: 18, spreadRadius: 2),
              BoxShadow(color: Colors.black.withValues(alpha: .55), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.04),
            child: faceDown ? _back() : _front(),
          ),
        ),
      ),
    );
    return child;
  }

  Widget _back() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF3A2154), Color(0xFF241238), Color(0xFF180C28)],
          stops: [0.3, 0.62, 1],
        ),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF6A4A8A), width: 2)),
      ),
      child: Center(
        child: Container(
          width: width * 0.62,
          height: width * 0.62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: DuelTheme.gold.withValues(alpha: .5)),
          ),
          child: Center(
            child: Text(
              '☥',
              style: TextStyle(
                fontSize: width * 0.34,
                color: DuelTheme.gold.withValues(alpha: .9),
                shadows: [Shadow(color: DuelTheme.gold.withValues(alpha: .8), blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _front() {
    final nameBg = switch (card.type) {
      CardType.monster => const Color(0xD9FFF0C8),
      CardType.spell => const Color(0xD9DCFFF0),
      CardType.trap => const Color(0xD9FFE1FA),
    };
    final nameColor = switch (card.type) {
      CardType.monster => const Color(0xFF1C1206),
      CardType.spell => const Color(0xFF06231A),
      CardType.trap => const Color(0xFF2A0622),
    };
    return Padding(
      padding: EdgeInsets.all(width * 0.035),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: width * 0.02),
            decoration: BoxDecoration(
              color: nameBg,
              borderRadius: BorderRadius.circular(width * 0.025),
            ),
            child: Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: width * 0.088,
                fontWeight: FontWeight.w700,
                color: nameColor,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(height: width * 0.03),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(width * 0.03),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final g in CardDb.artGradients(card.art))
                    Container(decoration: BoxDecoration(gradient: g)),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: width * 0.08, spreadRadius: -width * 0.02),
                      ],
                    ),
                  ),
                  Center(
                    child: Text(
                      card.glyph,
                      style: TextStyle(
                        fontSize: width * 0.34,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.white.withValues(alpha: .7), blurRadius: width * 0.1),
                          Shadow(color: Colors.black.withValues(alpha: .6), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (card.isMonster) ...[
            SizedBox(height: width * 0.02),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '✦' * card.level,
                style: TextStyle(
                  fontSize: width * 0.062,
                  color: DuelTheme.goldHi,
                  letterSpacing: width * 0.012,
                  shadows: [Shadow(color: DuelTheme.goldHi.withValues(alpha: .7), blurRadius: 3)],
                ),
              ),
            ),
            SizedBox(height: width * 0.02),
            Container(
              padding: EdgeInsets.symmetric(horizontal: width * 0.045, vertical: width * 0.025),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(width * 0.025),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('ATK ${card.atk}',
                          style: TextStyle(fontSize: width * 0.07, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('DEF ${card.def}',
                          style: TextStyle(fontSize: width * 0.07, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: width * 0.03),
            Text(
              card.type == CardType.spell ? '魔 法 SPELL' : '陷 阱 TRAP',
              style: TextStyle(
                fontSize: width * 0.062,
                letterSpacing: width * 0.03,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: .92),
              ),
            ),
            SizedBox(height: width * 0.02),
          ],
        ],
      ),
    );
  }
}
