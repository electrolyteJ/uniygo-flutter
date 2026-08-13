import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 卡组洗切动效：在卡组槽位上播放一段「摊开 → 交叉洗牌 → 收拢」的动画。
///
/// 纯 Canvas 绘制一组卡背，随播放进度做位移/旋转/缩放，播完自动从场景移除。
class DeckShuffleEffect extends PositionComponent {
  static const _cardW = 44.0;
  static const _cardH = 62.0;
  static const _duration = 0.9;
  static const _spread = 90.0;

  /// 洗牌时的抖动幅度（垂直方向）。
  static const _jitterAmp = 8.0;

  final Random _rand = Random();
  double _elapsed = 0;

  /// 每张卡独立的随机相位，避免洗牌动作完全同步。
  late final List<double> _phases = List.generate(
    _cardCount,
    (_) => _rand.nextDouble() * 2 * pi,
  );
  static const int _cardCount = 6;

  DeckShuffleEffect({super.position}) : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    for (var i = 0; i < _cardCount; i++) {
      final state = _cardState(i, t);
      canvas.save();
      canvas.translate(state.dx, state.dy);
      canvas.rotate(state.rotation);
      canvas.scale(state.scale);
      _drawCardBack(canvas);
      canvas.restore();
    }
  }

  /// 阶段划分：
  /// 0.0-0.35 摊开（左右两半沿水平散开，轻微旋转/上浮）；
  /// 0.35-0.70 交叉洗牌（每张卡随机相位左右往返，带垂直抖动）；
  /// 0.70-1.00 收拢（回到中心叠加成一摞）。
  _CardState _cardState(int index, double t) {
    final half = index < _cardCount / 2 ? -1.0 : 1.0;
    final within = index % (_cardCount ~/ 2);
    final phase = _phases[index];

    final open = _easeInOut((t / 0.35).clamp(0.0, 1.0));
    final riffle = _easeInOut(((t - 0.35) / 0.35).clamp(0.0, 1.0));
    final close = _easeInOut(((t - 0.70) / 0.30).clamp(0.0, 1.0));

    final baseX = half * _spread * open;
    final riffleX = sin(t * 6 * pi + phase) * _spread * 0.8 * riffle;

    final dx = baseX * (1 - close) + riffleX * (1 - close);
    final dy =
        -(within % 2) * 3 * open +
        cos(t * 5 * pi + phase) * _jitterAmp * riffle;
    final rotation =
        half * 0.18 * open +
        sin(t * 7 * pi + phase) * 0.35 * riffle -
        half * 0.18 * close;
    final scale = 1.0 + 0.25 * open + 0.1 * riffle - 0.25 * close;

    return _CardState(dx: dx, dy: dy, rotation: rotation, scale: scale);
  }

  void _drawCardBack(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _cardW,
      height: _cardH,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF31475E), Color(0xFF0A1020)],
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()
        ..color = const Color(0x5900F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  double _easeInOut(double x) => x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2;
}

class _CardState {
  final double dx;
  final double dy;
  final double rotation;
  final double scale;

  const _CardState({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.scale,
  });
}
