import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';

class LpPlate extends StatefulWidget {
  final DuelState state;
  final Side side;

  const LpPlate({super.key, required this.state, required this.side});

  @override
  State<LpPlate> createState() => _LpPlateState();
}

class _LpPlateState extends State<LpPlate> with SingleTickerProviderStateMixin {
  late final AnimationController _hurt;
  int _prevLp = 8000;

  @override
  void initState() {
    super.initState();
    _hurt = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _register();
  }

  void _register() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        widget.state.fx.registerAnchor(
            'plate_${widget.side.name}', box.localToGlobal(box.size.center(Offset.zero)));
      }
    });
  }

  @override
  void dispose() {
    _hurt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _register();
    final st = widget.state.side(widget.side);
    final lp = st.lp;
    if (lp < _prevLp) {
      _hurt.forward(from: 0);
    }
    _prevLp = lp;
    final isOwn = widget.side == Side.own;
    final trim = isOwn
        ? const LinearGradient(colors: [DuelTheme.goldHi, DuelTheme.goldDim, DuelTheme.gold])
        : const LinearGradient(colors: [Color(0xFFFF7BA0), Color(0xFF8A1F3A), DuelTheme.crimson]);
    final ratio = (lp / 8000).clamp(0.0, 1.0);

    return ClipPath(
      clipper: _PlateClip(),
      child: Container(
        decoration: BoxDecoration(gradient: trim),
        padding: const EdgeInsets.all(1.2),
        child: ClipPath(
          clipper: _PlateClip(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 8, 26, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF70F122A), Color(0xF7070918)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.state.nameOf(widget.side),
                        style: DuelTheme.body(13,
                            color: isOwn ? DuelTheme.goldHi : const Color(0xFFFF8FAE),
                            w: FontWeight.w700,
                            ls: 2)),
                    const SizedBox(width: 10),
                    Text(isOwn ? 'STAR DUELIST' : 'ABYSS WALKER',
                        style: DuelTheme.tech(8, color: DuelTheme.textDim, ls: 2.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LP', style: DuelTheme.tech(10, color: DuelTheme.textDim, ls: 3)),
                    const SizedBox(width: 12),
                    AnimatedBuilder(
                      animation: _hurt,
                      builder: (context, child) => Transform.scale(
                        scale: 1 + .25 * _hurt.value * (1 - _hurt.value) * 4,
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(begin: _prevLp == lp ? lp : _prevLp, end: lp),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, value, _) => Text('$value',
                            style: DuelTheme.tech(30,
                                color: isOwn ? DuelTheme.goldHi : const Color(0xFFFFDFE8),
                                w: FontWeight.w800)
                                .copyWith(shadows: [
                              Shadow(
                                  color: (isOwn ? DuelTheme.gold : DuelTheme.crimson)
                                      .withValues(alpha: .6),
                                  blurRadius: 14),
                            ])),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 240,
                  child: ClipPath(
                    clipper: _BarClip(),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.white.withValues(alpha: .08)),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: isOwn
                                    ? const LinearGradient(
                                        colors: [Color(0xFFB98A2E), DuelTheme.gold, DuelTheme.goldHi])
                                    : const LinearGradient(
                                        colors: [Color(0xFF8A1F3A), DuelTheme.crimson, Color(0xFFFF8FAE)]),
                                boxShadow: [
                                  BoxShadow(
                                      color: (isOwn ? DuelTheme.gold : DuelTheme.crimson)
                                          .withValues(alpha: .8),
                                      blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _meta('卡组', st.deck.length),
                      const SizedBox(width: 16),
                      _meta('墓地', st.grave.length),
                      const SizedBox(width: 16),
                      _meta('手牌', st.hand.length),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(String label, int v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: DuelTheme.body(10, color: DuelTheme.textDim, ls: 2)),
          const SizedBox(width: 5),
          Text('$v', style: DuelTheme.tech(11, color: DuelTheme.text)),
        ],
      );
}

class _PlateClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const c = 14.0;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _BarClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const c = 3.0;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - c, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
