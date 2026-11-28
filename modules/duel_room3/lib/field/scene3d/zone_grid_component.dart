import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import '../../theme/cyber_skin.dart';
import 'field_3d_layout.dart';

/// 槽位高亮态（对齐 duel_room1 的 CardSlotHighlight 语义）。
enum SlotHighlight { none, selectable, checked, placeTarget }

/// 区域地砖网格：32 个微凸起地砖，支持按槽位 id 高亮脉冲。
///
/// 赛博皮肤下地砖底色改为深靛蓝/紫/青，且无高亮槽位也有逐格相位差的
/// 流动微光；关闭「演出增强层」时回落到经典配色与原呼吸节奏。
class ZoneGridComponent extends Component3D {
  ZoneGridComponent({required this.slots})
    : _slotByKey = {
        for (final slot in slots)
          for (final key in slot.slotKeys) key: slot,
      };

  final List<ZoneSlot3D> slots;

  /// 区域 key（controller_zone_sequence）→ 槽位（与 StandeeController
  /// 同构；EMZ 携带双方两个 key）。setSlotHighlight 先翻译成 slot.id，
  /// 否则对方侧 EMZ key 的高亮静默不亮（update 只按 slot.id 查表）。
  final Map<String, ZoneSlot3D> _slotByKey;

  final Map<String, MeshComponent> _tiles = {};
  final Map<String, SpatialMaterial> _materials = {};
  final Map<String, SlotHighlight> _highlights = {};
  double _pulse = 0;

  static const _classicBaseColors = {
    ZoneRole.monster: ui.Color(0xFF2E3A55),
    ZoneRole.extraMonster: ui.Color(0xFF3A2E55),
    ZoneRole.spellTrap: ui.Color(0xFF1E4A44),
    ZoneRole.fieldSpell: ui.Color(0xFF1E4A44),
    ZoneRole.deck: ui.Color(0xFF4A3A1E),
    ZoneRole.extra: ui.Color(0xFF3A1E4A),
    ZoneRole.grave: ui.Color(0xFF40262A),
    ZoneRole.banish: ui.Color(0xFF2A2A33),
  };

  static const _cyberBaseColors = {
    ZoneRole.monster: ui.Color(0xFF161A38),
    ZoneRole.extraMonster: ui.Color(0xFF2A1246),
    ZoneRole.spellTrap: ui.Color(0xFF0B2C38),
    ZoneRole.fieldSpell: ui.Color(0xFF0B2C38),
    ZoneRole.deck: ui.Color(0xFF3A1633),
    ZoneRole.extra: ui.Color(0xFF2B1240),
    ZoneRole.grave: ui.Color(0xFF371425),
    ZoneRole.banish: ui.Color(0xFF151A2A),
  };

  static const _classicHighlightColors = {
    SlotHighlight.selectable: ui.Color(0xFF37E2FF),
    SlotHighlight.checked: ui.Color(0xFF7CFF6B),
    SlotHighlight.placeTarget: ui.Color(0xFFFFC837),
  };

  static const _cyberHighlightColors = {
    SlotHighlight.selectable: CyberPalette.cyan,
    SlotHighlight.checked: CyberPalette.acid,
    SlotHighlight.placeTarget: CyberPalette.magenta,
  };

  @override
  Future<void> onLoad() async {
    for (final slot in slots) {
      final material = SpatialMaterial(
        albedoColor: _cyberBaseColors[slot.role] ?? const ui.Color(0xFF14182C),
        metallic: 0.42,
        roughness: 0.55,
      );
      final tile = MeshComponent(
        mesh: CuboidMesh(
          size: Vector3(
            Field3DLayout.tileSize,
            Field3DLayout.tileThickness,
            Field3DLayout.tileSize,
          ),
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

  /// 设置某槽位的高亮态。接受区域 key（controller_zone_sequence，
  /// EMZ 双方 key 都可）或 slot.id/label；内部统一翻译为 slot.id。
  void setSlotHighlight(String key, SlotHighlight highlight) {
    final id = _slotByKey[key]?.id ?? key;
    if (highlight == SlotHighlight.none) {
      _highlights.remove(id);
    } else {
      _highlights[id] = highlight;
    }
  }

  /// 某槽位当前的高亮态（测试/调试用）。
  SlotHighlight highlightOf(String key) {
    final id = _slotByKey[key]?.id ?? key;
    return _highlights[id] ?? SlotHighlight.none;
  }

  /// 清掉全部高亮。
  void clearHighlights() => _highlights.clear();

  @override
  void update(double dt) {
    _pulse += dt;
    final cyber = CyberSkin.isOn;
    final baseColors = cyber ? _cyberBaseColors : _classicBaseColors;
    final highlightColors = cyber
        ? _cyberHighlightColors
        : _classicHighlightColors;
    final wave = 0.55 + 0.45 * math.sin(_pulse * (cyber ? 6.5 : 5.0));

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final material = _materials[slot.id];
      if (material == null) continue;
      final base = baseColors[slot.role] ?? const ui.Color(0xFF14182C);
      final highlight = _highlights[slot.id];
      if (highlight == null) {
        if (cyber) {
          // 逐格相位差的流动微光：32 槽像一条缓慢扫过的数据带。
          final drift = 0.88 + 0.12 * math.sin(_pulse * 2.1 + i * 0.42);
          material.albedoColor = ui.Color.fromRGBO(
            (base.r * 255 * drift).round().clamp(0, 255),
            (base.g * 255 * drift).round().clamp(0, 255),
            (base.b * 255 * drift).round().clamp(0, 255),
            1,
          );
        } else {
          material.albedoColor = base;
        }
      } else {
        final glow = highlightColors[highlight]!;
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
