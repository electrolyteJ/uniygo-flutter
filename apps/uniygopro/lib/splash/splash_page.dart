/// 01 开屏：品牌字标（uniy / go）+ 卡表与卡图资源校验进度。
///
/// 设计稿：Ardot 744179416852082 页面「01 开屏」（844×390）。
/// 进入后先播一轮渐显与进度动画，随后按登录态自动进入登录页或主页；
/// 任意点击可立即跳过。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/route.dart';
import '../ui/duel_canvas.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

/// 展示用版本号（与设计稿一致；发布构建可改为读 package info）。
const String kSplashBuildTag = 'v1.4.0 · BUILD 2601';
const String kClientVersion = 'v2.4.1 · CN-1';

/// 资源校验的总数（卡表 + 卡图条目数，设计稿给的是 20114）。
const int kResourceTotal = 20114;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _leave(after: const Duration(milliseconds: 320));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave({Duration after = Duration.zero}) async {
    if (_leaving) return;
    _leaving = true;
    if (after > Duration.zero) {
      await Future<void>.delayed(after);
    }
    if (!mounted) return;
    final loggedIn = context.read<MyCardAccountApi>().isLoggedIn;
    context.go(loggedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return DuelStage(
      backdrop: DuelBackdropKind.splash,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final intro = Curves.easeOutCubic.transform(
              (t / 0.32).clamp(0.0, 1.0),
            );
            final progress = Curves.easeInOutCubic.transform(
              ((t - 0.10) / 0.78).clamp(0.0, 1.0),
            );
            final checked = (kResourceTotal * progress).round();

            return Stack(
              children: [
                // ── 页眉 ─────────────────────────────────────────
                Positioned(
                  left: 34,
                  top: 23,
                  child: Text(
                    'OCG 2026.01 · 卡表已同步',
                    style: DuelType.latin(10.5, color: DuelColors.textGhost),
                  ),
                ),
                Positioned(
                  right: 38,
                  top: 23,
                  child: Text(
                    kSplashBuildTag,
                    style: DuelType.latin(10.5, color: DuelColors.textGhost),
                  ),
                ),

                // ── 环线两侧的赛季标注 ───────────────────────────
                Positioned(
                  left: 68,
                  top: 159,
                  child: Text(
                    '第 26 赛季',
                    style: DuelType.sans(10.5, color: DuelColors.textDim),
                  ),
                ),
                Positioned(
                  right: 56,
                  top: 159,
                  child: Text(
                    '混沌交叉',
                    style: DuelType.sans(10.5, color: DuelColors.textDim),
                  ),
                ),

                // ── 品牌字标 ─────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  top: 88 + (1 - intro) * 10,
                  child: Opacity(
                    opacity: intro,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'uniy',
                          style: DuelType.serif(
                            96,
                            height: 1.44,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Text(
                          'go',
                          style: DuelType.serif(
                            96,
                            height: 1.44,
                            letterSpacing: -1.5,
                            color: DuelColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 219,
                  child: Opacity(
                    opacity: intro,
                    child: Center(
                      child: Text(
                        '决斗终端',
                        style: DuelType.serif(
                          17,
                          color: DuelColors.textSecondary,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 249,
                  child: Opacity(
                    opacity: intro,
                    child: Center(
                      child: Text(
                        'REAL-TIME DUEL CLIENT',
                        style: DuelType.latin(
                          9.5,
                          color: DuelColors.textMuted,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 底部资源校验进度 ─────────────────────────────
                Positioned(
                  left: 20,
                  top: 346,
                  width: 770,
                  height: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DuelColors.divider,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: DuelColors.accent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 34,
                  top: 355,
                  child: Text(
                    progress >= 1
                        ? '资源校验完成 · $kResourceTotal / $kResourceTotal'
                        : '正在校验卡表与卡图资源 · $checked / $kResourceTotal',
                    style: DuelType.sans(10.5, color: DuelColors.textMuted),
                  ),
                ),
                Positioned(
                  right: 38,
                  top: 355,
                  child: Text(
                    kClientVersion,
                    style: DuelType.latin(10, color: DuelColors.textMuted),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
