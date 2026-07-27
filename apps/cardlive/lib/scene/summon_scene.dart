import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../service/dragon_geometry.dart';

class SummonScene extends FlameGame {
  final String cardImageUrl;
  final VoidCallback onComplete;

  SummonScene({required this.cardImageUrl, required this.onComplete});

  // 使用 RectangleComponent 代替 PositionComponent，因为它实现了 OpacityProvider
  late RectangleComponent cardContainer;
  SpriteComponent? cardSprite;
  late PositionComponent magicCircle;
  late List<vm.Vector3> dragonPoints;
  double summonProgress = 0.0;
  bool startDragonRender = false;
  
  // 用于背景粒子
  final List<vm.Vector2> bgParticles = [];
  final math.Random random = math.Random();

  @override
  Future<void> onLoad() async {
    // 1. 初始化背景粒子
    for (int i = 0; i < 100; i++) {
      bgParticles.add(vm.Vector2(random.nextDouble() * size.x, random.nextDouble() * size.y));
    }

    // 2. 六芒星魔法阵 (程序化绘制组件)
    magicCircle = HexagramComponent()
      ..size = Vector2.all(450)
      ..anchor = Anchor.center
      ..position = size / 2;
    add(magicCircle);
    
    // 魔法阵逆时针旋转
    magicCircle.add(RotateEffect.by(-math.pi * 2, EffectController(duration: 10, infinite: true)));

    // 3. 悬浮卡牌容器 (设置为透明的 RectangleComponent 以支持 OpacityEffect)
    cardContainer = RectangleComponent()
      ..size = Vector2(180, 260)
      ..anchor = Anchor.center
      ..position = size / 2
      ..paint = (Paint()..color = Colors.transparent);
    add(cardContainer);

    // 加载卡片图片（处理网络 URL）
    _loadCardImage();

    // 卡牌动效 - 现在 cardContainer 支持 OpacityEffect 了
    cardContainer.add(OpacityEffect.to(1.0, EffectController(duration: 1)));
    cardContainer.add(ScaleEffect.to(Vector2.all(1.1), EffectController(duration: 1.5, curve: Curves.easeOutBack)));
    cardContainer.add(MoveEffect.by(Vector2(0, -20), EffectController(duration: 2, reverseDuration: 2, infinite: true)));

    // 4. 准备龙的顶点数据
    final vertices = DragonGeometry.generateDragonVertices();
    dragonPoints = [];
    for (int i = 0; i < vertices.length; i += 3) {
      dragonPoints.add(vm.Vector3(vertices[i], vertices[i + 1], vertices[i + 2]));
    }

    // 延迟启动龙的召唤 (在魔法阵和卡牌出现后)
    Future.delayed(const Duration(seconds: 1), () {
      startDragonRender = true;
    });
  }

