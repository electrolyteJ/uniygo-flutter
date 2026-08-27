import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import 'field_3d_layout.dart';

/// 槽位高亮态（对齐 duel_room1 的 CardSlotHighlight 语义）。
enum SlotHighlight { none, selectable, checked, placeTarget }

/// 区域地砖网格：32 个微凸起地砖，支持按槽位 id 高亮脉冲。
class ZoneGridComponent extends Component3D {
  ZoneGridComponent({required this.slots});

  final List<ZoneSlot3D> slots;

  final Map<String, MeshComponent> _tiles = {};
  final Map<String, SpatialMaterial> _materials = {};
  final Map<String, SlotHighlight> _highlights = {};
  double _pulse = 0;

  static const _baseColors = {
    ZoneRole.monster: ui.Color(0xFF2E3A55),
    ZoneRole.extraMonster: ui.Color(0xFF3A2E55),
    ZoneRole.spellTrap: ui.Color(0xFF1E4A44),
    ZoneRole.fieldSpell: ui.Color(0xFF1E4A44),
    ZoneRole.deck: ui.Color(0xFF4A3A1E),
    ZoneRole.extra: ui.Color(0xFF3A1E4A),
    ZoneRole.grave: ui.Color(0xFF40262A),
    ZoneRole.banish: ui.Color(0xFF2A2A33),
  };

  static const _highlightColors = {
    SlotHighlight.selectable: ui.Color(0xFF37E2FF),
    SlotHighlight.checked: ui.Color(0xFF7CFF6B),
    SlotHighlight.placeTarget: ui.Color(0xFFFFC837),
  };

  @override
  Future<void> onLoad() async {
    for (final slot in slots) {
      final material = SpatialMaterial(
        albedoColor: _baseColors[slot.role] ?? const ui.Color(0xFF2A3245),
        metallic: 0.25,
        roughness: 0.8,
      );
      final tile = MeshComponent(
        mesh: CuboidMesh(
          size: Vector3(Field3DLayout.tileSize, Field3DLayout.tileThickness,
              Field3DLayout.tileSize),
          material: material,
        ),
        position: Vector3(
          slot.center.x,
          -Field3DLayout.tileThickness / 2 + 0.005,
          slot.center.z,
        ),
      );
      _tiles[slot.id] = tile;
      _materials[slot.id] = material;
      await add(tile);
    }
  }

  /// 设置某槽位的高亮态（id 见 [ZoneSlot3D.id]；空槽位 key 用 label）。
  void setSlotHighlight(String slotId, SlotHighlight highlight) {
    if (highlight == SlotHighlight.none) {
      _highlights.remove(slotId);
    } else {
      _highlights[slotId] = highlight;
    }
  }

  /// 清掉全部高亮。
  void clearHighlights() => _highlights.clear();

  @override
  void update(double dt) {
    _pulse += dt;
    final wave = 0.55 + 0.45 * math.sin(_pulse * 5.0);
    for (final slot in slots) {
      final material = _materials[slot.id];
      if (material == null) continue;
      final base = _baseColors[slot.role] ?? const ui.Color(0xFF2A3245);
      final highlight = _highlights[slot.id];
      if (highlight == null) {
        material.albedoColor = base;
      } else {
        final glow = _highlightColors[highlight]!;
        material.albedoColor = ui.Color.fromRGBO(
          _lerp8((base.r * 255).round(), (glow.r * 255).round(), wave),
          _lerp8((base.g * 255).round(), (glow.g * 255).round(), wave),
          _lerp8((base.b * 255).round(), (glow.b * 255).round(), wave),
          1,
        );
      }
    }
  }

  static int _lerp8(int a, int b, double t) =>
      (a + (b - a) * t).round().clamp(0, 255);
}
