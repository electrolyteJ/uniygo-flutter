import 'package:flutter/material.dart';

import 'models/duel_intro_timeline.dart';
import 'models/duel_intro_audio.dart';
import 'widgets/intro_painters.dart';
import 'widgets/intro_phases.dart';
import '../theme/cyber_intro_tokens.dart';

/// 决斗场地**载入页**：等候页 → **[本页]** → 决斗场地页。
///
/// 设计稿：`07 对战-载入`（预加载 + 入场动画 2700ms · 全程可跳过）。
///
/// 本页是房间进入对局后的第一屏，职责单一：**播入场演出**
/// （tunnel → field → vs），播完回调 [onFinished] 交出画面。
///
/// ## 版式：一份常驻框架 + 中间幻灯片
///
/// 设计稿的四个画板是**同一页的四个时刻**，所以只有一条进度条。落地时
/// 照这个结构拆成两层：
///
/// ```text
/// ┌─────────────────────────────────────────────┐
/// │ 01 入场开场 · ...            PHASE 01 / 03  │ ← 常驻框架（随相位换字）
/// │                                             │
/// │         [ 相位画面：隧道 / 场地线框 / VS ]   │ ← 幻灯片（整块换掉）
/// │                                             │
/// │ 正在载入 · 场地数据                   064 % │ ← 常驻框架（同一条进度条）
/// │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
/// │                  FPS 采样 60 · VSYNC ON ... │
/// └─────────────────────────────────────────────┘
/// ```
///
/// 进度条**只有一份**，挂在页面层级，由同一条 [AnimationController]
/// 连续推进（0 → 64 → 92 → 99）。相位切换只换中间那块内容，进度条从不
/// 重建、不会闪、更不会回退。
///
/// ## 为什么本页不持有 3D
///
/// 曾经为了让 3D 提前准备好，这里挂过一份 `revealed: false` 的场地页当
/// 预加载载体，但那样一来 3D 实例就必须跨页传递（flame 的 `_gameRenderBox`
/// 是单值，同一 `Game` 不能被两个 `GameWidget` 同时持有），而 [TabBarView]
/// 底层是 [PageView]、**不保活**，离开的页会被销毁——两个约束叠在一起，
/// 交接链路极其脆弱。
///
/// 现在 3D 完全属于第 ③ 页，页面之间不共享实例；第 ③ 页建场景的那一下
/// 开销由本页余下的演出遮住，玩家感知不到。
///
/// 业界术语：**Seamless Loading Screen**（无缝加载画面）——用一段过场
/// 演出盖住下一屏的就绪过程，而不是一块转圈占位。
class DuelFieldLoadingPage extends StatefulWidget {
  const DuelFieldLoadingPage({
    super.key,
    required this.data,
    required this.onFinished,
    this.autoPlay = true,
    this.skippable = true,
    this.bgm,
  });

  /// 双方席位数据（名字 / 先攻 / 观战）。
  final DuelIntroSceneData data;

  /// 入场演出播完（或被跳过）回调，只会触发一次。
  final VoidCallback onFinished;

  /// 是否自动播放（测试里可关掉，手动 pump 驱动）。
  final bool autoPlay;

  /// 是否允许点击 / 返回键跳过。
  ///
  /// 默认 **true**：设计稿明确要求「全程可跳过」。本页只播演出、不等 3D，
  /// 跳过不会撞见未就绪的场地。
  final bool skippable;

  /// 加载页背景音乐控制器。
  ///
  /// 由宿主持有（房间页）而非本页自建：本页会被 `_introDone` 换成一棵
  /// 空子树，音乐却要跨到场地页去，生命周期比本页长。
  ///
  /// 为 null 时完全不播（测试与静音场景）。
  final DuelIntroAudio? bgm;

  @override
  State<DuelFieldLoadingPage> createState() => _DuelFieldLoadingPageState();
}

