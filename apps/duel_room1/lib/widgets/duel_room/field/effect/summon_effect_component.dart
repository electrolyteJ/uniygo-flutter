import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../duel_field_world.dart';
import 'summon_effect_style.dart';

/// 通用层召唤特效驱动组件：监听快照的 `summonEffectTick`，
/// 把事件经 FIFO 队列依次播放（连续召唤不打断，语义同抽卡动画队列）。
///
/// 渲染全部由 [_SummonEffectPlayer] 承担（纯 Canvas 几何阵 + 自管粒子 +
/// 卡图显现，零美术资产）。挂载在 [DuelFieldWorld]（zone 之上、
/// 战斗呈现之下，priority 25）。
class SummonEffectComponent extends Component
    with HasWorldReference<DuelFieldWorld> {
  SummonEffectComponent() : super(priority: 25);

  final Queue<SummonEffectEvent> _queue = Queue();
  _SummonEffectPlayer? _active;
  int _lastTick = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final tick = world.game.snapshot.summonEffectTick;
    if (tick != _lastTick) {
      _lastTick = tick;
      final event = world.game.snapshot.summonEffectEvent;
      // tick 与事件 id 不一致（如同批多条消息只见到最新一条）时，
      // 以可见的最新事件为准，中间的退化丢弃（同 deckShuffleTick 语义）。
      if (event != null) {
        _queue.add(event);
      }
    }
    if (_active == null && _queue.isNotEmpty) {
      _startNext(_queue.removeFirst());
    }
  }

  /// 立即播放一条事件（debug 触发 / 未来王牌层分流复用）。
  void playNow(SummonEffectEvent event) => _queue.add(event);

  void _startNext(SummonEffectEvent event) {
    final pos = world.worldPositionForSlotId(event.slotId) ?? Vector2.zero();
    final player = _SummonEffectPlayer(
      event: event,
      style: kSummonEffectStyles[event.type]!,
      cardImage:
          event.code > 0 ? world.getCachedCardImage(event.code) : null,
      position: pos,
      onFinished: () {
        _active = null;
      },
    );
    _active = player;
    world.add(player);
  }
}

/// 单条召唤演出的播放器（自移除式 PositionComponent）。
///
/// 时间线（总长约 1.1s）：
/// - 0.00–0.35 聚集：双环+六辐中线缩放展开并旋转，粒子从四周汇聚；
/// - 0.35–0.60 显现：光柱爆闪，卡图从阵中升起（过冲回弹）；
/// - 0.60–1.10 余韵：粒子外扩衰减、环淡出，卡图交叉淡出
///   （zone 真实卡组件接管显示，避免双卡同框）。
class _SummonEffectPlayer extends PositionComponent {
  _SummonEffectPlayer({
    required this.event,
    required this.style,
    required this.cardImage,
    required this.onFinished,
    super.position,
  }) : super(anchor: Anchor.center, priority: 25);

  final SummonEffectEvent event;
  final SummonEffectStyle style;
  final ui.Image? cardImage;
  final void Function() onFinished;

  static const _duration = 1.1;
  static const _gatherEnd = 0.35;
  static const _revealEnd = 0.60;

  /// 卡图尺寸（与卡槽一致）。
  static const _cardW = 68.0;
  static const _cardH = 96.0;

  /// 召唤阵外环半径。
  static const _ringRadius = 56.0;

  double _t = 0;
  bool _done = false;

  final math.Random _rand = math.Random();
  late final List<_Particle> _particles = _makeParticles();

