import 'package:flutter/material.dart';
import 'package:ygo_card/card_info.dart';
import 'dart:math';

class SummonAnimation extends StatefulWidget {
  final CardInfo card;
  final String imageUrl;
  final VoidCallback onComplete;

  const SummonAnimation({
    super.key,
    required this.card,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<SummonAnimation> createState() => _SummonAnimationState();
}

class _SummonAnimationState extends State<SummonAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _flashAnimation;
  late Animation<double> _shockwaveAnimation;
  late Animation<double> _lightBeamAnimation;
  late Animation<double> _particlesAnimation;
  late Animation<double> _cardMaterializeAnimation;
  late Animation<double> _auraAnimation;

  late List<Particle> _particles;
  final Random _random = Random();

  late SummonStyle _summonStyle;

  @override
  void initState() {
    super.initState();
    _summonStyle = _getSummonStyle(widget.card);
    _initParticles();
    _initAnimations();
  }

  void _initParticles() {
    _particles = [];
    const count = 60;
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        angle: (i / count) * 2 * pi,
        radius: _random.nextDouble() * 50 + 10,
        speed: _random.nextDouble() * 3 + 1,
        size: _random.nextDouble() * 6 + 2,
        delay: _random.nextDouble() * 0.5,
        color: _summonStyle.particleColors[_random.nextInt(_summonStyle.particleColors.length)],
      ));
    }
  }

  void _initAnimations() {
    const totalDuration = Duration(seconds: 3);

    _mainController = AnimationController(
      duration: totalDuration,
      vsync: this,
    );

    _flashAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _shockwaveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.6, curve: Curves.easeOut),
      ),
    );

    _lightBeamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );

    _particlesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 1.2 / 3, curve: Curves.easeOut),
      ),
    );

    _cardMaterializeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _auraAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _mainController.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
    });
  }

  SummonStyle _getSummonStyle(CardInfo card) {
    if (card.isFusion) {
      return SummonStyle.fusion();
    }
    if (card.isSynchro) {
      return SummonStyle.synchro();
    }
    if (card.isXyz) {
      return SummonStyle.xyz();
    }
    if (card.isLink) {
      return SummonStyle.link();
    }
    if (card.isSpell) {
      return SummonStyle.spell();
    }
    if (card.isTrap) {
      return SummonStyle.trap();
    }
    if ((card.type & 0x8000) != 0) {
      return SummonStyle.specialSummon();
    }
    return SummonStyle.normal();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackground(),
          _buildShockwave(),
          _buildLightBeam(),
          _buildParticles(),
          _buildCardMaterialize(),
          _buildAura(),
          _buildFlash(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 0.5),
          radius: 1.0,
          colors: [
            _summonStyle.primaryColor.withValues(alpha: 0.3),
            Colors.black,
          ],
        ),
      ),
    );
  }

  Widget _buildShockwave() {
    return AnimatedBuilder(
      animation: _shockwaveAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ShockwavePainter(
            progress: _shockwaveAnimation.value,
            color: _summonStyle.primaryColor,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildLightBeam() {
    return AnimatedBuilder(
      animation: _lightBeamAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: LightBeamPainter(
            progress: _lightBeamAnimation.value,
            color: _summonStyle.primaryColor,
            style: _summonStyle.lightStyle,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particlesAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleFieldPainter(
            particles: _particles,
            progress: _particlesAnimation.value,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildCardMaterialize() {
    return AnimatedBuilder(
      animation: _cardMaterializeAnimation,
      builder: (context, child) {
        final progress = _cardMaterializeAnimation.value;
        final size = MediaQuery.of(context).size;
        final cardWidth = size.width * 0.35;
        final cardHeight = cardWidth * 1.4;

        return Center(
          child: Transform(
            transform: Matrix4.diagonal3Values(progress * 0.8 + 0.2, progress * 0.8 + 0.2, 1.0)
              ..rotateX((1 - progress) * pi),
            alignment: Alignment.center,
            child: Opacity(
              opacity: progress,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _summonStyle.primaryColor,
                      blurRadius: 40 * progress,
                      spreadRadius: 20 * progress,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAura() {
    return AnimatedBuilder(
      animation: _auraAnimation,
      builder: (context, child) {
        final progress = _auraAnimation.value;
        final size = MediaQuery.of(context).size;

        return Center(
          child: Container(
            width: size.width * 0.5,
            height: size.height * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _summonStyle.primaryColor.withValues(alpha: progress * 0.8),
                width: 3 * progress,
              ),
              boxShadow: [
                BoxShadow(
                  color: _summonStyle.primaryColor.withValues(alpha: progress * 0.3),
                  blurRadius: 60 * progress,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlash() {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.white.withValues(alpha: _flashAnimation.value * 0.8),
        );
      },
    );
  }
}

class Particle {
  final double angle;
  final double radius;
  final double speed;
  final double size;
  final double delay;
  final Color color;

  Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.delay,
    required this.color,
  });
}

class SummonStyle {
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> particleColors;
  final LightStyle lightStyle;

  SummonStyle({
    required this.primaryColor,
    required this.secondaryColor,
    required this.particleColors,
    required this.lightStyle,
  });

  static SummonStyle normal() {
    return SummonStyle(
      primaryColor: Colors.amber,
      secondaryColor: Colors.amber[700]!,
      particleColors: [Colors.amber, Colors.amber[700]!, Colors.yellow, Colors.orange],
      lightStyle: LightStyle.column,
    );
  }

  static SummonStyle specialSummon() {
    return SummonStyle(
      primaryColor: Colors.blue,
      secondaryColor: Colors.cyan,
      particleColors: [Colors.blue, Colors.cyan, Colors.lightBlue, Colors.white],
      lightStyle: LightStyle.radial,
    );
  }

  static SummonStyle fusion() {
    return SummonStyle(
      primaryColor: Colors.purple,
      secondaryColor: Colors.deepPurple,
      particleColors: [Colors.purple, Colors.deepPurple, Colors.pink, Colors.purpleAccent],
      lightStyle: LightStyle.spiral,
    );
  }

  static SummonStyle synchro() {
    return SummonStyle(
      primaryColor: const Color(0xFF00D4FF),
      secondaryColor: Colors.greenAccent,
      particleColors: [const Color(0xFF00D4FF), Colors.greenAccent, Colors.cyan, Colors.white],
      lightStyle: LightStyle.radial,
    );
  }

  static SummonStyle xyz() {
    return SummonStyle(
      primaryColor: const Color(0xFF9D4EDD),
      secondaryColor: Colors.black,
      particleColors: [const Color(0xFF9D4EDD), Colors.white, Colors.purple, Colors.indigo],
      lightStyle: LightStyle.blackHole,
    );
  }

  static SummonStyle link() {
    return SummonStyle(
      primaryColor: Colors.blueAccent,
      secondaryColor: Colors.lightBlue,
      particleColors: [Colors.blueAccent, Colors.lightBlue, Colors.cyan, Colors.white],
      lightStyle: LightStyle.lines,
    );
  }

  static SummonStyle spell() {
    return SummonStyle(
      primaryColor: Colors.blue,
      secondaryColor: Colors.lightBlue,
      particleColors: [Colors.blue, Colors.lightBlue, Colors.cyan],
      lightStyle: LightStyle.runes,
    );
  }

  static SummonStyle trap() {
    return SummonStyle(
      primaryColor: Colors.purple,
      secondaryColor: Colors.deepPurple,
      particleColors: [Colors.purple, Colors.deepPurple, Colors.red],
      lightStyle: LightStyle.shadow,
    );
  }
}

enum LightStyle {
  column,
  radial,
  spiral,
  blackHole,
  lines,
  runes,
  shadow,
}

class ShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  ShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    for (int i = 0; i < 3; i++) {
      final waveProgress = max(0.0, min(1.0, (progress * 3) - i));
      final radius = waveProgress * maxRadius * 0.8;
      final opacity = (1 - waveProgress) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 4 - (waveProgress * 3)
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class LightBeamPainter extends CustomPainter {
  final double progress;
  final Color color;
  final LightStyle style;

  LightBeamPainter({
    required this.progress,
    required this.color,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (style) {
      case LightStyle.column:
        _paintColumn(canvas, size, center);
        break;
      case LightStyle.radial:
        _paintRadial(canvas, size, center);
        break;
      case LightStyle.spiral:
        _paintSpiral(canvas, size, center);
        break;
      case LightStyle.blackHole:
        _paintBlackHole(canvas, size, center);
        break;
      case LightStyle.lines:
        _paintLines(canvas, size, center);
        break;
      case LightStyle.runes:
        _paintRunes(canvas, size, center);
        break;
      case LightStyle.shadow:
        _paintShadow(canvas, size, center);
        break;
    }
  }

  void _paintColumn(Canvas canvas, Size size, Offset center) {
    final height = size.height * progress;
    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.1),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.4,
      height: height * 2,
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  void _paintRadial(Canvas canvas, Size size, Offset center) {
    const lineCount = 12;
    final maxLength = size.width * 0.6;

    for (int i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * 2 * pi + (progress * pi);
      final length = maxLength * progress;
      final start = center;
      final end = Offset(
        center.dx + cos(angle) * length,
        center.dy + sin(angle) * length,
      );

      final gradient = LinearGradient(
        colors: [
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0),
        ],
      );

      final paint = Paint()
        ..strokeWidth = 3
        ..shader = gradient.createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, paint);
    }
  }

  void _paintSpiral(Canvas canvas, Size size, Offset center) {
    final maxRadius = size.width * 0.5;
    const turns = 3;

    final path = Path();
    for (double t = 0; t <= progress * turns * 2 * pi; t += 0.05) {
      final radius = (t / (turns * 2 * pi)) * maxRadius;
      final x = center.dx + cos(t) * radius;
      final y = center.dy + sin(t) * radius;
      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.2),
      ],
    );

    canvas.drawPath(
      path,
      Paint()
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..shader = gradient.createShader(Offset.zero & size),
    );
  }

  void _paintBlackHole(Canvas canvas, Size size, Offset center) {
    final radius = size.width * 0.3 * (1 - progress) + size.width * 0.05;

    final gradient = RadialGradient(
      colors: [
        Colors.black,
        color.withValues(alpha: 0.6),
        Colors.black,
      ],
      center: Alignment(center.dx / size.width * 2 - 1, center.dy / size.height * 2 - 1),
      radius: radius / min(size.width, size.height),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  void _paintLines(Canvas canvas, Size size, Offset center) {
    const lineCount = 8;
    final height = size.height * progress;

    for (int i = 0; i < lineCount; i++) {
      final x = center.dx + ((i - lineCount / 2) * (size.width / lineCount));
      final start = Offset(x, size.height);
      final end = Offset(x, size.height - height);

      final gradient = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.6),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 2
          ..shader = gradient.createShader(Rect.fromPoints(start, end)),
      );
    }
  }

  void _paintRunes(Canvas canvas, Size size, Offset center) {
    final radius = size.width * 0.3 * progress;

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      canvas.drawCircle(
        Offset(x, y),
        8 * progress,
        Paint()..color = color.withValues(alpha: 0.8),
      );

      canvas.drawLine(
        center,
        Offset(x, y),
        Paint()
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.4),
      );
    }
  }

  void _paintShadow(Canvas canvas, Size size, Offset center) {
    final radius = size.width * 0.4 * progress;

    final gradient = RadialGradient(
      colors: [
        Colors.black.withValues(alpha: 0.9),
        color.withValues(alpha: 0.3),
        Colors.black.withValues(alpha: 0),
      ],
      center: Alignment(center.dx / size.width * 2 - 1, center.dy / size.height * 2 - 1),
      radius: radius / min(size.width, size.height),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant LightBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.style != style;
  }
}

class ParticleFieldPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticleFieldPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final particleProgress = max(0.0, min(1.0, (progress - particle.delay) * 2));
      if (particleProgress <= 0) continue;

      final angle = particle.angle + particleProgress * 2 * pi * 0.5;
      final radius = particle.radius + particleProgress * 200 * particle.speed;
      final yOffset = -particleProgress * 300;

      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius + yOffset;

      final opacity = (1 - particleProgress) * 0.8;
      final size = particle.size * (1 - particleProgress * 0.5);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..blendMode = BlendMode.plus;

      canvas.drawCircle(Offset(x, y), size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleFieldPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}