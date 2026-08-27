/// ZoneGridComponent 高亮 key 翻译回归测试（S3）。
///
/// 背景：高亮调用方传区域 key（controller_zone_sequence），EMZ 槽携带
/// 双方两个 key（emz_1 = 己方 0_4_5 + 对方 1_4_6）；旧实现直接以传入
/// key 存表而 update 只按 slot.id（首个 key）查 → 对方侧 EMZ 高亮
/// 静默不亮。修复后内部统一翻译为 slot.id。
library;

import 'package:duel_room3/scene3d/field_3d_layout.dart';
import 'package:duel_room3/scene3d/zone_grid_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // myController=0 视角：emz_1 携带 ['0_4_5'（己方）, '1_4_6'（对方）]
  final slots = Field3DLayout.buildSlots(0);
  final emz1 = slots.firstWhere((s) => s.label == 'emz_1');

  group('EMZ 双 key 高亮翻译', () {
    test('对方侧 EMZ key 高亮落到同一槽位（slot.id）', () {
      final grid = ZoneGridComponent(slots: slots);
      expect(emz1.slotKeys, hasLength(2));
      expect(emz1.id, emz1.slotKeys.first); // id = 首个 key

      grid.setSlotHighlight(emz1.slotKeys[1], SlotHighlight.placeTarget);
      expect(grid.highlightOf(emz1.id), SlotHighlight.placeTarget);
      expect(grid.highlightOf(emz1.slotKeys[0]), SlotHighlight.placeTarget);
    });

    test('己方 key 与对方 key 等价；清除任一侧 key 都生效', () {
      final grid = ZoneGridComponent(slots: slots);
      grid.setSlotHighlight(emz1.slotKeys[0], SlotHighlight.selectable);
      expect(grid.highlightOf(emz1.slotKeys[1]), SlotHighlight.selectable);

      grid.setSlotHighlight(emz1.slotKeys[1], SlotHighlight.none);
      expect(grid.highlightOf(emz1.id), SlotHighlight.none);
    });

    test('普通槽位（单 key）与 label 槽位行为不变', () {
      final grid = ZoneGridComponent(slots: slots);
      final monster = slots.firstWhere((s) => s.label == 'self_m_0');
      grid.setSlotHighlight(monster.slotKeys.single, SlotHighlight.checked);
      expect(grid.highlightOf(monster.id), SlotHighlight.checked);

      // 无 slotKeys 的槽位（卡组等）以 label 原样工作
      grid.setSlotHighlight('self_deck', SlotHighlight.selectable);
      expect(grid.highlightOf('self_deck'), SlotHighlight.selectable);
    });

    test('clearHighlights 清空全部', () {
      final grid = ZoneGridComponent(slots: slots);
      grid.setSlotHighlight(emz1.slotKeys[1], SlotHighlight.checked);
      grid.setSlotHighlight('self_deck', SlotHighlight.selectable);
      grid.clearHighlights();
      expect(grid.highlightOf(emz1.id), SlotHighlight.none);
      expect(grid.highlightOf('self_deck'), SlotHighlight.none);
    });
  });
}