  List<_Particle> _makeParticles() {
    return List.generate(56, (i) {
      final burst = i >= 28; // 一半汇聚、一半爆发
      return _Particle(
        angle: _rand.nextDouble() * 2 * math.pi,
        // 汇聚粒子从 ~130px 外收拢；爆发粒子冲到 ~90px 外
        radius: burst
            ? 60 + _rand.nextDouble() * 40
            : 110 + _rand.nextDouble() * 40,
        size: 1.5 + _rand.nextDouble() * 2.5,
        phase: _rand.nextDouble(),
        burst: burst,
        spin: (_rand.nextDouble() - 0.5) * 2,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done) return;
    _t += dt;
    if (_t >= _duration) {
      _done = true;
      onFinished();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = _t.clamp(0.0, _duration);

    _renderGatherRing(canvas, t);
    if (style.revealCard) {
      _renderFlash(canvas, t);
      _renderCard(canvas, t);
    }
    _renderParticles(canvas, t);
  }

  // ── 召唤阵（双环 + 六辐中线）────────────────────────────────────

  void _renderGatherRing(Canvas canvas, double t) {
    final grow = _easeOutCubic((t / _gatherEnd).clamp(0.0, 1.0));
    if (grow <= 0) return;
    // 余韵阶段整体淡出
    final fade = t <= _revealEnd
        ? 1.0
        : (1 - (t - _revealEnd) / (_duration - _revealEnd)).clamp(0.0, 1.0);
    final alpha = grow * fade;
    if (alpha <= 0) return;

    final radius = _ringRadius * (0.2 + 0.8 * grow);
    final rotation = grow * math.pi * 1.5 + t * 0.8;

    final ringPaint = Paint()
      ..color = style.primary.withValues(alpha: 0.9 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = style.secondary.withValues(alpha: 0.7 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.rotate(rotation);
    canvas.drawCircle(Offset.zero, radius, ringPaint);
    canvas.drawCircle(Offset.zero, radius * 0.72, innerPaint);
    // 六辐中线（外环到内环）
    final spokePaint = Paint()
      ..color = style.primary.withValues(alpha: 0.6 * alpha)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        Offset(math.cos(a) * radius * 0.72, math.sin(a) * radius * 0.72),
        Offset(math.cos(a) * radius, math.sin(a) * radius),
        spokePaint,
      );
    }
    canvas.restore();
  }

  // ── 爆闪光柱 ────────────────────────────────────────────────────

  void _renderFlash(Canvas canvas, double t) {
    if (t < _gatherEnd || t > _revealEnd) return;
    final k = ((t - _gatherEnd) / (_revealEnd - _gatherEnd)).clamp(0.0, 1.0);
    final strength = math.sin(k * math.pi); // 膨胀-收回

    // 径向光晕
    final glowRadius = 70.0 * (0.4 + 0.6 * k);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          style.secondary.withValues(alpha: 0.85 * strength),
          style.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: glowRadius));
    canvas.drawCircle(Offset.zero, glowRadius, glowPaint);

    // 垂直光柱
    final pillarW = 14.0 * (0.5 + strength);
    final pillarPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          style.primary.withValues(alpha: 0.0),
          style.secondary.withValues(alpha: 0.8 * strength),
          style.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(-pillarW / 2, -90, pillarW, 180));
    canvas.drawRect(Rect.fromLTWH(-pillarW / 2, -90, pillarW, 180), pillarPaint);
  }

  // ── 卡图显现 ────────────────────────────────────────────────────

  void _renderCard(Canvas canvas, double t) {
    final image = cardImage;
    if (image == null || t < _gatherEnd) return;
    final rise =
        _easeOutBack(((t - _gatherEnd) / 0.35).clamp(0.0, 1.0));
    // 末尾交叉淡出（zone 真实卡接管）
    final fadeOut = t <= 0.85
        ? 1.0
        : (1 - (t - 0.85) / (_duration - 0.85)).clamp(0.0, 1.0);
    if (fadeOut <= 0) return;

    final scale = 0.3 + 0.7 * rise;
    final dy = -14 * (1 - rise); // 从阵中微微升起
    canvas.save();
    canvas.translate(0, dy);
    canvas.scale(scale);
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: _cardW,
      height: _cardH,
    );
    final paint = Paint()
      ..colorFilter =
          ColorFilter.mode(Colors.white.withValues(alpha: fadeOut), BlendMode.modulate);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      paint,
    );
    canvas.restore();
  }

  // ── 粒子 ────────────────────────────────────────────────────────

  void _renderParticles(Canvas canvas, double t) {
    final paint = Paint();
    for (final p in _particles) {
      double r; // 当前半径
      double alpha;
      if (!p.burst) {
        // 汇聚：gather 阶段从外圈收拢到中心
        final k = ((t - p.phase * 0.1) / _gatherEnd).clamp(0.0, 1.0);
        r = p.radius * (1 - _easeInCubic(k));
        alpha = k <= 0 ? 0.0 : (k >= 1 ? 0.0 : 0.9);
        // 汇聚结束后不再绘制
        if (t > _revealEnd) continue;
      } else {
        // 爆发：余韵阶段从中心向外扩散衰减
        final k = ((t - _revealEnd) / (_duration - _revealEnd)).clamp(0.0, 1.0);
        if (k <= 0 || t < _revealEnd) continue;
        r = p.radius * _easeOutCubic(k);
        alpha = 1 - k;
      }
      final angle = p.angle + t * p.spin;
      paint.color = style.secondary.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(math.cos(angle) * r, math.sin(angle) * r),
        p.size,
        paint,
      );
    }
  }

  // ── 缓动 ────────────────────────────────────────────────────────

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
  static double _easeInCubic(double t) => t * t * t;
  static double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3).toDouble() + c1 * math.pow(t - 1, 2).toDouble();
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.phase,
    required this.burst,
    required this.spin,
  });

  final double angle;
  final double radius;
  final double size;
  final double phase;
  final bool burst;
  final double spin;
}
