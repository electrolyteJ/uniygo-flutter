import 'package:flutter/material.dart';

enum CardPosition {
  faceUpAttack,
  faceDownAttack,
  faceUpDefense,
  faceDownDefense,
}

enum CardType { monster, spell, trap }

class DuelCard {
  final int code;
  final String name;
  final CardType type;
  final int attribute;
  final int level;
  final int attack;
  final int defense;
  final String imageUrl;
  CardPosition position;
  bool isTapped;

  DuelCard({
    required this.code,
    required this.name,
    this.type = CardType.monster,
    this.attribute = 0x01,
    this.level = 4,
    this.attack = 0,
    this.defense = 0,
    this.imageUrl = '',
    this.position = CardPosition.faceUpAttack,
    this.isTapped = false,
  });

  DuelCard.preview()
      : code = 0,
        name = '',
        type = CardType.monster,
        attribute = 0x01,
        level = 4,
        attack = 0,
        defense = 0,
        imageUrl = '',
        position = CardPosition.faceUpAttack,
        isTapped = false;

  bool get isFaceUp =>
      position == CardPosition.faceUpAttack ||
      position == CardPosition.faceUpDefense;

  bool get isAttack =>
      position == CardPosition.faceUpAttack ||
      position == CardPosition.faceDownAttack;

  Color get attributeColor {
    switch (attribute) {
      case 0x01:
        return Colors.brown;
      case 0x02:
        return Colors.blue;
      case 0x04:
        return Colors.red;
      case 0x08:
        return Colors.green;
      case 0x10:
        return Colors.yellow;
      case 0x20:
        return Colors.grey;
      case 0x40:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  Color get typeColor {
    switch (type) {
      case CardType.monster:
        return Colors.orange;
      case CardType.spell:
        return Colors.teal;
      case CardType.trap:
        return Colors.purple;
    }
  }
}
