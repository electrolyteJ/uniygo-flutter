import 'package:duelink/duelink.dart' show DuelPhase;
import 'package:flutter/widgets.dart';

import '../../util/duel_field_layout.dart';
import '../player_status/player_status_layout.dart';

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

  /// 紧凑 HUD 模式（小屏）下轨道在屏幕上的固定缩放比：
  /// 不随场地相机 zoom 缩放，保证阶段胶囊/按钮可读可点。
  static const compactScreenScale = 0.85;

  /// Compact 模式按钮的屏幕命中边长，视觉尺寸保持不变。
  static const compactHitExtent = 44.0;

  static double hitScreenScale({
    required double cameraZoom,
    required bool compact,
  }) => compact ? compactScreenScale : cameraZoom;

  static Rect hitRectForVisual(Rect visualRect, {double screenScale = 1}) {
    final scale = screenScale.isFinite && screenScale > 0 ? screenScale : 1.0;
    final minimum = compactHitExtent / scale;
    final width = visualRect.width < minimum ? minimum : visualRect.width;
    final height = visualRect.height < minimum ? minimum : visualRect.height;
    return Rect.fromLTWH(
      visualRect.left,
      visualRect.center.dy - height / 2,
      width,
      height,
    );
  }

  /// 轨道总高（含首尾胶囊）。
  static double get height =>
      phases.length * pillHeight + (phases.length - 1) * pillSpacing; // 150

  /// 第 [index] 个胶囊中心的 y 坐标（整体以 centerY 居中）。
  static double pillCenterY(int index) =>
      (index - (phases.length - 1) / 2) * (pillHeight + pillSpacing);

  /// 轨道右沿（相机内容宽度需覆盖到它）。
  static double get rightEdge => centerX + pillWidth / 2; // 344

  // ── 回合徽章（轨道顶部，DP 胶囊上方）──
  /// 徽章尺寸：比胶囊宽以容纳「T12 · 对方」级别的文案。
  static const turnBadgeWidth = 64.0;
  static const turnBadgeHeight = 22.0;

  /// 徽章与首位胶囊（DP）的纵向间距。
  static const turnBadgeGap = 8.0;

  /// 徽章中心 y（胶囊区以 centerY 居中，徽章挂在其上方）。
  static double get turnBadgeCenterY =>
      -(height / 2 + turnBadgeGap + turnBadgeHeight / 2); // -(75+8+11) = -94

  /// 徽章上沿（组件尺寸/底板覆盖范围用）。
  static double get turnBadgeTop => turnBadgeCenterY - turnBadgeHeight / 2;

  // ── 投降按钮（回合徽章上方，轨道最顶端）──
  // 位置语义：轨道上唯一的点击区是底部的 ≡ 菜单按钮；投降是危险操作，
  // 放在离 ≡ 最远的轨道顶端，避免误触。
  /// 按钮尺寸：与胶囊同宽，容纳「投降」二字。
  static const surrenderButtonWidth = pillWidth;
  static const surrenderButtonHeight = 22.0;

  /// 投降按钮与回合徽章的纵向间距。
  static const surrenderButtonGap = 8.0;

  /// 投降按钮中心 y（胶囊区以 centerY 居中，徽章挂其上方，
  /// 投降按钮再挂徽章上方）。
  static double get surrenderButtonCenterY =>
      turnBadgeTop - surrenderButtonGap - surrenderButtonHeight / 2;

  /// 投降按钮上沿（组件尺寸/底板覆盖范围用）。
  static double get surrenderButtonTop =>
      surrenderButtonCenterY - surrenderButtonHeight / 2;

  /// 含投降按钮、回合徽章与末端按钮的轨道总高（组件尺寸用）。
  static double get heightWithSurrenderBadgeAndButton =>
      surrenderButtonHeight + surrenderButtonGap + heightWithBadgeAndButton;

  // ── 阶段操作菜单按钮（EP 胶囊下方）──
  /// 按钮尺寸：与胶囊同宽，略高以容纳图标与呼吸辉光。
  static const actionButtonWidth = pillWidth;
  static const actionButtonHeight = 22.0;

  /// 按钮与末位胶囊（EP）的纵向间距。
  static const actionButtonGap = 8.0;

  /// 按钮中心 y（胶囊区以 centerY 居中，按钮挂在其下方）。
  static double get actionButtonCenterY =>
      height / 2 + actionButtonGap + actionButtonHeight / 2; // 75+8+11 = 94

  /// 含按钮的轨道总高（菜单锚点用）。
  static double get heightWithButton =>
      height + actionButtonGap + actionButtonHeight; // 180

  /// 含顶部回合徽章与末端按钮的轨道总高（组件尺寸用）。
  static double get heightWithBadgeAndButton =>
      turnBadgeHeight + turnBadgeGap + heightWithButton; // 22+8+180 = 210

  /// 顶部附件（徽章块 + 投降块）与底部附件（按钮块）引入的组件中心
  /// 净下移量：胶囊区保持以 centerY 居中。
  /// 上方 30+30=60，下方 30，净上移 15（负值）。
  static double get actionButtonShift =>
      ((actionButtonGap + actionButtonHeight) -
          (turnBadgeGap +
              turnBadgeHeight +
              surrenderButtonGap +
              surrenderButtonHeight)) /
      2; // -15

  /// 轨道左/右端外沿取大者：右为轨道右沿，左为左侧玩家状态卡外沿
  /// （几何见 player_status_layout.dart）。
  static double get contentHalfExtent {
    final leftCardEdge = -PlayerStatusLayout.leftEdge; // 388
    return rightEdge > leftCardEdge ? rightEdge : leftCardEdge;
  }

  /// 包含轨道与左侧状态卡的棋盘内容宽度（供 DuelFlameGame 相机自适配
  /// 引用）。横屏高度受限场景 zoom 不变，左右附件免费入镜；
  /// 窄屏（宽受限）才轻微缩出。
  static final boardContentWidth = 2 * (contentHalfExtent + 8); // 792
}
