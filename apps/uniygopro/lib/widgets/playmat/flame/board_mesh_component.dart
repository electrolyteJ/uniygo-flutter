import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'duel_flame_game.dart';

class BoardMeshComponent extends PositionComponent with HasGameReference<DuelFlameGame> {
  double _time = 0;
  // 预生成极小尘埃粒子：35 个浮动点，模拟原图中的星空背景 (Normalized 0..1)
  final List<Offset> _dustParticles = List.generate(35, (_) => Offset(Random().nextDouble(), Random().nextDouble()));

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final size = game.canvasSize;
    final centerX = size.x / 2;
    final centerY = size.y / 2 + 40;

    // 1. 定义棋盘地毯尺寸 (根据图示比例：宽且扁平)
    const double matW = 580;
    const double matH = 240;

    // 统一投影算法路径
    final matPath = Path()
      ..moveTo(game.project3D(-matW, -matH).dx, game.project3D(-matW, -matH).dy)
      ..lineTo(game.project3D(matW, -matH).dx, game.project3D(matW, -matH).dy)
      ..lineTo(game.project3D(matW, matH).dx, game.project3D(matW, matH).dy)
      ..lineTo(game.project3D(-matW, matH).dx, game.project3D(-matW, matH).dy)
      ..close();

    // 1.1 底部背景：深邃蓝黑
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = const Color(0xFF02050A));

    // 1.2 棋盘内底色：中心微弱青色径向光 (100% 匹配 HTML radial-gradient 氛围)
    canvas.drawPath(matPath, Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          const Color(0xFF00F0FF).withOpacity(0.06), 
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(center: Offset(centerX, centerY), width: 1200, height: 600)));

    // 1.3 精细外边框：1.2px 的青色细线 (Matches thin border in image)
    canvas.drawPath(matPath, Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.35) 
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke);
    
    // 边框微弱外发光
    canvas.drawPath(matPath, Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.1)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // 2. 极其微弱的参考网格线
    final gridPaint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.03)
      ..strokeWidth = 0.8;

    for (double y = -matH; y <= matH; y += matH / 2) {
      canvas.drawLine(game.project3D(-matW, y), game.project3D(matW, y), gridPaint);
    }
    for (double x = -matW; x <= matW; x += matW / 3.5) {
      canvas.drawLine(game.project3D(x, -matH), game.project3D(x, -matH), gridPaint);
    }

    // 3. 核心：强力水平辉光光束 (100% 还原效果图中的 Intense Horizontal Beam)
    final double pulse = 0.8 + sin(_time * 3.5) * 0.2;
    
    // 3.1 底层广域辉光 (Wide Bloom)
    canvas.drawLine(game.project3D(-matW * 0.8, 0), game.project3D(matW * 0.8, 0), 
      Paint()
        ..color = const Color(0xFF00F0FF).withOpacity(0.15 * pulse)
        ..strokeWidth = 35.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    // 3.2 中层扩散光 (Secondary Bloom)
    canvas.drawLine(game.project3D(-matW * 0.9, 0), game.project3D(matW * 0.9, 0), 
      Paint()
        ..color = const Color(0xFF00F0FF).withOpacity(0.25 * pulse)
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // 3.3 核心极细高亮线 (带有紫色微调)
    final centerDividerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00F0FF),
          const Color(0xFFB026FF).withOpacity(0.8),
          const Color(0xFF00F0FF),
          Colors.transparent,
        ],
        stops: const [0.1, 0.4, 0.5, 0.6, 0.9],
      ).createShader(Rect.fromPoints(game.project3D(-matW * 0.9, 0), game.project3D(matW * 0.9, 0)))
      ..strokeWidth = 2.0;
    
    canvas.drawLine(game.project3D(-matW * 0.9, 0), game.project3D(matW * 0.9, 0), centerDividerPaint);

    // 4. 背景环境尘埃 (微小、淡雅，增加 3D 深度感)
    for (var i = 0; i < _dustParticles.length; i++) {
      final p = _dustParticles[i];
      final double dx = (p.dx * 1400 - 700) + sin(_time * 0.3 + i) * 30;
      final double dy = (p.dy * 1000 - 500) + cos(_time * 0.2 + i) * 30;
      final proj = game.project3D(dx, dy, lift: 80 + sin(_time * 0.5 + i) * 30);
      canvas.drawCircle(proj, 0.8, Paint()..color = const Color(0xFF00F0FF).withOpacity(0.12));
    }
  }
}