  Future<void> _loadCardImage() async {
    try {
      ui.Image image;
      if (cardImageUrl.startsWith('http')) {
        // 使用网络加载
        final completer = Completer<ui.Image>();
        final stream = NetworkImage(cardImageUrl).resolve(ImageConfiguration.empty);
        stream.addListener(ImageStreamListener((info, _) {
          completer.complete(info.image);
        }, onError: (e, s) {
          completer.completeError(e);
        }));
        image = await completer.future;
      } else {
        // 使用本地加载
        image = await Flame.images.load(cardImageUrl);
      }
      print('卡片图片加载成功: $cardImageUrl  尺寸: ${image.width}x${image.height}');
      
      final sprite = Sprite(image);
      // 在构造函数中设置 sprite，防止 onMount 断言失败
      cardSprite = SpriteComponent(
        sprite: sprite,
        size: cardContainer.size.clone(),
      )..opacity = 0;

      cardContainer.add(cardSprite!);
      cardSprite!.add(OpacityEffect.to(1.0, EffectController(duration: 1)));
    } catch (e) {
      debugPrint('加载卡片图片失败: $e');
      // 失败时显示一个带颜色的占位矩形
      final placeholder = RectangleComponent()
        ..size = cardContainer.size.clone()
        ..paint = (Paint()..color = Colors.blueGrey.withOpacity(0.5))
        ..add(OpacityEffect.to(1.0, EffectController(duration: 1)));
      cardContainer.add(placeholder);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // 更新背景粒子
    for (var p in bgParticles) {
      p.y -= dt * 50;
      if (p.y < 0) {
        p.y = size.y;
        p.x = random.nextDouble() * size.x;
      }
    }

    // 更新召唤进度
    if (startDragonRender && summonProgress < 1.0) {
      summonProgress += dt * 0.5; // 2秒完成
      if (summonProgress >= 1.0) {
        summonProgress = 1.0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // 背景变暗
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black.withOpacity(0.85));

    // 绘制背景科技粒子
    final pPaint = Paint()..color = Colors.blueAccent.withOpacity(0.4);
    for (var p in bgParticles) {
      canvas.drawCircle(Offset(p.x, p.y), 1.2, pPaint);
    }

    super.render(canvas); // 渲染魔法阵和卡牌

    if (startDragonRender) {
      _renderDragon(canvas);
    }
  }

  void _renderDragon(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    
    // 闪电特效
    if (random.nextDouble() > 0.85) {
      _drawLightning(canvas, center);
    }

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 颜色插值：从粒子蓝到实体银白
    final colorT = (summonProgress * 1.5).clamp(0.0, 1.0);
    paint.color = Color.lerp(Colors.blueAccent, Colors.white, colorT)!
        .withOpacity(summonProgress.clamp(0.2, 1.0));

    // 3D 旋转角度 (随时间旋转)
    double angle = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    for (var pt in dragonPoints) {
      // 围绕 Y 轴旋转点
      double rx = pt.x * math.cos(angle) - pt.z * math.sin(angle);
      double rz = pt.x * math.sin(angle) + pt.z * math.cos(angle);
      double ry = pt.y;

      // 投影
      double zScale = 400 / (400 + rz + 5); // 简单的投影
      double x = center.dx + rx * 120 * zScale;
      double y = center.dy - ry * 120 * zScale; // 向上为正

      if (summonProgress < 0.6) {
        // 线条粒子阶段：绘制小点
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      } else {
        // 实体化阶段：绘制稍大的方块或相连感
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 2, height: 2), paint..style = PaintingStyle.fill);
      }
    }
  }

  void _drawLightning(Canvas canvas, Offset origin) {
    final lPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    
    final path = Path();
    double startX = origin.dx + (random.nextDouble() - 0.5) * 300;
    path.moveTo(startX, 0);
    
    double currX = startX;
    double currY = 0;
    while (currY < size.y) {
      currX += (random.nextDouble() - 0.5) * 100;
      currY += random.nextDouble() * 100;
      path.lineTo(currX, currY);
    }
    canvas.drawPath(path, lPaint);
  }
}

class HexagramComponent extends PositionComponent {
  final Paint _paint = Paint()
    ..color = Colors.blueAccent.withOpacity(0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;
    
    // 外圈圆
    canvas.drawCircle(center, radius, _paint);
    canvas.drawCircle(center, radius * 0.9, _paint..strokeWidth = 1);

    // 六芒星 (两个三角形)
    _drawTriangle(canvas, center, radius * 0.85, 0);
    _drawTriangle(canvas, center, radius * 0.85, math.pi);
    
    // 内部一些科技感线条
    canvas.drawCircle(center, radius * 0.4, _paint);
  }

  void _drawTriangle(Canvas canvas, Offset center, double radius, double rotation) {
    final path = Path();
    for (int i = 0; i < 3; i++) {
      double angle = rotation + (i * 2 * math.pi / 3) - math.pi / 2;
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, _paint);
  }
}
