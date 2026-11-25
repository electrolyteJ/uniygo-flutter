/// 舞台背景的漂浮卡牌剪影（纯装饰，不参与命中）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 四张倾斜卡牌，坐标以 844×390 设计稿为准。
List<Widget> floatingCards() {
  const cards = [
    (230.0, 92.0, -14.0),
    (580.0, 124.0, 12.0),
    (592.0, 240.0, -9.0),
    (234.0, 252.0, 16.0),
  ];
  return [
    for (final card in cards)
      Positioned(
        left: card.$1,
        top: card.$2,
        child: Transform.rotate(
          angle: card.$3 * math.pi / 180,
          child: Container(
            width: 38,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0x8C0B1826),
              border: Border.all(color: const Color(0xFF1A324A)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
  ];
}
