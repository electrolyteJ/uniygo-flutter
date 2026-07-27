import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ygo_card_deck/db/models/card_info.dart';
import '../scene/summon_scene.dart';

class SummonAnimationOverlay extends StatelessWidget {
  final CardInfo card;
  final String imageUrl;
  final VoidCallback onBack;

  const SummonAnimationOverlay({
    super.key,
    required this.card,
    required this.imageUrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Flame 游戏舞台
          GameWidget(
            game: SummonScene(
              cardImageUrl: imageUrl,
              onComplete: () {
                // 动画完成后的逻辑
              },
            ),
          ),
          
          // 返回按钮
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: onBack,
            ),
          ),
          
          // 召唤成功的卡片名称显示
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    '召唤成功！',
                    style: TextStyle(
                      color: Colors.blueAccent.withOpacity(0.8),
                      fontSize: 18,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.blueAccent, blurRadius: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
