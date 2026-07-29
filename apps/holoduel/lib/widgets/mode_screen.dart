import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/duel_card.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';
import 'card_face.dart';

class ModeScreen extends StatefulWidget {
  final ValueChanged<GameMode> onPick;

  const ModeScreen({super.key, required this.onPick});

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _ring,
          child: CustomPaint(size: const Size(560, 560), painter: _ModeRingPainter()),
        ),
        Positioned(
          left: 40,
          top: 90,
          child: Transform.rotate(
            angle: -0.24,
            child: CardFace(card: CardDb.make('ra'), width: 130)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(end: -16, duration: 3.seconds, curve: Curves.easeInOut),
          ),
        ),
        Positioned(
          right: 40,
          bottom: 80,
          child: Transform.rotate(
            angle: 0.19,
            child: CardFace(card: CardDb.make('scarab'), width: 130, faceDown: true)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(end: -14, duration: 3.6.seconds, curve: Curves.easeInOut),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    center: Alignment(0, -0.24), colors: [Color(0xFF1C2356), Color(0xFF0A0D24)]),
                border: Border.all(color: DuelTheme.gold.withValues(alpha: .6)),
                boxShadow: [
                  BoxShadow(color: DuelTheme.gold.withValues(alpha: .35), blurRadius: 36),
                ],
              ),
              child: Center(
                child: Text('☥',
                    style: TextStyle(
                        fontSize: 36,
                        color: DuelTheme.goldHi,
                        shadows: [Shadow(color: DuelTheme.gold.withValues(alpha: .9), blurRadius: 14)])),
              ),
            ),
            const SizedBox(height: 18),
            Text('决斗领域',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 16,
                  color: DuelTheme.goldHi,
                  shadows: [
                    Shadow(color: DuelTheme.gold.withValues(alpha: .75), blurRadius: 40),
                    const Shadow(color: Color(0xFF6A4A14), offset: Offset(0, 4)),
                  ],
                )),
            const SizedBox(height: 10),
            Text('DUEL ARENA',
                style: DuelTheme.tech(14, color: DuelTheme.cyan, w: FontWeight.w800, ls: 11)
                    .copyWith(shadows: [
                  Shadow(color: DuelTheme.cyan.withValues(alpha: .8), blurRadius: 16),
                ])),
            const SizedBox(height: 12),
            Text('全息卡牌对战 · HOLOGRAPHIC CARD BATTLE',
                style: DuelTheme.body(11, color: DuelTheme.textFaint, ls: 5)),
            const SizedBox(height: 48),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeCard(
                  glyph: '⚔',
                  title: '单人挑战',
                  en: 'SOLO DUEL',
                  desc: '对战 AI 决斗者「深渊行者」。\n它会召唤、施法、盖放陷阱,\n伺机直击你的生命值。',
                  gold: true,
                  onTap: () => widget.onPick(GameMode.ai),
                ),
                const SizedBox(width: 26),
                _ModeCard(
                  glyph: '☥',
                  title: '双人对战',
                  en: 'LOCAL VERSUS',
                  desc: '同屏轮流操作,回合间交接\n设备隐藏手牌。与身边的决\n斗者一决高下。',
                  gold: false,
                  onTap: () => widget.onPick(GameMode.local),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Text('支持拖拽召唤 · 陷阱连锁反制 · 技能特效',
                style: DuelTheme.body(10, color: const Color(0xFF4A5480), ls: 4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    p.color = DuelTheme.gold.withValues(alpha: .22);
    final r1 = size.shortestSide / 2;
    const dash = 12.0;
    const gap = 9.0;
    final circ = 2 * 3.14159265 * r1;
    var a = 0.0;
    while (a < circ) {
      final a2 = (a + dash).clamp(0.0, circ);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r1), a / r1, (a2 - a) / r1, false, p);
      a = a2 + gap;
    }
    p.color = DuelTheme.cyan.withValues(alpha: .14);
    canvas.drawCircle(c, r1 - 60, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ModeCard extends StatefulWidget {
  final String glyph;
  final String title;
  final String en;
  final String desc;
  final bool gold;
  final VoidCallback onTap;

  const _ModeCard({
    required this.glyph,
    required this.title,
    required this.en,
    required this.desc,
    required this.gold,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.gold ? DuelTheme.gold : DuelTheme.cyan;
    final hi = widget.gold ? DuelTheme.goldHi : const Color(0xFFAEF0FF);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 250,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          transform: Matrix4.translationValues(0.0, _hover ? -6.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF5121632), Color(0xF5080A1A)],
            ),
            border: Border.all(color: accent.withValues(alpha: _hover ? 1 : .55)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 40, offset: const Offset(0, 18)),
              BoxShadow(color: accent.withValues(alpha: _hover ? .3 : .14), blurRadius: _hover ? 44 : 30),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.glyph,
                  style: TextStyle(
                      fontSize: 30, color: hi, shadows: [Shadow(color: accent.withValues(alpha: .9), blurRadius: 16)])),
              const SizedBox(height: 10),
              Text(widget.title,
                  style: DuelTheme.body(21, color: const Color(0xFFF2F5FF), w: FontWeight.w900, ls: 4)),
              const SizedBox(height: 4),
              Text(widget.en, style: DuelTheme.tech(9, color: accent, ls: 4)),
              const SizedBox(height: 10),
              Text(widget.desc,
                  style: DuelTheme.body(11, color: DuelTheme.textDim, w: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
