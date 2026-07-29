import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/duel_theme.dart';

class _Star {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
  const _Star(this.x, this.y, this.size, this.phase, this.speed);
}

class _Mote {
  final double x;
  final double period;
  final double delay;
  final bool gold;
  const _Mote(this.x, this.period, this.delay, this.gold);
}

class CosmosBackground extends StatefulWidget {
  const CosmosBackground({super.key});

  @override
  State<CosmosBackground> createState() => _CosmosBackgroundState();
}

class _CosmosBackgroundState extends State<CosmosBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
    final rng = Random(7);
    _stars = List.generate(
        90,
        (i) => _Star(rng.nextDouble(), rng.nextDouble(),
            rng.nextDouble() * 2 + 1, rng.nextDouble() * 2 * pi, 1 + rng.nextDouble() * 3));
    _motes = List.generate(
        20,
        (i) => _Mote(rng.nextDouble(), 9 + rng.nextDouble() * 14,
            rng.nextDouble(), rng.nextDouble() < .4));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: _CosmosPainter(_ctrl.value, _stars, _motes),
        size: Size.infinite,
      ),
    );
  }
}

class _CosmosPainter extends CustomPainter {
  final double t;
  final List<_Star> stars;
  final List<_Mote> motes;

  _CosmosPainter(this.t, this.stars, this.motes);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Paint();
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DuelTheme.void_, Color(0xFF080A1C), DuelTheme.void_],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    void nebula(Offset c, double r, Color color) {
      base.shader = RadialGradient(colors: [color, Colors.transparent])
          .createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawRect(rect, base);
    }

    nebula(Offset(w * .72, h * -.1), w * .7, const Color(0x661A2150));
    nebula(Offset(w * .12, h * 1.12), w * .55, const Color(0x592A1440));
    nebula(Offset(w * .88, h * .82), w * .45, const Color(0x4D0E2C3A));

    final tw = t * 2 * pi;
    for (final s in stars) {
      final a = .15 + .75 * ((sin(tw * s.speed + s.phase) + 1) / 2);
      base.shader = null;
      base.color = const Color(0xFFCFE9FF).withValues(alpha: a);
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.size / 2, base);
    }

    for (final m in motes) {
      final frac = (t * (24 / m.period) + m.delay) % 1.0;
      final y = h * (1 - frac);
      final fade = sin(frac * pi);
      final color = m.gold
          ? const Color(0xFFE8B84B).withValues(alpha: .5 * fade)
          : const Color(0xFF3FE0FF).withValues(alpha: .5 * fade);
      base.shader = null;
      base.color = color;
      canvas.drawCircle(Offset(m.x * w, y), 1.6, base);
      base.color = color.withValues(alpha: .25 * fade);
      canvas.drawCircle(Offset(m.x * w, y), 4, base);
    }
  }

  @override
  bool shouldRepaint(_CosmosPainter old) => old.t != t;
}
