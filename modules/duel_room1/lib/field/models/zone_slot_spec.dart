import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:duelink/duelink.dart'
    show
        CARD_ZONE_DECK,
        CARD_ZONE_EXTRA,
        CARD_ZONE_GRAVE,
        CARD_ZONE_REMOVED,
        POS_FACEUP_ATTACK,
        POS_FACEDOWN;

import 'duel_field_layout.dart';
import 'flame_field_snapshot.dart';

/// 卡槽高亮态：驱动选择/放置类交互的槽位描边与发光。
enum CardSlotHighlight {
  none,

  /// 就地选择中可选中（连锁/选卡/解放等）。
  selectable,

  /// 就地选择多选中已勾选。
  checked,

  /// 放置选择（MSG_SELECT_PLACE）中的可放置空槽位。
  placeTarget,
}

/// 槽位点击行为。
enum ZoneSlotTapBehavior {
  /// 默认：按选中卡逻辑分发（onCardSelect）。
  select,

  /// 打开区域检视（墓地/额外/除外）。
  inspect,

  /// 无行为（卡组槽位）。
  none,
}

/// 槽位静态规格：位置/标签等布局期常量 + 动态内容解析闭包。
///
/// 32 个槽位位置固定（见 [buildZoneSlotSpecs]），布局期一次性创建；
/// 快照变化时只需重新执行 [resolveCard] 与 [resolveSlotInteraction]
/// 得到动态内容并原地更新组件，无需销毁重建。
class ZoneSlotSpec {
  const ZoneSlotSpec({
    required this.label,
    required this.boardX,
    required this.boardY,
    required this.resolveCard,
    this.isMonster = false,
    this.isEMZ = false,
    this.slotKeys = const [],
    this.tapBehavior = ZoneSlotTapBehavior.select,
    this.inspectZoneKey,
    this.chainSlotKey,
  });

  final String label;
  final double boardX;
  final double boardY;
  final bool isMonster;
  final bool isEMZ;

  /// 参与高亮/放置判定的槽位 key（EMZ 携带双方 controller 两个）。
  final List<String> slotKeys;
  final ZoneSlotTapBehavior tapBehavior;

  /// [tapBehavior] 为 [ZoneSlotTapBehavior.inspect] 时的区域 key。
  final String? inspectZoneKey;

  /// 连锁序号查找 key（仅卡组槽位等 slotKeys/inspectZoneKey 都覆盖不到
  /// 的槽位需要显式指定，如 `self_deck`/`opp_deck`）。
  final String? chainSlotKey;

  /// 从给定快照解析该槽位应显示的卡（null = 空槽）。
  final FieldCard? Function(FlameFieldSnapshot snapshot) resolveCard;

  /// 该槽位对应的连锁序号（1 起；不在连锁链上为 null）。
  ///
  /// 查找顺序：场上卡槽 key（slotKeys，EMZ 携带双方 key）→
  /// 区域堆命名 key（inspectZoneKey / chainSlotKey）。
  int? chainOrderOf(Map<String, int> orders) {
    if (orders.isEmpty) return null;
    for (final key in slotKeys) {
      final order = orders[key];
      if (order != null) return order;
    }
    final namedKey = chainSlotKey ?? inspectZoneKey;
    return namedKey == null ? null : orders[namedKey];
  }
}

/// 解析槽位的交互态（高亮 + 放置目标 key）。
///
/// 优先级 checked > selectable > placeTarget，与 [slotKeys] 顺序无关：
/// 循环内独立收集候选，循环后按优先级挑选（EMZ 槽位同时携带双方 key 时，
/// 先命中的 placeTarget 不再挡住后续 selectable 升级高亮）。
({CardSlotHighlight highlight, String? placeTargetKey}) resolveSlotInteraction(
  FlameFieldSnapshot snapshot,
  List<String> slotKeys,
) {
  var selectable = false;
  String? placeTargetKey;
  for (final key in slotKeys) {
    if (snapshot.inlineSelectedFieldKeys.contains(key)) {
      return (highlight: CardSlotHighlight.checked, placeTargetKey: null);
    }
    if (snapshot.inlineSelectableFieldKeys.contains(key)) {
      selectable = true;
    } else if (placeTargetKey == null &&
        snapshot.placeTargetFieldKeys.contains(key)) {
      placeTargetKey = key;
    }
  }
  if (selectable) {
    return (highlight: CardSlotHighlight.selectable, placeTargetKey: null);
  }
  if (placeTargetKey != null) {
    return (
      highlight: CardSlotHighlight.placeTarget,
      placeTargetKey: placeTargetKey,
    );
  }
  return (highlight: CardSlotHighlight.none, placeTargetKey: null);
}

