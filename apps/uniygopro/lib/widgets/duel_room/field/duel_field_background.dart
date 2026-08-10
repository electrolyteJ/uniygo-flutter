import 'package:flutter/material.dart';

/// 决斗场地背景：v10 设计稿的多层渐变光晕 + 压边 vignette，
/// 位于场地与 HUD 之下，纯装饰。
class DuelFieldBackground extends StatelessWidget {
  const DuelFieldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // v10: 底层线性渐变 linear-gradient(180deg, #010308, #06101c, #010308)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF010308),
                  Color(0xFF06101C),
                  Color(0xFF010308),
                ],
              ),
            ),
          ),
        ),
        // v10: 顶部青色光晕 radial-gradient(circle at 50% 18%, rgba(0,240,255,.24), transparent 34%)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.64),
                radius: 0.68,
                colors: [Color(0x3D00F0FF), Colors.transparent],
              ),
            ),
          ),
        ),
        // v10: 底部蓝色光晕 radial-gradient(circle at 50% 82%, rgba(0,140,255,.16), transparent 34%)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.64),
                radius: 0.68,
                colors: [Color(0x29008CFF), Colors.transparent],
              ),
            ),
          ),
        ),
        // v10: 左右两侧青色光晕 rgba(0,240,255,.10)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.72, 0.0),
                radius: 0.6,
                colors: [Color(0x1A00F0FF), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.72, 0.0),
                radius: 0.6,
                colors: [Color(0x1A00F0FF), Colors.transparent],
              ),
            ),
          ),
        ),
        // v10: .vignette —— 位于背景之上、场地与 HUD 之下（z-index 2），纯装饰
        Positioned.fill(child: IgnorePointer(child: PlaymatVignette())),
      ],
    );
  }
}

/// v10 .vignette：上下/左右边缘压暗 + 中心径向收边
class PlaymatVignette extends StatelessWidget {
  const PlaymatVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x75000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0x7A000000),
                ],
                stops: [0.0, 0.16, 0.82, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x6B000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0x6B000000),
                ],
                stops: [0.0, 0.10, 0.90, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [Colors.transparent, Color(0x4D000000)],
                stops: [0.6, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
