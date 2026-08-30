import '../../util/duel_field_layout.dart';

/// 左侧玩家状态卡（我方/对方各一张，竖排）的纯布局参数。
///
/// 卡片紧贴场地左侧：右缘距棋盘左缘（colX[0] 左沿）留 [boardGap]，
/// 两张卡分别靠近自家半场中线。组件本体只读这里的常量做绘制与
/// 命中测试，相机内容宽度（PhaseRailLayout.contentHalfExtent）也
/// 引用同一份几何，保证画面与点击区一致。
class PlayerStatusLayout {
  PlayerStatusLayout._();

  /// 卡片尺寸（紧凑细长竖版：头像+名字+LP+五行区域计数）。
  static const cardWidth = 60.0;
  static const cardHeight = 224.0;

  /// 卡片右缘与棋盘左缘（x=-286）的间隙。
  static const boardGap = 10.0;

  /// 卡片中心 x：棋盘左沿外侧。
  static const centerX =
      -(DuelFieldLayout.lastColX +
          DuelFieldLayout.slotWidth / 2 +
          boardGap +
          cardWidth / 2); // -(252+34+10+30) = -326

  /// 两张卡的中心 y：各靠近自家半场（长卡纵向几乎覆盖自家半区，
  /// 中间让出 y=0 的 EMZ/中央计时器一线）。
  static const selfCenterY = 121.0;
  static const oppCenterY = -121.0;

  /// 卡片左缘（相机内容宽度需覆盖到它）。
  static double get leftEdge => centerX - cardWidth / 2; // -356

  // ── 卡内布局（相对卡片左上角的局部坐标）──
  static const padding = 10.0;
  static const avatarRadius = 12.0;

  /// 头像圆心 y（局部）。
  static const avatarCenterY = padding + avatarRadius; // 22

  /// 名字基线中心 y（局部）。
  static const nameCenterY = avatarCenterY + avatarRadius + 6 + 6; // 46

  /// LP 数字中心 y（局部）。
  static const lpCenterY = nameCenterY + 6 + 11; // 63

  /// 计数行（H/D/EX/GY/B）首行中心 y 与行高（局部）。
  static const rowsFirstCenterY = lpCenterY + 11 + 10 + 12; // 96
  static const rowHeight = 24.0;

  /// 计数行标签与顺序（EX/GY/B 可点开区域浏览器）。
  static const rowLabels = ['H', 'D', 'EX', 'GY', 'B'];

  /// 第 [index] 行中心 y（局部）。
  static double rowCenterY(int index) =>
      rowsFirstCenterY + index * rowHeight;
}
