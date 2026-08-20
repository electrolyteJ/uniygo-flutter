import 'package:flutter/material.dart' show Offset;

/// 棋盘布局常量（世界/逻辑坐标，原点为棋盘中心）。
///
/// 从 duel_field_world.dart 抽离：布局参数是纯数据，与 Flame 组件树无关，
/// 独立成文件以便槽位规格（zone_slot_spec.dart）与单元测试直接引用，
/// 避免测试链拖入 Flame/cardlive 重依赖。
class DuelFieldLayout {
  DuelFieldLayout._();

  /// 7 列布局的 x 坐标。
  static const colX = [-252.0, -168.0, -84.0, 0.0, 84.0, 168.0, 252.0];

  /// 最右列（colX[6]）的 x 坐标。const 表达式不能索引 const 列表，
  /// 需要参与 const 计算的场景（如阶段轨道布局）用此命名常量。
  static const lastColX = 252.0;
  // 怪兽行 y：EMZ 在 y=0（半高 48，跨越 ±48），怪兽行需 ≥ 96 才不重叠；
  // 取 100 留 4px 间隙（与怪兽-魔陷行间距一致）。
  static const monsterY = 100.0;
  // 魔陷行紧贴怪兽行外侧：中心相距 100，扣除两张卡半高后留约 4px 间隙。
  static const stY = 200.0;
  static const slotWidth = 68.0;
  static const slotHeight = 96.0;

  /// 主卡组槽位棋盘坐标：己方底排最右（colX[6], stY），对方顶排最左。
  ///
  /// 洗牌动效等一次性表现组件从这里取落点，与 zone_slot_spec 的
  /// DECK 槽位保持一致（一致性由 shuffle_slot_test 锁定）。
  static Offset deckSlotPos({required bool isSelf}) =>
      Offset(isSelf ? colX[6] : colX[0], isSelf ? stY : -stY);

  /// 额外卡组槽位棋盘坐标：己方底排最左（colX[0], stY），对方顶排最右。
  static Offset extraSlotPos({required bool isSelf}) =>
      Offset(isSelf ? colX[0] : colX[6], isSelf ? stY : -stY);

  // 阶段指示器的几何已迁移到 phase_rail_layout.dart（右侧垂直阶段轨道）。
}
