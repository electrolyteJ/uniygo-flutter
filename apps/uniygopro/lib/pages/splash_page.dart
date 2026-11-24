/// 开屏页：品牌展示 + 启动期过渡，结束后按登录态分流到大厅或登录页。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/route.dart';
import '../layout/app_layout.dart';

/// 开屏停留时长（同时驱动进度条动画）。
const Duration kSplashDuration = Duration(milliseconds: 1200);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // 有限次动画：一次 forward 后即跳转，不使用无限循环，
    // 否则集成测试的 pumpAndSettle 永远等不到静止。
    _controller = AnimationController(vsync: this, duration: kSplashDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goNext();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final loggedIn = context.read<MyCardAccountApi>().isLoggedIn;
    context.go(loggedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final logoWidth = switch (spec.tier) {
      AppLayoutTier.compact => spec.viewport.width * 0.42,
      AppLayoutTier.regular => (spec.viewport.width * 0.34).clamp(240.0, 520.0),
      AppLayoutTier.wide => 560.0,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 0.9,
            colors: [Color(0xFF122236), Color(0xFF05070F)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: logoWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.casino,
                          size: logoWidth * 0.16,
                          color: const Color(0xFFFFD75A),
                        ),
                        SizedBox(width: logoWidth * 0.04),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'uniygo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: logoWidth * 0.18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spec.gutter),
                  Text(
                    '决斗，由此开始',
                    style: TextStyle(
                      color: const Color(0xFF8A93A8),
                      fontSize: spec.tier == AppLayoutTier.compact ? 12 : 14,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: spec.gutter * 1.6),
                  SizedBox(
                    width: logoWidth * 0.8,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 3,
                          backgroundColor: const Color(0xFF1E3A55),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF37E2FF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: spec.pagePadding,
              bottom: spec.pagePadding,
              child: const Row(
                children: [
                  _StatusDot(),
                  SizedBox(width: 8),
                  Text(
                    '初始化中…',
                    style: TextStyle(color: Color(0xFF5C6A85), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF7CFF6B),
        shape: BoxShape.circle,
      ),
    );
  }
}
