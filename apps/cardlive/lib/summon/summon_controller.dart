import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'styles/summon_style.dart';
import 'styles/style_provider.dart';
import 'components/ring_component.dart';
import 'components/beam_component.dart';
import 'components/particle_system.dart';
import 'components/card_sprite.dart';
import 'stages/stage_sequence.dart';

/// Flame 游戏 —— 完整的 5 阶段召唤动效场景
class SummonController extends FlameGame {
  final String cardImageUrl;
  final String cardName;
  final SummonType summonType;
  final VoidCallback onComplete;
  final double backgroundAlpha; // Overlay=0.9, Inline=0.65

  late SummonStyle _style;
  late StageSequence _sequence;

  // 组件引用
  late RingComponent _ring;
  late BeamComponent _beam;
  late ParticleSystem _particles;
  late CardSpriteComponent _cardSprite;

  // 闪白效果
  double _flashAlpha = 1.0;

  // 背景粒子
  final List<Offset> _bgParticles = [];
  final math.Random _random = math.Random();

  SummonController({
    required this.cardImageUrl,
    required this.cardName,
    required this.summonType,
    required this.onComplete,
    this.backgroundAlpha = 0.9,
  });

  @override
  Future<void> onLoad() async {
    _style = styleForType(summonType);

    // 初始化背景粒子
    for (int i = 0; i < 80; i++) {
      _bgParticles.add(Offset(
        _random.nextDouble() * 800,
        _random.nextDouble() * 600,
      ));
    }

    final center = size / 2;

    // 光柱组件（全屏）
    _beam = BeamComponent(style: _style)
      ..position = center
      ..size = size;
    add(_beam);

    // 粒子系统
    _particles = ParticleSystem(style: _style)..position = center;
    add(_particles);

    // 光环组件
    _ring = RingComponent(style: _style)..position = center;
    add(_ring);

    // 卡片精灵
    _cardSprite = CardSpriteComponent(
      imageUrl: cardImageUrl,
      size: Vector2(160, 220),
    )..position = center;
    add(_cardSprite);

    // 启动阶段序列
    _sequence = StageSequence(onComplete: () {
      // 延迟少许后回调
      Future.delayed(const Duration(milliseconds: 200), onComplete);
    });
    _sequence.start();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sequence.update(dt);

    // 闪白阶段
    final flashStage = _sequence.stage(StageType.flash);
    if (flashStage != null) {
      _flashAlpha = (1.0 - flashStage.progress).clamp(0.0, 1.0);
    }

    // 光柱阶段
    final beamStage = _sequence.stage(StageType.beam);
    if (beamStage != null) {
      _beam.progress = beamStage.progress;
    }

    // 粒子阶段
    final particleStage = _sequence.stage(StageType.particles);
    if (particleStage != null) {
      _particles.progress = particleStage.progress;
      if (particleStage.progress > 0.1 && !_particles.hasEmitted) {
        _particles.emit();
      }
    }

    // 实体化阶段
    final materializeStage = _sequence.stage(StageType.materialize);
    if (materializeStage != null) {
      final p = materializeStage.progress;
      _cardSprite.materializeProgress = p;
      // 从 0.2x 缩放到 1.0x，带弹性曲线
      final scale = 0.2 + p * 0.8 + math.sin(p * math.pi) * 0.15;
      _cardSprite.scale = Vector2.all(scale);
      _cardSprite.opacity = (p * 1.2).clamp(0.0, 1.0);
    }

    // 光环阶段
    final auraStage = _sequence.stage(StageType.aura);
    if (auraStage != null) {
      _ring.summonProgress = auraStage.progress;
    }

    // 更新背景粒子
    for (int i = 0; i < _bgParticles.length; i++) {
      final p = _bgParticles[i];
      _bgParticles[i] = Offset(p.dx, (p.dy - dt * 40) % size.y.abs());
    }
  }

  @override
  void render(Canvas canvas) {
    // 暗背景
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.black.withValues(alpha: backgroundAlpha));

    // 背景微粒子
    final bgPaint = Paint()
      ..color = _style.primaryColor.withValues(alpha: 0.2);
    for (final p in _bgParticles) {
      canvas.drawCircle(p, 1, bgPaint);
    }

    // 闪白覆盖层
    if (_flashAlpha > 0.01) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()..color = Colors.white.withValues(alpha: _flashAlpha * 0.7));
    }

    super.render(canvas);

    // 卡片名称（底部居中）
    if (_sequence.totalProgress > 0.4) {
      final nameAlpha = ((_sequence.totalProgress - 0.4) * 2).clamp(0.0, 1.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$cardName · ${_style.label}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: nameAlpha),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            shadows: [
              Shadow(
                color: _style.primaryColor.withValues(alpha: nameAlpha * 0.8),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.x - 40);
      textPainter.paint(
          canvas, Offset((size.x - textPainter.width) / 2, size.y - 60));
    }
  }
}
