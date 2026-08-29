import 'package:duelink/duelink.dart' show DuelPhase;

import 'duel_field_layout.dart';

/// 阶段轨道（右侧垂直阶段按钮列）的纯布局参数。
///
/// 轨道为 6 个阶段胶囊（DP/SP/M1/BP/M2/EP）纵向排列，居中于棋盘中线
/// （y=0），水平停靠在最右卡槽列（colX[6]）外侧。组件本体只读这里的
/// 常量做绘制，页面/相机的锚点上报也用同一份几何，保证点击区、
/// 菜单锚点与画面三者一致。
class PhaseRailLayout {
  PhaseRailLayout._();

  /// 轨道上的阶段顺序（不含 idle）。
  static const phases = [
    DuelPhase.dp,
    DuelPhase.sp,
    DuelPhase.m1,
    DuelPhase.bp,
    DuelPhase.m2,
    DuelPhase.ep,
  ];

  /// 胶囊内的两字母阶段码。
  static const shortLabels = ['DP', 'SP', 'M1', 'BP', 'M2', 'EP'];

  /// 阶段在轨道上的序号（0 起）；idle 返回 -1（无当前节点，全部暗色）。
  static int orderIndex(DuelPhase phase) => phases.indexOf(phase);

  // ── 几何（世界坐标）──
  /// 单个阶段胶囊尺寸。
  static const pillWidth = 44.0;
  static const pillHeight = 20.0;

  /// 相邻胶囊的纵向间距。
  static const pillSpacing = 6.0;

  /// 轨道中心 x：最右卡槽列（colX[6]）右沿外留 14px 间隙。
  static const centerX =
      DuelFieldLayout.lastColX +
      DuelFieldLayout.slotWidth / 2 +
      14 +
      pillWidth / 2; // 252 + 34 + 14 + 22 = 322

  /// 轨道中心 y：棋盘中线（双方回合中立位）。
  static const centerY = 0.0;

  /// 轨道总高（含首尾胶囊）。
  static double get height =>
      phases.length * pillHeight + (phases.length - 1) * pillSpacing; // 150

  /// 第 [index] 个胶囊中心的 y 坐标（整体以 centerY 居中）。
  static double pillCenterY(int index) =>
      (index - (phases.length - 1) / 2) * (pillHeight + pillSpacing);

  /// 轨道右沿（相机内容宽度需覆盖到它）。
  static double get rightEdge => centerX + pillWidth / 2; // 344

  // ── 阶段操作菜单按钮（EP 胶囊下方）──
  /// 按钮尺寸：与胶囊同宽，略高以容纳图标与呼吸辉光。
  static const actionButtonWidth = pillWidth;
  static const actionButtonHeight = 22.0;

  /// 按钮与末位胶囊（EP）的纵向间距。
  static const actionButtonGap = 8.0;

  /// 按钮中心 y（胶囊区以 centerY 居中，按钮挂在其下方）。
  static double get actionButtonCenterY =>
      height / 2 + actionButtonGap + actionButtonHeight / 2; // 75+8+11 = 94

  /// 含按钮的轨道总高（组件尺寸与菜单锚点用）。
  static double get heightWithButton =>
      height + actionButtonGap + actionButtonHeight; // 180

  /// 按钮引入的组件中心下移量：胶囊区保持以 centerY 居中，
  /// 组件整体（胶囊 + 按钮）的几何中心相对 centerY 下移该值。
  static double get actionButtonShift =>
      (actionButtonGap + actionButtonHeight) / 2; // 15

  /// 包含轨道的棋盘内容宽度（供 DuelFlameGame 相机自适配引用）。
  /// 在旧值 600 基础上加宽到 704：横屏高度受限场景 zoom 不变，
  /// 轨道免费入镜；窄屏（宽受限）才轻微缩出。
  static const boardContentWidth = 704.0; // 2 * (rightEdge + 8)
}
