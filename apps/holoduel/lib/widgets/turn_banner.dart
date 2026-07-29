import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';

class TurnBanner extends StatefulWidget {
  final BannerData? data;

  const TurnBanner({super.key, this.data});

  @override
  State<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<TurnBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int? _shownKey;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void didUpdateWidget(TurnBanner old) {
    super.didUpdateWidget(old);
    if (widget.data?.key != _shownKey && widget.data != null) {
      _shownKey = widget.data!.key;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          double opacity;
          if (t < .12) {
            opacity = t / .12;
          } else if (t > .72) {
            opacity = ((1 - t) / .28).clamp(0.0, 1.0);
          } else {
            opacity = 1;
          }
          final scaleX = t < .12
              ? 0.1 + (t / .12) * 0.96
              : t < .2
                  ? 1.06 - ((t - .12) / .08) * 0.06
                  : 1.0;
          return Opacity(
            opacity: opacity,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.12,
                    child: Transform.scale(
                      scaleX: scaleX,
                      child: Container(
                        width: 900,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            DuelTheme.gold.withValues(alpha: .16),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.07,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scaleX: scaleX,
                          child: Text(
                            d.cn,
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 14,
                              color: DuelTheme.goldHi,
                              shadows: [
                                Shadow(color: Color(0xD9E8B84B), blurRadius: 36),
                                Shadow(color: Color(0xFF6A4A14), blurRadius: 0, offset: Offset(0, 4)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          d.en,
                          style: DuelTheme.tech(13, color: DuelTheme.cyan, w: FontWeight.w800, ls: 10)
                              .copyWith(shadows: [
                            Shadow(color: DuelTheme.cyan.withValues(alpha: .8), blurRadius: 14),
                          ]),
                        ),
                      ],
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
