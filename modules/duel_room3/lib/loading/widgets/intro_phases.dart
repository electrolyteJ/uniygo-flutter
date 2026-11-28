import 'package:flutter/material.dart';

import '../models/duel_intro_timeline.dart';
import 'intro_painters.dart';
import '../../theme/cyber_intro_tokens.dart';

/// 载入页的双方席位数据：名字 + 先后攻 + 观战视角。
@immutable
class DuelIntroSceneData {
  const DuelIntroSceneData({
    required this.myName,
    required this.opponentName,
    required this.iGoFirst,
    this.isSpectator = false,
  });

  /// 两个决斗方的名字。**注意**：观战者视角下它们仍是引擎玩家
  /// `myController` / `1 - myController` 的名字，不是「观战者自己 / 他的对手」，
  /// 兜底名因此不能写「观战者」或「对手」（见房间页装配入场数据处）。
  final String myName;
  final String opponentName;

  /// `myName` 这一方是否先攻（[RoomInDuel.isFirstTurn]）。
  /// 观战者没有立场，这个值只是「引擎玩家 myController 是否先攻」的
  /// 座位对齐结果——但因为两个方名也按同一套 myController 解析，
  /// 用它把方名与「先攻 / 后攻」配对仍然是**自洽**的。
  final bool iGoFirst;

  /// 观战者视角：席位标识不能写「YOU / RIVAL」。
  final bool isSpectator;

  /// 左侧席位标识。旧实现硬编码 `YOU ▸ SEAT A`，观战者会把引擎玩家
  /// 1 误读成自己；观战时退化为纯席位号。
  String get leftSeatTag => isSpectator ? 'SEAT A' : 'YOU  ▸  SEAT A';

  /// 右侧席位标识。同理，观战时不写 `RIVAL`。
  String get rightSeatTag => isSpectator ? 'SEAT B' : 'SEAT B  ◂  RIVAL';
}

/// 01 冲入隧道（0–900ms）。
///
/// 速度线隧道 + 中心光晕 + LINK 三层错位大字 + 传输读数。
///
/// ⚠️ 只画**画面中部的幻灯片内容**：进度条、相位角标、图注这些
/// 页面级常驻元素由 [DuelFieldLoadingPage] 统一绘制，相位之间不各画一份
/// （否则跨相位切换时它会跟着重画、跳动）。
class PhaseTunnel extends StatelessWidget {
  const PhaseTunnel({super.key, required this.t});

  /// 相位内归一化进度 [0, 1]。
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
                  const MonoLabel(
                    '正在接入决斗场地',
                    fontSize: 12,
                    color: CyberIntroTokens.textSecondary,
                    letterSpacing: 3,
                  ),
                  const SizedBox(height: 24),
                  const MonoLabel(
                    'ARENA STREAM  1024 KB/s   //   ZONE 07',
                    fontSize: 11,
                    color: CyberIntroTokens.textMuted,
                    letterSpacing: 2.2,
                  ),
                ],
              ),
            ),
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
              child: Container(height: 1, color: CyberIntroTokens.acid),
            ),
          ),
        ),
    ];
  }
}

/// 02 场地成形（900–1900ms）。
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
                  color: CyberIntroTokens.textSecondary,
                  letterSpacing: 2,
                ),
              ],
            ),
          ),
        ),

        // 左侧席位标识（观战时不写 YOU）。
        Align(
          alignment: const Alignment(-0.78, 0.30),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.45, 0.8)),
            child: MonoLabel(
              data.leftSeatTag,
              fontSize: 14,
              color: CyberIntroTokens.cyan,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // 右侧席位标识（观战时不写 RIVAL）。
        Align(
          alignment: const Alignment(0.78, -0.02),
          child: Opacity(
            opacity: easeOutCubic(progressBetween(t, 0.55, 0.9)),
            child: MonoLabel(
              data.rightSeatTag,
              fontSize: 14,
              color: CyberIntroTokens.magenta,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
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
                      CyberIntroTokens.cyan.withValues(alpha: 0.16),
                      CyberIntroTokens.cyan.withValues(alpha: 0),
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
                      CyberIntroTokens.magenta.withValues(alpha: 0.16),
                      CyberIntroTokens.magenta.withValues(alpha: 0),
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
                  color: CyberIntroTokens.acid,
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
                    color: CyberIntroTokens.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  const MonoLabel(
                    'DUEL START',
                    fontSize: 16,
                    color: CyberIntroTokens.acid,
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
                    color: CyberIntroTokens.textSecondary,
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
              color: CyberIntroTokens.cyan,
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
              color: CyberIntroTokens.magenta,
              alignEnd: true,
            ),
          ),
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
            color: CyberIntroTokens.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: CyberIntroTokens.uiFamily,
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

/// 按相位分发到具体画面（只返回「幻灯片内容」那一层）。
///
/// 页面级常驻元素（进度条 / 角标 / 图注）不在这里，见
/// [DuelFieldLoadingPage] 的 `_fixedChrome`。
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

/// 右侧「进度区间 + 百分比」换算表。
///
/// 区间首尾相接，保证跨相位切换时进度不跳回：0 → 64 → 92 → 99。
/// 页面级进度条只在切相位时读一次（见 `_DuelFieldLoadingPageState`），
/// 相位内部由同一条 controller 连续推进，所以这里只是分段线性映射。
(double, double) progressRangeOf(DuelIntroPhase phase) => switch (phase) {
  DuelIntroPhase.tunnel => (0, 0.64),
  DuelIntroPhase.field => (0.64, 0.92),
  DuelIntroPhase.vs => (0.92, 0.99),
};

/// 各相位的状态文案（进度条左侧那行）。
String statusLabelOf(DuelIntroPhase phase) => switch (phase) {
  DuelIntroPhase.tunnel => '正在载入  ·  场地数据',
  DuelIntroPhase.field => '正在载入  ·  场地成形',
  DuelIntroPhase.vs => '正在载入  ·  引擎预热',
};

/// 各相位的图注（左上角）。
String captionOf(DuelIntroPhase phase) => switch (phase) {
  DuelIntroPhase.tunnel => '01  入场开场 · 视角被拉入隧道的瞬间，场地数据流开始传输',
  DuelIntroPhase.field => '02  场地线框自中点向四周描边 · 双方区域点亮',
  DuelIntroPhase.vs => '03  VS 落字 · 冲击波扩散 · 黑幕下拉交接决斗页',
};
