import 'package:flutter/material.dart' show Offset, Size;

/// 棋盘布局常量（世界/逻辑坐标，原点为棋盘中心）。
///
/// 从 duel_field_world.dart 抽离：布局参数是纯数据，与 Flame 组件树无关，
/// 独立成文件以便槽位规格（zone_slot_spec.dart）与单元测试直接引用，
/// 避免测试链拖入 Flame/cardlive 重依赖。
class DuelFieldLayout {
  DuelFieldLayout._();

  /// 7 列布局的 x 坐标。
  static const colX = [-252.0, -168.0, -84.0, 0.0, 84.0, 168.0, 252.0];
  // 怪兽行 y：EMZ 在 y=0（半高 48，跨越 ±48），怪兽行需 ≥ 96 才不重叠；
  // 取 100 留 4px 间隙（与怪兽-魔陷行间距一致）。
  static const monsterY = 100.0;
  // 魔陷行紧贴怪兽行外侧：中心相距 100，扣除两张卡半高后留约 4px 间隙。
  static const stY = 200.0;
  static const slotWidth = 68.0;
  static const slotHeight = 96.0;

  /// PhaseLamp 锚点：self_grave（墓地）卡槽（第 7 列 / Monster 行）。
  /// 己方墓地位于 Monster 行 monsterY 的 colX[6] 位置（己方 Monster 行最右）。
  static const phaseLampRefBoardX = 252.0; // colX[6]
  static const phaseLampRefBoardY = monsterY; // 100

  /// PhaseLamp 的尺寸（Flutter 与 Flame 共用）。
  static const phaseLampWidth = 132.0;
  static const phaseLampHeight = 44.0;
  static const phaseLampSize = Size(phaseLampWidth, phaseLampHeight);

  /// PhaseLamp 左下角与锚点卡槽右上角之间的间距（px）。
  /// 同时决定 x 向右、y 向上的偏移，形成对角间隙。需要更松/更紧时调它即可。
  static const phaseLampGap = 8.0;

  /// PhaseLamp 相对锚点卡槽「中心」的偏移：使灯的左下角落在卡槽右上角
  /// 外侧 [phaseLampGap] 像素处（向右 gap、向上 gap）。
  /// 推导：center→center 偏移 = (半宽和 + gap, -(半高和 + gap))。
  /// 在原型(Flutter)/火焰(Flame) 两侧统一引用（project3D 为恒等时世界坐标=像素）。
  static const phaseLampOffset = Offset(
    (slotWidth + phaseLampWidth) / 2 + phaseLampGap, // 34 + 66 + 8 = 108
    -((slotHeight + phaseLampHeight) / 2 +
        phaseLampGap), // -(48 + 22 + 8) = -78
  );

  /// PhaseLamp 未找到锚点时的 fallback（相对视口比例）。
  /// x: 0.88 对应 self_grave（我方墓地，棋盘右区 colX[6]）；
  /// y: 0.53 对应 Monster 行上沿附近，留边缘安全距离。
  static const phaseLampFallbackRatio = Offset(0.88, 0.53);
}
