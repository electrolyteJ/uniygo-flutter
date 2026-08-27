/// 3D 决斗场布局数学（纯 Dart，不依赖 flame_3d / GPU，可单测）。
///
/// 世界坐标约定：Y 轴向上，场地在 XZ 平面（y=0 为地砖上表面）；
/// 己方在 +Z（近相机端），对方在 -Z。长度单位：卡宽 = 1.0。
///
/// 槽位语义与 duel_room1 的 buildZoneSlotSpecs 逐项一致（32 槽）：
/// 对方 S/T 行（DECK | S/T×5 逆序 | EXTRA）、对方怪兽行（Grave | M×5 逆序
/// | Field）、EMZ+除外行（对方除外 | EMZ1 | EMZ2 | 己方除外）、
/// 己方怪兽行（Field | M×5 | Grave）、己方 S/T 行（EXTRA | S/T×5 | DECK）。
library;

import 'package:vector_math/vector_math.dart';

/// 卡面表示形式位（与 ocgcore / duelink 的 POS_* 一致，
/// 本地重定义以保持本模块纯 Dart 无 duelink 依赖）。
const int posFaceupAttack = 0x1;
const int posFacedownAttack = 0x2;
const int posFaceupDefense = 0x4;
const int posFacedownDefense = 0x8;
const int posFacedown = 0x2 | 0x8; // duelink POS_FACEDOWN = 攻里|守里 的组合判定

/// 卡区域位（与 ocgcore LOCATION_* 一致）。
const int zoneDeck = 0x01;
const int zoneHand = 0x02;
const int zoneMonster = 0x04;
const int zoneSpellTrap = 0x08;
const int zoneGrave = 0x10;
const int zoneRemoved = 0x20;
const int zoneExtra = 0x40;
const int zoneOverlay = 0x80;

/// 卡槽角色（决定地砖配色/图标与交互行为）。
enum ZoneRole {
  deck,
  extra,
  grave,
  banish,
  fieldSpell,
  monster,
  spellTrap,
  extraMonster,
}

enum FieldSide { self, opponent }

/// 3D 卡槽静态规格：世界坐标 + 槽位 key + 角色。
class ZoneSlot3D {
  const ZoneSlot3D({
    required this.label,
    required this.center,
    required this.slotKeys,
    required this.role,
    required this.side,
  });

  final String label;

  /// 地砖中心（y=0）。立牌摆放在 center + [standeeBaseOffset]。
  final Vector3 center;

  /// 参与高亮/放置判定的槽位 key（`controller_zone_sequence`；
  /// EMZ 携带双方 controller 两个，见 duel_room1 同名语义）。
  final List<String> slotKeys;
  final ZoneRole role;
  final FieldSide side;

  /// 稳定 id（用于组件查找/高亮映射）：首个 slotKey 或 label。
  String get id => slotKeys.isNotEmpty ? slotKeys.first : label;
}

/// 3D 场地布局常量与槽位构建。
abstract final class Field3DLayout {
  /// 卡宽（世界单位）。卡高 = cardW / (59/86)。
  static const double cardW = 1.0;
  static const double cardH = cardW * 86 / 59;

  /// 地砖 footprint（比卡略大）。
  static const double tileSize = 1.18;
  static const double tileThickness = 0.06;

  /// 列间距 / 行位置。
  static const double colGap = 1.26;
  static const double monsterRowZ = 1.62;
  static const double spellTrapRowZ = 3.12;
  static const double emzX = 0.98;

  /// 立牌底部离地高度（浮在地砖上方）。
  static const double standeeBaseY = 0.10;

  /// 立牌后仰角（弧度，绕 X 轴向己方一侧倾倒，便于俯视阅读）。
  static const double standeeTiltRad = -0.10;

  /// 默认相机（MDPro3 式己方身后俯视）。
  static final Vector3 defaultCameraPosition = Vector3(0, 7.6, 8.8);
  static final Vector3 defaultCameraTarget = Vector3(0, 0, -0.4);
  static const double defaultFovY = 50;

  static double colX(int col) => (col - 3) * colGap;

