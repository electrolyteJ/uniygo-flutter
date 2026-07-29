import 'dart:math';
import 'package:flutter/material.dart';

enum _Kind { spark, ring, bolt, flash }

class _P {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double g = 0;
  double size = 2;
  double r = 0;
  double max = 0;
  int life = 0;
  int ttl = 24;
  Color color = Colors.white;
  _Kind kind = _Kind.spark;
  List<Offset> pts = const [];
}

class FxEngine extends ChangeNotifier {
  final List<_P> _parts = [];
  final Map<String, Offset> anchors = {};
  final Random _rng = Random();
  int _shakeUntil = 0;

  void registerAnchor(String key, Offset global) {
    anchors[key] = global;
  }

  Offset? anchor(String key) => anchors[key];

  bool get active =>
      _parts.isNotEmpty || DateTime.now().millisecondsSinceEpoch < _shakeUntil;

  void burst(Offset p, List<Color> colors, {int n = 26, double pow = 7}) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = _rng.nextDouble() * pow + 1;
      _parts.add(_P()
        ..kind = _Kind.spark
        ..x = p.dx
        ..y = p.dy
        ..vx = cos(a) * sp
        ..vy = sin(a) * sp - 2
        ..g = 0.16
        ..size = 1.5 + _rng.nextDouble() * 2.6
        ..ttl = 26 + _rng.nextInt(24)
        ..color = colors[_rng.nextInt(colors.length)]);
    }
    notifyListeners();
  }

  void burstAt(String key, List<Color> colors, {int n = 26, double pow = 7}) {
    final p = anchors[key];
    if (p != null) burst(p, colors, n: n, pow: pow);
  }

  void ring(Offset p, Color c, {double max = 130, double w = 3}) {
    _parts.add(_P()
      ..kind = _Kind.ring
      ..x = p.dx
      ..y = p.dy
      ..r = 6
      ..max = max
      ..size = w
      ..ttl = 26
      ..color = c);
    notifyListeners();
  }

  void ringAt(String key, Color c, {double max = 130}) {
    final p = anchors[key];
    if (p != null) ring(p, c, max: max);
  }

  void pillar(Offset p, List<Color> colors) {
    for (var i = 0; i < 18; i++) {
      _parts.add(_P()
        ..kind = _Kind.spark
        ..x = p.dx + _rng.nextDouble() * 46 - 23
        ..y = p.dy + _rng.nextDouble() * 10
        ..vx = (_rng.nextDouble() - .5) * .8
        ..vy = -(3 + _rng.nextDouble() * 5)
        ..size = 1.6 + _rng.nextDouble() * 2
        ..ttl = 26 + _rng.nextInt(14)
        ..color = colors[_rng.nextInt(colors.length)]);
    }
    notifyListeners();
  }

  void pillarAt(String key, List<Color> colors) {
    final p = anchors[key];
    if (p != null) pillar(p, colors);
  }

  void beam(String fromKey, String toKey, Color c) {
    final a = anchors[fromKey];
    final b = anchors[toKey];
    if (a == null || b == null) return;
    final pts = <Offset>[a];
    for (var i = 1; i < 7; i++) {
      final k = i / 7;
      pts.add(Offset(
        a.dx + (b.dx - a.dx) * k + (_rng.nextDouble() * 36 - 18),
        a.dy + (b.dy - a.dy) * k + (_rng.nextDouble() * 36 - 18),
      ));
    }
    pts.add(b);
    _parts.add(_P()
      ..kind = _Kind.bolt
      ..pts = pts
      ..ttl = 13
      ..size = 3
      ..color = c);
    for (var i = 0; i < 14; i++) {
      final k = _rng.nextDouble();
      _parts.add(_P()
        ..kind = _Kind.spark
        ..x = a.dx + (b.dx - a.dx) * k
        ..y = a.dy + (b.dy - a.dy) * k
        ..vx = (_rng.nextDouble() - .5) * 1.6
        ..vy = (_rng.nextDouble() - .5) * 1.6
        ..size = 1.6 + _rng.nextDouble() * 2
        ..ttl = 14 + _rng.nextInt(10)
        ..color = c);
    }
    notifyListeners();
  }

  void flash(Color c) {
    _parts.add(_P()
      ..kind = _Kind.flash
      ..ttl = 22
      ..color = c);
    notifyListeners();
  }

  void shake() {
    _shakeUntil = DateTime.now().millisecondsSinceEpoch + 350;
    notifyListeners();
  }

  Offset get shakeOffset {
    final remain = _shakeUntil - DateTime.now().millisecondsSinceEpoch;
    if (remain <= 0) return Offset.zero;
    final k = remain / 350;
    return Offset((_rng.nextDouble() * 2 - 1) * 7 * k,
        (_rng.nextDouble() * 2 - 1) * 5 * k);
  }

  void tick() {
    if (_parts.isEmpty) {
      notifyListeners();
      return;
    }
    _parts.removeWhere((p) {
      p.life++;
      switch (p.kind) {
        case _Kind.spark:
          p.x += p.vx;
          p.y += p.vy;
          p.vy += p.g;
          p.vx *= .985;
        case _Kind.ring:
          p.r += (p.max - p.r) * .16;
        case _Kind.bolt:
          break;
        case _Kind.flash:
          break;
      }
      return p.life >= p.ttl;
    });
    notifyListeners();
  }

  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final p in _parts) {
      final a = 1 - p.life / p.ttl;
      switch (p.kind) {
        case _Kind.spark:
          paint.shader = null;
          paint.color = p.color.withValues(alpha: a);
          canvas.drawCircle(Offset(p.x, p.y), p.size * a + .4, paint);
          paint.color = p.color.withValues(alpha: a * .4);
          canvas.drawCircle(Offset(p.x, p.y), p.size * 2.2 * a, paint);
        case _Kind.ring:
          paint.color = p.color.withValues(alpha: a * .9);
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = p.size * a + 1;
          canvas.drawCircle(Offset(p.x, p.y), p.r, paint);
          paint.style = PaintingStyle.fill;
        case _Kind.bolt:
          paint.color = p.color.withValues(alpha: a);
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = p.size * a + 1;
          final path = Path();
          if (p.pts.isNotEmpty) {
            path.moveTo(p.pts[0].dx, p.pts[0].dy);
            for (final q in p.pts.skip(1)) {
              path.lineTo(q.dx, q.dy);
            }
          }
          canvas.drawPath(path, paint);
          paint.style = PaintingStyle.fill;
        case _Kind.flash:
          paint.color = p.color.withValues(alpha: a);
          canvas.drawRect(Offset.zero & size, paint);
      }
    }
  }
}
