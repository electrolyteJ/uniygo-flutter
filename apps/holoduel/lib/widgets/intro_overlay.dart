import 'package:flutter/cupertino.dart';

import '../theme/duel_theme.dart';

class IntroOverlay extends StatefulWidget {
  const IntroOverlay({super.key});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final textScale = t < .35 ? 3.2 - (t / .35) * 2.2 : t < .48 ? 1.0 + (.48 - t) / .13 * .08 : 1.0;
          final textOpacity = (t / .35).clamp(0.0, 1.0);
          final ringScale = 2.4 - t * 1.4;
          return Container(
            color: Color.lerp(const Color(0xFF101433), DuelTheme.void_, t.clamp(0.4, 1.0)),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale.clamp(1.0, 2.4),
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: DuelTheme.gold.withValues(alpha: .55), width: 2),
                        boxShadow: [
                          BoxShadow(color: DuelTheme.gold.withValues(alpha: .3), blurRadius: 60),
                        ],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: textOpacity,
                    child: Transform.scale(
                      scale: textScale,
                      child: const Text(
                        '决斗',
                        style: TextStyle(
                          fontSize: 100,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 22,
                          color: DuelTheme.goldHi,
                          shadows: [
                            Shadow(color: Color(0xE6E8B84B), blurRadius: 46),
                            Shadow(color: Color(0xFF6A4A14), offset: Offset(0, 5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 210,
                    child: Opacity(
                      opacity: ((t - .3) / .25).clamp(0.0, 1.0),
                      child: Text('DUEL !',
                          style: DuelTheme.tech(20, color: DuelTheme.cyan, w: FontWeight.w800, ls: 12)
                              .copyWith(shadows: [
                            Shadow(color: DuelTheme.cyan.withValues(alpha: .9), blurRadius: 18),
                          ])),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}