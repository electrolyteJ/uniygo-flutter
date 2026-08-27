import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';

import 'card_standee.dart';
import 'field_3d_layout.dart';
import 'raycast_3d.dart';
import 'standee_diff.dart';

/// 立牌控制器：按快照 diff 维护场上立牌的生命周期与摆放。
///
/// - 新增：在槽位生成并播登场动画（默认 scale-in；召唤演出由
///   EffectsManager 另行触发后再调 playEntrance）
/// - 更新：表示形式/素材/卡号变化原地补间
/// - 移除：播破坏动画后回收
class StandeeController extends Component3D {
  StandeeController({required List<ZoneSlot3D> slots})
      : slotByKey = {
          for (final slot in slots)
            for (final key in slot.slotKeys) key: slot,
        };

  /// 卡槽 key（controller_zone_sequence）→ 槽位。EMZ 双方 key 都有映射。
  final Map<String, ZoneSlot3D> slotByKey;

  final Map<String, CardStandee> _byKey = {};
  Map<String, StandeeCardView> _snapshot = {};

  CardStandee? at(String zoneKey) => _byKey[zoneKey];

  /// 卡槽的世界坐标（立牌中心）。未知 key 返回 null。
  Vector3? slotStandeeCenter(String zoneKey) {
    final slot = slotByKey[zoneKey];
    return slot == null ? null : Field3DLayout.standeeCenter(slot);
  }

  /// 卡槽地砖中心（y=0，效果落点用）。未知 key 返回 null。
  Vector3? slotGroundCenter(String zoneKey) {
    return slotByKey[zoneKey]?.center;
  }

  /// 应用新快照：diff 后增删改。
  void applySnapshot(Map<String, StandeeCardView> next) {
    final diff = diffStandeeCards(_snapshot, next);
    if (diff.isEmpty) return;
    _snapshot = Map.of(next);

    for (final key in diff.removed) {
      final standee = _byKey.remove(key);
      if (standee == null) continue;
      if (standee.dying) {
        standee.removeFromParent();
      } else {
        standee.die(onDone: standee.removeFromParent);
      }
    }
    for (final entry in diff.added.entries) {
      _spawn(entry.key, entry.value);
    }
    for (final entry in diff.updated.entries) {
      _byKey[entry.key]?.applyCard(
        code: entry.value.code,
        position: entry.value.position,
        overlayCount: entry.value.overlayCount,
      );
    }
  }

  /// 直接清场（新对局/离房）。
  void clearAll() {
    _snapshot.clear();
    for (final standee in _byKey.values) {
      standee.removeFromParent();
    }
    _byKey.clear();
  }

  void _spawn(String key, StandeeCardView view) {
    final slot = slotByKey[key];
    if (slot == null) return; // 手牌/额外等区域不立牌
    final standee = CardStandee(
      slotId: slot.id,
      code: view.code,
      cardPosition: view.position,
      overlayCount: view.overlayCount,
    );
    standee.position.setFrom(Field3DLayout.standeeCenter(slot));
    _byKey[key] = standee;
    add(standee);
    standee.playEntrance(StandeeEntrance.appear);
  }

  /// 射线拾取：命中最近立牌的卡槽 key，未命中返回 null。
  String? hitTest(Ray3D ray) {
    String? bestKey;
    var bestT = double.infinity;
    for (final entry in _byKey.entries) {
      if (entry.value.dying) continue;
      final t = intersectAabb(ray, entry.value.hitAabb());
      if (t != null && t < bestT) {
        bestT = t;
        bestKey = entry.key;
      }
    }
    return bestKey;
  }
}
