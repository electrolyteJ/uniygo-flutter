import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../models/duel_card.dart';
import '../preview_helpers.dart';

class CardFace extends StatefulWidget {
  final DuelCard card;
  final double width;
  final double height;
  final bool selected;
  final bool faceDown;
  final VoidCallback? onTap;

  const CardFace({
    super.key,
    required this.card,
    this.width = 64,
    this.height = 90,
    this.selected = false,
    this.faceDown = false,
    this.onTap,
  });

  @override
  State<CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends State<CardFace> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _buildTransform(),
          transformAlignment: Alignment.bottomCenter,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.selected
                    ? Colors.yellowAccent
                    : _hovered
                        ? Colors.white70
                        : widget.card.typeColor.withValues(alpha: 0.6),
                width: widget.selected ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (widget.selected)
                  BoxShadow(
                    color: Colors.yellowAccent.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.6 : 0.3),
                  blurRadius: _hovered ? 12 : 6,
                  offset: Offset(0, _hovered ? 6 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: widget.faceDown ? _buildCardBack() : _buildCardFront(),
            ),
          ),
        ),
      ),
    );
  }

  Matrix4 _buildTransform() {
    final m = Matrix4.identity();
    if (_hovered && !widget.faceDown) {
      m.setEntry(3, 2, 0.002);
      m.rotateX(-0.08);
      m.scaleByDouble(1.08, 1.08, 1.08, 1.0);
    }
    if (widget.selected) {
      m.translateByDouble(0.0, -6.0, 0.0, 0.0);
    }
    return m;
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.brown.shade800,
            Colors.brown.shade900,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: widget.width * 0.55,
          height: widget.height * 0.55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.shade300, width: 1.5),
            gradient: RadialGradient(
              colors: [
                Colors.orange.shade200.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: widget.width * 0.3,
            color: Colors.orange.shade200,
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.card.typeColor.withValues(alpha: 0.25),
            Colors.grey.shade900,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            color: Colors.black.withValues(alpha: 0.5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.card.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.width * 0.11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.card.type == CardType.monster)
                  Text(
                    '★${widget.card.level}',
                    style: TextStyle(
                      color: Colors.yellow.shade300,
                      fontSize: widget.width * 0.1,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Icon(
                  widget.card.type == CardType.monster
                      ? Icons.catching_pokemon
                      : widget.card.type == CardType.spell
                          ? Icons.auto_fix_high
                          : Icons.shield,
                  size: widget.width * 0.35,
                  color: widget.card.attributeColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          if (widget.card.type == CardType.monster)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              color: Colors.black.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _AtkDefText(
                      label: 'ATK',
                      value: widget.card.attack,
                      color: Colors.red,
                      width: widget.width,
                    ),
                  ),
                  Expanded(
                    child: _AtkDefText(
                      label: 'DEF',
                      value: widget.card.defense,
                      color: Colors.blue,
                      width: widget.width,
                      alignRight: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AtkDefText extends StatelessWidget {
  final String label;
  final int value;
  final MaterialColor color;
  final double width;
  final bool alignRight;

  const _AtkDefText({
    required this.label,
    required this.value,
    required this.color,
    required this.width,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        '$label/$value',
        style: TextStyle(
          color: color.shade300,
          fontSize: width * 0.09,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

@Preview(name: '怪兽卡', group: 'CardFace', wrapper: darkPreviewWrapper)
Widget previewMonsterCard() => CardFace(
      card: DuelCard(
          code: 89631139,
          name: '青眼白龙',
          attack: 3000,
          defense: 2500,
          level: 8,
          attribute: 0x10),
      width: 120,
      height: 170,
    );

@Preview(name: '魔法卡', group: 'CardFace', wrapper: darkPreviewWrapper)
Widget previewSpellCard() => CardFace(
      card: DuelCard(code: 53129443, name: '黑洞', type: CardType.spell),
      width: 120,
      height: 170,
    );

@Preview(name: '陷阱卡', group: 'CardFace', wrapper: darkPreviewWrapper)
Widget previewTrapCard() => CardFace(
      card: DuelCard(code: 1, name: '神圣防护罩', type: CardType.trap),
      width: 120,
      height: 170,
    );

@Preview(name: '背面', group: 'CardFace', wrapper: darkPreviewWrapper)
Widget previewCardBack() => CardFace(
      card: DuelCard.preview(),
      width: 120,
      height: 170,
      faceDown: true,
    );

@Preview(name: '选中状态', group: 'CardFace', wrapper: darkPreviewWrapper)
Widget previewSelectedCard() => CardFace(
      card: DuelCard(
          code: 46986414,
          name: '黑魔术师',
          attack: 2500,
          defense: 2100,
          level: 7,
          attribute: 0x20),
      width: 120,
      height: 170,
      selected: true,
    );
