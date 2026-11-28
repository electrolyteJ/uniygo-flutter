import 'package:flutter/material.dart';

import 'duel_intro_timeline.dart';
import 'intro_painters.dart';
import 'intro_tokens.dart';

/// 相位画面的公共入参：双方名字 + 先后攻 + 当前相位进度。
@immutable
class DuelIntroSceneData {
  const DuelIntroSceneData({
    required this.myName,
    required this.opponentName,
    required this.iGoFirst,
    this.isSpectator = false,
  });

  final String myName;
  final String opponentName;

  /// 我方是否先攻（[RoomInDuel.isFirstTurn]）。
  final bool iGoFirst;

  /// 观战者视角：不显示「你」而是「观战中」，先后攻由服务器下发。
  final bool isSpectator;

  String get mySeatLabel => isSpectator ? '观战者' : '你';
}

/// 02 冲入隧道（500–1400ms）。
///
/// 速度线隧道 + 中心光晕 + LINK 三层错位大字 + 传输读数 + 加载条。
class PhaseTunnel extends StatelessWidget {
  const PhaseTunnel({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final enter = easeOutCubic(progressBetween(t, 0, 0.45));
    final linkScale = 0.72 + 0.28 * easeOutCubic(progressBetween(t, 0.05, 0.7));
    final ghost = progressBetween(t, 0.15, 0.55);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 隧道：进度持续流动。
        fillPainter(SpeedTunnelPainter(progress: t)),
        // 中心光晕。
        Center(
          child: Opacity(
            opacity: 0.55 * enter,
            child: const SizedBox(
              width: 620,
              height: 620,
              child: RadialGlow(opacity: 0.5),
            ),
          ),
        ),
        // 竖向速度线（设计稿 402:216-218 的酸绿细线，横向拉伸）。
        ..._acidRules(t),

        // LINK 大字。
        Center(
          child: Transform.scale(
            scale: linkScale,
            child: Opacity(
              opacity: enter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChromaText(
                    'LINK',
                    fontSize: 56,
                    letterSpacing: 10,
                    ghostOpacity: ghost,
                    glow: true,
                  ),
                  const SizedBox(height: 18),
                  MonoLabel(
                    '正在接入决斗场地',
                    fontSize: 12,
                    color: IntroTokens.textSecondary,
                    letterSpacing: 3,
                  ),
                  const SizedBox(height: 24),
                  MonoLabel(
                    'ARENA STREAM  1024 KB/s   //   ZONE 07',
                    fontSize: 11,
                    color: IntroTokens.textMuted,
                    letterSpacing: 2.2,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 底部状态栏（共用组件，进度 0 → 64%）。
        Positioned(
          left: 40,
          right: 40,
          bottom: 44,
          child: IntroStatusBar(
            phase: DuelIntroPhase.tunnel,
            t: t,
            visible: enter,
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 40, top: 33),
          child: Align(
            alignment: Alignment.topLeft,
            child: IntroCaption('01  入场开场 · 视角被拉入隧道的瞬间，场地数据流开始传输'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 40, top: 33),
          child: Align(
            alignment: Alignment.topRight,
            child: IntroPhaseBadge(DuelIntroPhase.tunnel),
          ),
        ),
      ],
    );
  }

  /// 三条横向酸绿细线（设计稿 Group 402:215），随进度横向拉开。
  List<Widget> _acidRules(double t) {
    const specs = [(0.18, 0.62, 0.55), (0.30, 0.47, 0.42), (0.40, 0.40, 0.32)];
    return [
      for (final (top, widthFactor, opacity) in specs)
        Align(
          alignment: Alignment(0, top * 2 - 1),
          child: Opacity(
            opacity: (opacity * easeOutCubic(t)).clamp(0.0, 1.0),
            child: FractionallySizedBox(
              widthFactor:
                  widthFactor *
                  (0.4 + 0.6 * easeOutCubic(progressBetween(t, 0, 0.6))),
              child: Container(height: 1, color: IntroTokens.acid),
            ),
          ),
        ),
    ];
  }
}

/// 03 场地成形（1400–2400ms）。
///
/// 透视场地线框自中点描边生长 + 展开同心环 + DUEL FIELD 大字 + SEAT 标识。
class PhaseField extends StatelessWidget {
  const PhaseField({super.key, required this.t, required this.data});

  final double t;
  final DuelIntroSceneData data;

  @override
  Widget build(BuildContext context) {
    final reveal = easeOutCubic(progressBetween(t, 0.05, 0.62));
    final titleIn = easeOutCubic(progressBetween(t, 0, 0.4));

    return Stack(
      fit: StackFit.expand,
      children: [
        fillPainter(PerspectiveFieldPainter(reveal: reveal, opacity: 0.9)),

        // 展开同心环（贴住场地中心）。
        Align(
          alignment: const Alignment(0, 0.18),
          child: Opacity(
            opacity: (0.5 * reveal).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.55 + 0.45 * reveal,
              child: const SizedBox(
                width: 320,
                height: 320,
                child: RingOutline(opacity: 0.9, strokeWidth: 1.2),
              ),
            ),
          ),
        ),

        // DUEL FIELD 大字。
        Align(
          alignment: const Alignment(0, -0.62),
          child: Opacity(
            opacity: titleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChromaText(
                  'DUEL FIELD',
                  fontSize: 44,
                  letterSpacing: 6,
                  ghostOpacity: progressBetween(t, 0, 0.35),
                  glow: true,
                ),
                const SizedBox(height: 14),
                MonoLabel(
                  '先攻：${data.iGoFirst ? data.myName : data.opponentName}'
                  '   ·   后攻：${data.iGoFirst ? data.opponentName : data.myName}',
                  fontSize: 12,
                  color: IntroTokens.textSecondary,
                  letterSpacing: 2,
                ),
              ],
            ),
          ),
        ),

        // 左侧我方标识。
        Align(
          alignment: const Alignment(-0.78, 0.30),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.45, 0.8)),
            child: const MonoLabel(
              'YOU  ▸  SEAT A',
              fontSize: 14,
              color: IntroTokens.cyan,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // 右侧对手标识。
        Align(
          alignment: const Alignment(0.78, -0.02),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.55, 0.9)),
            child: const MonoLabel(
              'SEAT B  ◂  RIVAL',
              fontSize: 14,
              color: IntroTokens.magenta,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // 底部加载条（酸绿）。
        Positioned(
          left: 40,
          right: 40,
          bottom: 44,
          child: IntroStatusBar(phase: DuelIntroPhase.field, t: t),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 40, top: 33),
          child: Align(
            alignment: Alignment.topLeft,
            child: IntroCaption('02  场地线框自中点向四周描边 · 双方区域点亮'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 40, top: 33),
          child: Align(
            alignment: Alignment.topRight,
            child: IntroPhaseBadge(DuelIntroPhase.field),
          ),
        ),
      ],
    );
  }
}

/// 03 开场握手（1900–2700ms）。
///
/// VS 三层错位大字 + 左右青/品红对峙光 + 冲击波环 + 方名与先后攻。
class PhaseVs extends StatelessWidget {
  const PhaseVs({super.key, required this.t, required this.data});

