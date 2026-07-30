import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/duel_state.dart';
import '../theme/md_theme.dart';

class TurnBanner extends StatelessWidget {
  final BannerData? data;

  const TurnBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    return Center(
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0),
        builder: (context, _) => Container(
          key: ValueKey(data!.key),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              MdTheme.bg.withValues(alpha: .95),
              MdTheme.panel.withValues(alpha: .9),
              MdTheme.bg.withValues(alpha: .95),
            ]),
            border: Border(
              top: BorderSide(color: MdTheme.gold.withValues(alpha: .6)),
              bottom: BorderSide(color: MdTheme.gold.withValues(alpha: .6)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data!.cn, style: MdTheme.title(28, color: MdTheme.goldHi, ls: 6)),
              const SizedBox(height: 4),
              Text(data!.en, style: MdTheme.body(11, color: MdTheme.textDim, ls: 4)),
            ],
          ),
        ).animate(key: ValueKey(data!.key)).fadeIn(duration: 300.ms).scaleXY(begin: 1.1, end: 1, duration: 300.ms).then(delay: 1200.ms).fadeOut(duration: 400.ms),
      ),
    );
  }
}
