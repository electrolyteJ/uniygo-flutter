import 'package:flutter/material.dart';

import 'duel_intro_timeline.dart';
import 'intro_painters.dart';
import 'intro_phases.dart';
import 'intro_tokens.dart';

/// 决斗场地**载入页**的演出层。
///
/// 层面定位：等候页 → **[本组件]** → 决斗场地页。设计稿里的页类型是
/// **Loading Screen**，只包含两件事：① 预加载 ② 入场动画；
/// 先后攻揭示与抽卡阶段已移出本页（移交对局页）。
///
/// 本组件只负责 ②：用一条 [AnimationController] 驱动 3 个相位
/// （见 [DuelIntroTimeline]，tunnel → field → vs，共 2700ms 基准），
/// 播完通过 [onFinished] 把画面交给场地页。它**不持有、不预热 3D**。
///
/// 设计稿要点：
/// - **全程可跳过**：任意时刻点一下即进对局（[skippable]，默认开）；
/// - **观战者精简**：观战者没有先后攻立场，`field` 相位的先后攻文案
///   换成中性表述，其余相位照常（他们同样需要「正在接入」的感知）。
class DuelIntroOverlay extends StatefulWidget {
  const DuelIntroOverlay({
    super.key,
    required this.data,
    required this.onFinished,
    this.autoPlay = true,
    this.skippable = true,
  });

  final DuelIntroSceneData data;

  /// 演出结束（自然播完或被跳过）时回调，只会触发一次。
  final VoidCallback onFinished;

  /// 是否自动播放（测试里可关掉，手动 pump 驱动）。
  final bool autoPlay;

  /// 是否允许点击 / 返回键跳过。
  ///
  /// 默认 **true**：设计稿明确要求「全程可跳过」（T1 注：`点击任意位置跳过`）。
  /// 载入页只播演出、不等 3D，跳过不会撞见未就绪的场地，
  /// 所以不需要像旧版那样锁住。
  final bool skippable;

  @override
  State<DuelIntroOverlay> createState() => _DuelIntroOverlayState();
}

class _DuelIntroOverlayState extends State<DuelIntroOverlay>
    with SingleTickerProviderStateMixin {
  /// 载入页只有这一条时间轴，演完即交接。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: DuelIntroTimeline.totalMs),
  );

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    if (widget.autoPlay) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  /// 立即跳过剩余演出（仅 [DuelIntroOverlay.skippable] 时生效）。
  void _skip() {
    if (_finished || !widget.skippable) return;
    _controller.value = 1;
    _finish();
  }

  /// 当前绝对毫秒。
  int get _elapsedMs => (_controller.value * DuelIntroTimeline.totalMs).round();

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      behavior: widget.skippable
          ? HitTestBehavior.opaque
          : HitTestBehavior.translucent,
      onTap: widget.skippable ? _skip : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elapsed = _elapsedMs;
          final phase = DuelIntroTimeline.phaseAt(elapsed);
          final span = DuelIntroTimeline.spanOf(phase);
          final t = span.progressAt(elapsed);

          return ColoredBox(
            color: IntroTokens.bg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 相位交叉淡入：新相位从 0 渐显，旧相位直接消失
                // （各相位底色一致，硬切也看不出来）。
                PhaseClip(
                  child: _PhaseTransition(
                    phase: phase,
                    t: t,
                    data: widget.data,
                    elapsedMs: elapsed,
                  ),
                ),
                // 跳过提示（仅在允许跳过时出现）。设计稿放在右下角，
                // 字号 10 / 弱化色，不抢画面。
                if (widget.skippable)
                  Positioned(
                    right: 28,
                    bottom: 14,
                    child: Opacity(
                      opacity: progressBetween(t, 0.2, 0.6) * 0.55,
                      child: const MonoLabel(
                        '点击任意位置跳过  ›',
                        fontSize: 10,
                        color: IntroTokens.textDim,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    if (!widget.skippable) return content;

    return PopScope(
      // 跳过开着时拦截返回键：先跳过动画而不是直接退出房间。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skip();
      },
      child: content,
    );
  }
}

/// 相位交叉淡入包装。
///
/// 每个相位挂载时从 0 淡入到 1（[IntroTokens.phaseFade]），
/// 用 [ValueKey] 保证相位切换时重建。
class _PhaseTransition extends StatefulWidget {
  const _PhaseTransition({
    required this.phase,
    required this.t,
    required this.data,
    required this.elapsedMs,
  });

  final DuelIntroPhase phase;
  final double t;
  final DuelIntroSceneData data;
  final int elapsedMs;

  @override
  State<_PhaseTransition> createState() => _PhaseTransitionState();
}

class _PhaseTransitionState extends State<_PhaseTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IntroTokens.phaseFade,
  )..forward();

  @override
  void didUpdateWidget(_PhaseTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _fade
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: buildIntroPhase(
        phase: widget.phase,
        t: widget.t,
        data: widget.data,
      ),
    );
  }
}