  final double t;
  final DuelIntroSceneData data;

  @override
  Widget build(BuildContext context) {
    final vsIn = easeOutCubic(progressBetween(t, 0, 0.35));
    // VS 落字：从 1.6 倍砸到 1 倍。
    final vsScale = 1.0 + 0.6 * (1 - vsIn);
    final wave = easeOutCubic(progressBetween(t, 0.1, 0.85));

    return Stack(
      fit: StackFit.expand,
      children: [
        // 左右对峙光：斜切色块。
        Align(
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: (0.55 * vsIn).clamp(0.0, 1.0),
            child: SizedBox(
              width: 460,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      IntroTokens.cyan.withValues(alpha: 0.16),
                      IntroTokens.cyan.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: (0.55 * vsIn).clamp(0.0, 1.0),
            child: SizedBox(
              width: 460,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      IntroTokens.magenta.withValues(alpha: 0.16),
                      IntroTokens.magenta.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 透视场地（已成形，静态）。
        fillPainter(const PerspectiveFieldPainter(reveal: 1, opacity: 0.62)),

        // 冲击波环：两圈由小扩散。
        Align(
          alignment: const Alignment(0, 0.12),
          child: Opacity(
            opacity: (0.5 * (1 - wave)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.3 + 1.5 * wave,
              child: const SizedBox(
                width: 320,
                height: 320,
                child: RingOutline(
                  color: IntroTokens.acid,
                  opacity: 0.9,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ),
        ),

        // VS 大字。
        Align(
          alignment: const Alignment(0, -0.28),
          child: Transform.scale(
            scale: vsScale,
            child: Opacity(
              opacity: vsIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChromaText(
                    'VS',
                    fontSize: 88,
                    letterSpacing: 8,
                    ghostOpacity: vsIn,
                    glow: true,
                    color: IntroTokens.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  const MonoLabel(
                    'DUEL START',
                    fontSize: 16,
                    color: IntroTokens.acid,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  // 设计稿 402:264：VS 下方「决斗开始 · 双方 LP 8000」。
                  // 开局 LP 由服务端随 MSG_START 下发，这里只做演出呈现，
                  // 真实数值以场地页 HUD 为准。
                  const MonoLabel(
                    '决斗开始  ·  双方 LP 8000',
                    fontSize: 11,
                    color: IntroTokens.textSecondary,
                    letterSpacing: 2,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 左右方名 + 先后攻。
        Align(
          alignment: const Alignment(-0.62, -0.16),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.25, 0.7)),
            child: _SideName(
              name: data.myName,
              turn: data.iGoFirst ? '先攻  ·  TURN 01' : 'TURN 01  ·  后攻',
              color: IntroTokens.cyan,
              alignEnd: false,
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.62, -0.16),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.32, 0.78)),
            child: _SideName(
              name: data.opponentName,
              turn: data.iGoFirst ? 'TURN 01  ·  后攻' : '先攻  ·  TURN 01',
              color: IntroTokens.magenta,
              alignEnd: true,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 40, top: 33),
          child: Align(
            alignment: Alignment.topLeft,
            child: IntroCaption('03  VS 落字 · 冲击波扩散 · 黑幕下拉交接决斗页'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 40, top: 33),
          child: Align(
            alignment: Alignment.topRight,
            child: IntroPhaseBadge(DuelIntroPhase.vs),
          ),
        ),

        // 底部状态栏：这一相位走到 99%，紧接着交棒给场地页。
        Positioned(
          left: 40,
          right: 40,
          bottom: 44,
          child: IntroStatusBar(phase: DuelIntroPhase.vs, t: t),
        ),
      ],
    );
  }
}

class _SideName extends StatelessWidget {
  const _SideName({
    required this.name,
    required this.turn,
    required this.color,
    required this.alignEnd,
  });

  final String name;
  final String turn;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: IntroTokens.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: IntroTokens.uiFamily,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        MonoLabel(
          turn,
          fontSize: 12,
          color: color,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

/// 按相位分发到具体画面。
Widget buildIntroPhase({
  required DuelIntroPhase phase,
  required double t,
  required DuelIntroSceneData data,
}) {
  return switch (phase) {
    DuelIntroPhase.tunnel => PhaseTunnel(t: t),
    DuelIntroPhase.field => PhaseField(t: t, data: data),
    DuelIntroPhase.vs => PhaseVs(t: t, data: data),
  };
}

/// 载入页共用底栏：进度条 + 当前状态文案 + 右下角运行读数。
///
/// 设计稿（402:198 / 402:236 / 402:264）三个画板的底部都是同一套结构：
///
/// ```text
/// 正在载入 · 场地数据                       064 %
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// ```
///
/// 数值是**演出驱动的假进度**，不是真实任务进度——设计稿的预加载任务清单
/// 与状态机（517:1 / 517:64）尚未接入，这一段只保证观感连续：
/// 进度只增不减（T4 注：进度条失实时可用末尾缓停，不可倒退）。
class IntroStatusBar extends StatelessWidget {
  const IntroStatusBar({
    super.key,
    required this.phase,
    required this.t,
    this.visible = 1,
  });

  final DuelIntroPhase phase;

  /// 相位内归一化进度 [0, 1]。
  final double t;

  /// 整体透明度（入场淡入用）。
  final double visible;

  /// 各相位的进度区间与状态文案（对齐设计稿三个画板）。
  ///
  /// 区间首尾相接，保证跨相位切换时进度不跳回：64 → 92 → 99。
  (double, double, String, Color) get _stage => switch (phase) {
    DuelIntroPhase.tunnel => (0, 0.64, '正在载入  ·  场地数据', IntroTokens.cyan),
    DuelIntroPhase.field => (0.64, 0.92, '正在载入  ·  场地成形', IntroTokens.cyan),
    DuelIntroPhase.vs => (0.92, 0.99, '正在载入  ·  引擎预热', IntroTokens.acid),
  };

  @override
  Widget build(BuildContext context) {
    final (from, to, label, color) = _stage;
    final progress = from + (to - from) * t;
    return Opacity(
      opacity: visible.clamp(0.0, 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntroProgressBar(
            progress: progress,
            label: label,
            percentText:
                '${(progress * 100).round().toString().padLeft(3, '0')} %',
            color: color,
          ),
          const SizedBox(height: 10),
          // 设计稿右下角的运行读数：纯装饰，营造「引擎在跑」的质感。
          Align(
            alignment: Alignment.centerRight,
            child: MonoLabel(
              'FPS 采样 60  ·  VSYNC ON  ·  GPU 已上传 214 MB',
              fontSize: 9,
              color: IntroTokens.textFaint,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上角相位角标（`PHASE 02 / 03`）。
class IntroPhaseBadge extends StatelessWidget {
  const IntroPhaseBadge(this.phase, {super.key});

  final DuelIntroPhase phase;

  @override
  Widget build(BuildContext context) {
    final n = DuelIntroTimeline.ordinalOf(phase).toString().padLeft(2, '0');
    final total = DuelIntroPhase.values.length.toString().padLeft(2, '0');
    return MonoLabel(
      'PHASE $n / $total',
      fontSize: 11,
      color: IntroTokens.rule,
      letterSpacing: 2,
    );
  }
}