/// 场地全部 32 个槽位的静态布局 + 动态解析闭包。
///
/// 布局语义与原 ZonesComponent._buildAllSlots 逐项一致：
/// SpellTrap 行 [EXTRA][S/T..][DECK]（对手镜像），Monster 行 FIELD 与
/// M1..5 同线，EMZ/BANISH 行（y=0）共享物理槽位。
/// [snapshot] 仅用于确定 self/opp controller 朝向（决斗期间不变），
/// 返回的规格在整场对局中复用；resolveCard 每次调用读传入快照。
List<ZoneSlotSpec> buildZoneSlotSpecs(FlameFieldSnapshot snapshot) {
  final self = snapshot.myController;
  final opp = 1 - self;

  const colX = DuelFieldLayout.colX;
  const monsterY = DuelFieldLayout.monsterY;
  const stY = DuelFieldLayout.stY;

  FieldCard? Function(FlameFieldSnapshot) field(int c, int z, int s) =>
      (snap) => snap.fieldCards[zoneKeyOf(c, z, s)];

  FieldCard? Function(FlameFieldSnapshot) deckPreview(int controller) {
    return (snap) {
      final count = controller == snap.myController
          ? snap.selfDeck
          : snap.oppDeck;
      if (count <= 0) return null;
      return FieldCard(
        code: 0,
        controller: controller,
        zone: CARD_ZONE_DECK,
        sequence: count - 1,
        position: POS_FACEDOWN,
      );
    };
  }

  FieldCard? Function(FlameFieldSnapshot) zonePreview(
    String zoneKey, {
    required int controller,
    required int zone,
  }) {
    return (snap) {
      final codes = snap.zoneCodesOf(zoneKey);
      for (var i = codes.length - 1; i >= 0; i--) {
        final code = codes[i];
        if (code <= 0) continue;
        return FieldCard(
          code: code,
          controller: controller,
          zone: zone,
          sequence: i,
          position: POS_FACEUP_ATTACK,
        );
      }
      return null;
    };
  }

  // EMZ 为双方共享的物理槽位，双方 controller 的序列是镜像的：
  // 己方 s5 ↔ 对手 s6（屏幕左 EMZ），己方 s6 ↔ 对手 s5（屏幕右 EMZ）。
  // 解析时优先对手 controller，缺省兜底己方。
  FieldCard? Function(FlameFieldSnapshot) emz(
    int selfSequence,
    int oppSequence,
  ) => (snap) =>
      snap.fieldCards['${opp}_4_$oppSequence'] ??
      snap.fieldCards['${self}_4_$selfSequence'];

  return [
    // ── 对手 SpellTrap 行 (-stY) ──
    ZoneSlotSpec(
      label: 'DECK',
      boardX: colX[0],
      boardY: -stY,
      resolveCard: deckPreview(opp),
      tapBehavior: ZoneSlotTapBehavior.none,
      chainSlotKey: 'opp_deck',
    ),
    for (int i = 0; i < 5; i++)
      ZoneSlotSpec(
        label: 'S/T ${5 - i}',
        boardX: colX[1 + i],
        boardY: -stY,
        resolveCard: field(opp, 8, 4 - i),
        slotKeys: [zoneKeyOf(opp, 8, 4 - i)],
      ),
    ZoneSlotSpec(
      label: 'EXTRA',
      boardX: colX[6],
      boardY: -stY,
      resolveCard: zonePreview(
        'opp_extra',
        controller: opp,
        zone: CARD_ZONE_EXTRA,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'opp_extra',
    ),

    // ── 对手 Monster 行 (-monsterY) ──
    ZoneSlotSpec(
      label: 'Grave',
      boardX: colX[0],
      boardY: -monsterY,
      resolveCard: zonePreview(
        'opp_grave',
        controller: opp,
        zone: CARD_ZONE_GRAVE,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'opp_grave',
    ),
    for (int i = 0; i < 5; i++)
      ZoneSlotSpec(
        label: 'M ${5 - i}',
        boardX: colX[1 + i],
        boardY: -monsterY,
        isMonster: true,
        resolveCard: field(opp, 4, 4 - i),
        slotKeys: [zoneKeyOf(opp, 4, 4 - i)],
      ),
    ZoneSlotSpec(
      label: 'Field',
      boardX: colX[6],
      boardY: -monsterY,
      resolveCard: field(opp, 8, 5),
      slotKeys: ['${opp}_8_5'],
    ),

    // ── EMZ + BANISH 行 (y=0) ──
    ZoneSlotSpec(
      label: 'Banish',
      boardX: colX[0],
      boardY: 0,
      resolveCard: zonePreview(
        'opp_removed',
        controller: opp,
        zone: CARD_ZONE_REMOVED,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'opp_removed',
    ),
    ZoneSlotSpec(
      label: 'EMZ 1',
      boardX: -84.0,
      boardY: 0,
      isMonster: true,
      isEMZ: true,
      resolveCard: emz(5, 6),
      slotKeys: ['${self}_4_5', '${opp}_4_6'],
    ),
    ZoneSlotSpec(
      label: 'EMZ 2',
      boardX: 84.0,
      boardY: 0,
      isMonster: true,
      isEMZ: true,
      resolveCard: emz(6, 5),
      slotKeys: ['${self}_4_6', '${opp}_4_5'],
    ),
    ZoneSlotSpec(
      label: 'Banish',
      boardX: colX[6],
      boardY: 0,
      resolveCard: zonePreview(
        'self_removed',
        controller: self,
        zone: CARD_ZONE_REMOVED,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'self_removed',
    ),

    // ── 己方 Monster 行 (monsterY) ──
    ZoneSlotSpec(
      label: 'Field',
      boardX: colX[0],
      boardY: monsterY,
      resolveCard: field(self, 8, 5),
      slotKeys: ['${self}_8_5'],
    ),
    for (int i = 0; i < 5; i++)
      ZoneSlotSpec(
        label: 'M ${i + 1}',
        boardX: colX[1 + i],
        boardY: monsterY,
        isMonster: true,
        resolveCard: field(self, 4, i),
        slotKeys: [zoneKeyOf(self, 4, i)],
      ),
    ZoneSlotSpec(
      label: 'Grave',
      boardX: colX[6],
      boardY: monsterY,
      resolveCard: zonePreview(
        'self_grave',
        controller: self,
        zone: CARD_ZONE_GRAVE,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'self_grave',
    ),

    // ── 己方 SpellTrap 行 (stY) ──
    ZoneSlotSpec(
      label: 'EXTRA',
      boardX: colX[0],
      boardY: stY,
      resolveCard: zonePreview(
        'self_extra',
        controller: self,
        zone: CARD_ZONE_EXTRA,
      ),
      tapBehavior: ZoneSlotTapBehavior.inspect,
      inspectZoneKey: 'self_extra',
    ),
    for (int i = 0; i < 5; i++)
      ZoneSlotSpec(
        label: 'S/T ${i + 1}',
        boardX: colX[1 + i],
        boardY: stY,
        resolveCard: field(self, 8, i),
        slotKeys: [zoneKeyOf(self, 8, i)],
      ),
    ZoneSlotSpec(
      label: 'DECK',
      boardX: colX[6],
      boardY: stY,
      resolveCard: deckPreview(self),
      tapBehavior: ZoneSlotTapBehavior.none,
      chainSlotKey: 'self_deck',
    ),
  ];
}
