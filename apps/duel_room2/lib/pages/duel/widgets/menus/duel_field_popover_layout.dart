import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../models/field_card.dart';


String fieldSlotId(FieldCard fieldCard) {
  return '${fieldCard.controller}_${fieldCard.zone}_${fieldCard.sequence}';
}

/// 渲染器 anchors 缺失时的场地卡回退锚点（按经验比例估算）。
Offset fieldCardAnchor(Size size, FieldCard fieldCard, int myController) {
  final boardCenterX = size.width * 0.56;
  final boardWidth = math.min(size.width * 0.66, 940.0);
  final startX = boardCenterX - (boardWidth / 2);
  final stepX = boardWidth / 6;

  int displayColumn;
  if (fieldCard.zone == 4 && fieldCard.sequence >= 5) {
    displayColumn = fieldCard.sequence == 5 ? 2 : 4;
  } else if (fieldCard.zone == 8 && fieldCard.sequence == 5) {
    displayColumn = fieldCard.controller == myController ? 0 : 6;
  } else {
    final rawColumn = fieldCard.sequence + 1;
    displayColumn = fieldCard.controller == myController
        ? rawColumn
        : 6 - rawColumn;
  }

  final normalizedY = switch ((fieldCard.zone, fieldCard.sequence)) {
    (4, 5) || (4, 6) => 0.50,
    (4, _) when fieldCard.controller == myController => 0.58,
    (4, _) => 0.38,
    (8, 5) when fieldCard.controller == myController => 0.58,
    (8, 5) => 0.38,
    (8, _) when fieldCard.controller == myController => 0.73,
    (8, _) => 0.24,
    _ => 0.5,
  };

  return Offset(startX + (displayColumn * stepX), size.height * normalizedY);
}