class _DuelFieldLoadingPageState extends State<DuelFieldLoadingPage>
    with TickerProviderStateMixin {
  /// 载入页只有这一条时间轴：进度条与相位画面共用它，演完即交接。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: DuelIntroTimeline.totalMs),
  );

  /// 相位交叉淡入（换「幻灯片」时那一下柔和过渡）。
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: DuelIntroTimeline.phaseFade,
  );

  /// 当前相位。由 controller listener 推进，只在跨相位时 setState 一次，
  /// 不参与逐帧重建。
  DuelIntroPhase _phase = DuelIntroTimeline.spans.first.phase;

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _fade.value = 1;
    _controller
      ..addListener(_syncPhase)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    // 氛围曲从本页出现就开始：预先载入 3D 场地那几秒在无声状态下会
    // 显得格外长。
    widget.bgm?.startAmbient();
    if (widget.autoPlay) _controller.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    // 注意：**不**在这里停 BGM。本页会在 `_introDone` 时被换成一棵
    // 空子树，入场曲此时通常还在播；停音乐的职责归房间页的
    // DuelIntroAudio（跨页生命周期）。
    super.dispose();
  }

  /// 跨相位时换幻灯片并重放淡入。progressRangeOf 区间首尾相接，
  /// 换相位的瞬间进度条数值是连续的（64 → 64 → 92 → 92 → 99）。
  void _syncPhase() {
    final phase = DuelIntroTimeline.phaseAt(_elapsedMs);
    if (phase == _phase) return;
    setState(() => _phase = phase);
    _fade
      ..reset()
      ..forward();
    // 切到 vs 相位（双方对峙）时起入场曲：此刻画面最有张力，音乐也
    // 该到顶。早于此播会和隧道的画面抢注意力。
    if (phase == DuelIntroPhase.vs) widget.bgm?.playEnter();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // 音效先收尾：演出结束（含跳过）后不该再有「氛围音乐」压在对局上。
    widget.bgm?.finish();
    widget.onFinished();
  }

  /// 立即跳过剩余演出（仅 [DuelFieldLoadingPage.skippable] 时生效）。
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
      child: ColoredBox(
        color: CyberIntroTokens.bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ① 常驻框架：进度条 + 读数，整页只画一份。
            Positioned.fill(child: _fixedChrome()),

            // ② 幻灯片：只换中间这块内容，其余不动。
            Positioned.fill(child: _slide()),

            // ③ 跳过提示（仅在允许跳过时出现）。
            if (widget.skippable)
              Positioned(
                right: 28,
                bottom: 14,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = DuelIntroTimeline.spanOf(
                      _phase,
                    ).progressAt(_elapsedMs);
                    return Opacity(
                      opacity: progressBetween(t, 0.2, 0.6) * 0.55,
                      child: const MonoLabel(
                        '点击任意位置跳过  ›',
                        fontSize: 10,
                        color: CyberIntroTokens.textDim,
                        letterSpacing: 1.8,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
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

  /// 页面级常驻框架：图注 + 相位角标 + 进度条 + 运行读数。
  ///
  /// 用 [AnimatedBuilder] 逐帧重绘，但 `_phase` 本身只在 [State] 里存一份
  /// ——相位切换时这些元素**不重建**，只是文案变化。
  Widget _fixedChrome() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = _elapsedMs;
        final phase = _phase;
        final span = DuelIntroTimeline.spanOf(phase);
        final t = span.progressAt(elapsed);
        final (from, to) = progressRangeOf(phase);
        final progress = from + (to - from) * t;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 左上图注。
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 33),
              child: Align(
                alignment: Alignment.topLeft,
                child: IntroCaption(captionOf(phase)),
              ),
            ),
            // 右上角标。
            Padding(
              padding: const EdgeInsets.only(right: 40, top: 33),
              child: Align(
                alignment: Alignment.topRight,
                child: MonoLabel(
                  'PHASE ${_ordinalOf(phase)} / $_totalOrdinal',
                  fontSize: 11,
                  color: CyberIntroTokens.rule,
                  letterSpacing: 2,
                ),
              ),
            ),
            // 底部：唯一一条进度条。全程青色，不随相位换色
            // （设计稿四帧一致：槽 #16263A / 填充 #37E2FF）。
            Positioned(
              left: 40,
              right: 40,
              bottom: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntroProgressBar(
                    progress: progress,
                    label: statusLabelOf(phase),
                    percentText:
                        '${(progress * 100).round().toString().padLeft(3, '0')} %',
                    color: CyberIntroTokens.cyan,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MonoLabel(
                      'FPS 采样 60  ·  VSYNC ON  ·  GPU 已上传 214 MB',
                      fontSize: 9,
                      color: CyberIntroTokens.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 幻灯片内容：一条 controller 驱动，换相位时整块交叉淡入。
  Widget _slide() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final span = DuelIntroTimeline.spanOf(_phase);
        final t = span.progressAt(_elapsedMs);
        return FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: buildIntroPhase(phase: _phase, t: t, data: widget.data),
        );
      },
    );
  }

  static String _ordinalOf(DuelIntroPhase phase) =>
      DuelIntroTimeline.ordinalOf(phase).toString().padLeft(2, '0');

  static final String _totalOrdinal = DuelIntroPhase.values.length
      .toString()
      .padLeft(2, '0');
}