  /// 构建全部 32 个卡槽（[myController] 为己方 controller，0 或 1）。
  static List<ZoneSlot3D> buildSlots(int myController) {
    final self = myController;
    final opp = 1 - self;
    String key(int c, int z, int s) => '${c}_${z}_$s';

    return [
      // ── 对方 S/T 行（z = -spellTrapRowZ）：DECK | S/T5..1 | EXTRA ──
      ZoneSlot3D(
        label: 'opp_deck',
        center: Vector3(colX(0), 0, -spellTrapRowZ),
        slotKeys: const [],
        role: ZoneRole.deck,
        side: FieldSide.opponent,
      ),
      for (var i = 0; i < 5; i++)
        ZoneSlot3D(
          label: 'opp_st_${4 - i}',
          center: Vector3(colX(1 + i), 0, -spellTrapRowZ),
          slotKeys: [key(opp, zoneSpellTrap, 4 - i)],
          role: ZoneRole.spellTrap,
          side: FieldSide.opponent,
        ),
      ZoneSlot3D(
        label: 'opp_extra',
        center: Vector3(colX(6), 0, -spellTrapRowZ),
        slotKeys: const [],
        role: ZoneRole.extra,
        side: FieldSide.opponent,
      ),
      // ── 对方怪兽行（z = -monsterRowZ）：Grave | M5..1 | Field ──
      ZoneSlot3D(
        label: 'opp_grave',
        center: Vector3(colX(0), 0, -monsterRowZ),
        slotKeys: const [],
        role: ZoneRole.grave,
        side: FieldSide.opponent,
      ),
      for (var i = 0; i < 5; i++)
        ZoneSlot3D(
          label: 'opp_m_${4 - i}',
          center: Vector3(colX(1 + i), 0, -monsterRowZ),
          slotKeys: [key(opp, zoneMonster, 4 - i)],
          role: ZoneRole.monster,
          side: FieldSide.opponent,
        ),
      ZoneSlot3D(
        label: 'opp_field',
        center: Vector3(colX(6), 0, -monsterRowZ),
        slotKeys: [key(opp, zoneSpellTrap, 5)],
        role: ZoneRole.fieldSpell,
        side: FieldSide.opponent,
      ),
      // ── EMZ + 除外行（z = 0）：对方除外 | EMZ1 | EMZ2 | 己方除外 ──
      ZoneSlot3D(
        label: 'opp_banish',
        center: Vector3(colX(0), 0, 0),
        slotKeys: const [],
        role: ZoneRole.banish,
        side: FieldSide.opponent,
      ),
      ZoneSlot3D(
        label: 'emz_1',
        center: Vector3(-emzX, 0, 0),
        slotKeys: [key(self, zoneMonster, 5), key(opp, zoneMonster, 6)],
        role: ZoneRole.extraMonster,
        side: FieldSide.self,
      ),
      ZoneSlot3D(
        label: 'emz_2',
        center: Vector3(emzX, 0, 0),
        slotKeys: [key(self, zoneMonster, 6), key(opp, zoneMonster, 5)],
        role: ZoneRole.extraMonster,
        side: FieldSide.self,
      ),
      ZoneSlot3D(
        label: 'self_banish',
        center: Vector3(colX(6), 0, 0),
        slotKeys: const [],
        role: ZoneRole.banish,
        side: FieldSide.self,
      ),
      // ── 己方怪兽行（z = +monsterRowZ）：Field | M1..5 | Grave ──
      ZoneSlot3D(
        label: 'self_field',
        center: Vector3(colX(0), 0, monsterRowZ),
        slotKeys: [key(self, zoneSpellTrap, 5)],
        role: ZoneRole.fieldSpell,
        side: FieldSide.self,
      ),
      for (var i = 0; i < 5; i++)
        ZoneSlot3D(
          label: 'self_m_$i',
          center: Vector3(colX(1 + i), 0, monsterRowZ),
          slotKeys: [key(self, zoneMonster, i)],
          role: ZoneRole.monster,
          side: FieldSide.self,
        ),
      ZoneSlot3D(
        label: 'self_grave',
        center: Vector3(colX(6), 0, monsterRowZ),
        slotKeys: const [],
        role: ZoneRole.grave,
        side: FieldSide.self,
      ),
      // ── 己方 S/T 行（z = +spellTrapRowZ）：EXTRA | S/T1..5 | DECK ──
      ZoneSlot3D(
        label: 'self_extra',
        center: Vector3(colX(0), 0, spellTrapRowZ),
        slotKeys: const [],
        role: ZoneRole.extra,
        side: FieldSide.self,
      ),
      for (var i = 0; i < 5; i++)
        ZoneSlot3D(
          label: 'self_st_$i',
          center: Vector3(colX(1 + i), 0, spellTrapRowZ),
          slotKeys: [key(self, zoneSpellTrap, i)],
          role: ZoneRole.spellTrap,
          side: FieldSide.self,
        ),
      ZoneSlot3D(
        label: 'self_deck',
        center: Vector3(colX(6), 0, spellTrapRowZ),
        slotKeys: const [],
        role: ZoneRole.deck,
        side: FieldSide.self,
      ),
    ];
  }

  /// 立牌中心点（地砖中心 + 离地 + 立起后重心上移 cardH/2）。
  static Vector3 standeeCenter(ZoneSlot3D slot) =>
      Vector3(slot.center.x, standeeBaseY + cardH / 2, slot.center.z);

  /// 立牌横置角（弧度，绕卡面法线 Z 轴 roll）。守备表示横置 90°——
  /// 卡图仍面向 +Z（我方相机）保持可读，只是画面横躺（MDPro3 风格）。
  static double standeeRoll(int position) {
    final isDefense =
        position & (posFaceupDefense | posFacedownDefense) != 0;
    return isDefense ? -1.5707963 : 0.0;
  }

  static bool isFacedown(int position) => position & posFacedown != 0;
}
