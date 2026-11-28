import 'package:flutter/material.dart';

/// 决斗载入页的相位定义与时间轴。
///
/// 对应 Ardot 设计稿「07 对战-载入」页（415:1）的 01–04 画板，也是
/// 「DUEL LOADING SCREEN FLOW」规范里写死的那条时间轴：
///
/// ```text
/// 01 tunnel   0ms    ──── 900ms    冲入隧道 / 速度线 + LINK 大字
/// 02 field    900ms  ── 1900ms    场地成形 / 线框自中点描边 + DUEL FIELD
/// 03 vs       1900ms ─ 2700ms    开场握手 / VS 落字 + 冲击波扩散
/// ```
///
/// 设计稿原话：「页面 07 对战-载入 · 预加载 + 入场动画 **2700ms** ·
/// 全程可跳过 · 先后攻与抽卡已移交对局页」。
///
/// 所以这里**没有 confirm 相位**（旧版那张点击先攻的匹配盘已经删掉），
/// 也**没有 handoff 兜底相位**（载入页不再等 3D——3D 归场地页自己）。
/// 三个阶段播完即 `onFinished`，由房间页切到场地页。
///
/// 时间轴本身是纯数据（[DuelIntroTimeline.phaseAt]），
/// 由 [DuelFieldLoadingPage] 的状态机驱动，便于单测覆盖相位边界。
enum DuelIntroPhase {
  /// 01 入场开场 · 视角被拉入隧道的瞬间，场地数据流开始传输。
  tunnel,

  /// 02 场地线框自中点向四周描边 · 双方区域点亮。
  field,

  /// 03 VS 落字 · 冲击波扩散 · 黑幕下拉交接决斗页。
  vs,
}

/// 一个相位的时间窗口（绝对毫秒）。
@immutable
class DuelIntroSpan {
  const DuelIntroSpan(this.phase, this.startMs, this.endMs);

  final DuelIntroPhase phase;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  /// 该相位内的归一化进度 [0, 1]。
  double progressAt(int elapsedMs) {
    if (durationMs <= 0) return 1;
    return ((elapsedMs - startMs) / durationMs).clamp(0.0, 1.0);
  }

  bool contains(int elapsedMs) => elapsedMs >= startMs && elapsedMs < endMs;
}

/// 入场动画时间轴：相位窗口 + 全局时长。
///
/// **调速只看 [speed]**：所有相位窗口都是「设计稿基准毫秒 × speed」算出来的，
/// 想整体变快 / 变慢只改这一个数，相位比例与相对节奏不会跑偏。
abstract final class DuelIntroTimeline {
  /// 全局速度倍率。`1.0` = 设计稿原始节奏，越大越慢。
  ///
  /// 设 1.35：玩家反馈设计稿的 2700ms 偏赶，三个画面各自还没看清就切走了。
  static const double speed = 1.35;

  /// 按 [speed] 换算基准毫秒。
  static int _ms(int baseMs) => (baseMs * speed).round();

  /// 全部相位窗口。基准：0-900 / 900-1900 / 1900-2700。
  static final List<DuelIntroSpan> spans = [
    DuelIntroSpan(DuelIntroPhase.tunnel, 0, _ms(900)),
    DuelIntroSpan(DuelIntroPhase.field, _ms(900), _ms(1900)),
    DuelIntroSpan(DuelIntroPhase.vs, _ms(1900), _ms(2700)),
  ];

  /// 演出总时长。设计稿基准 2700ms，乘 [speed] 后约 3645ms。
  ///
  /// 载入页只有这一条时间轴：演完即交接，不存在「动画演完还要等 3D」
  /// 的第二段（3D 由第 ③ 页自己装配）。
  static int get totalMs => spans.last.endMs;

  /// 相位序号（1 起，用于「PHASE 01 / 03」角标）。
  static int ordinalOf(DuelIntroPhase phase) =>
      DuelIntroPhase.values.indexOf(phase) + 1;

  /// 解析某一时刻的相位。超出末尾归入最后一个相位。
  static DuelIntroPhase phaseAt(int elapsedMs) {
    for (final span in spans) {
      if (span.contains(elapsedMs)) return span.phase;
    }
    return elapsedMs < 0 ? DuelIntroPhase.tunnel : DuelIntroPhase.vs;
  }

  /// 解析某一时刻的相位窗口。
  static DuelIntroSpan spanOf(DuelIntroPhase phase) =>
      spans.firstWhere((s) => s.phase == phase);

  /// 某相位的起始毫秒（用于「从该相位开始播」的场景）。
  static int startMsOf(DuelIntroPhase phase) => spanOf(phase).startMs;

  /// 是否已播完（可交接给场地页）。
  static bool isDone(int elapsedMs) => elapsedMs >= totalMs;

  /// 相位画面切换的交叉淡入时长。
  ///
  /// 跟随 [speed]（基准 220ms × 1.35 ≈ 297ms）：放慢时淡入若还保持原速，
  /// 相位切换会显得生硬。
  ///
  /// 放在这里而不是 `theme/`：它依赖 [speed]，本质是时间轴的一部分。
  /// 留在 token 里会逼着 theme 反过来 import loading。
  static final Duration phaseFade = Duration(milliseconds: _ms(220));
}
