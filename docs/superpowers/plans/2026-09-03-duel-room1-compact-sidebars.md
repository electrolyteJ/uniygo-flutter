# duel_room1 紧凑侧栏适配实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 compact 视口的卡片详情、区域浏览和确认列表缩窄为安全内容区约 35% 的左右侧栏，同时保持决斗区相机不变。

**Architecture:** 在 `DuelRoomLayoutSpec` 中集中计算紧凑侧栏宽度，左详情和右侧 DockedPanel 共同消费同一规格。内容组件只根据实际约束调整卡图、内边距和网格列数；侧栏状态不传入 Flame 相机。

**Tech Stack:** Dart 3 / Flutter / Flame / flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-03-duel-room1-compact-sidebars-design.md`

---

### Task 1: 实现 compact 窄侧栏

**Files:**
- Modify: `modules/duel_room1/lib/layout/duel_room_layout.dart`
- Modify: `modules/duel_room1/lib/field/widgets/docked_panel_shell.dart`
- Modify: `modules/duel_room1/lib/field/widgets/inspector/card_detail_drawer.dart`
- Modify: `modules/duel_room1/lib/field/widgets/inspector/zone_browser_panel.dart`
- Modify: `modules/duel_room1/lib/field/widgets/confirm/confirm_cards_panel.dart`
- Modify: `modules/duel_room1/test/duel_room_layout_test.dart`
- Modify: `modules/duel_room1/test/docked_panel_shell_test.dart`
- Modify: `modules/duel_room1/test/zone_browser_panel_test.dart`
- Modify: `modules/duel_room1/test/confirm_cards_panel_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖 `640×360`、`800×450`、带非对称安全区的 `844×390` 和桌面尺寸：

```dart
expect(DuelRoomLayoutSpec.resolve(const Size(640, 360)).dockedPanelWidth, 224);
expect(DuelRoomLayoutSpec.resolve(const Size(800, 450)).dockedPanelWidth, 280);
expect(DuelRoomLayoutSpec.resolve(const Size(1280, 720)).dockedPanelWidth, 440);
```

Widget 测试断言左右侧栏实际宽度、safeRect、2 列网格、卡图不越内容区、关闭 44dp、内容可滚动。

- [ ] **Step 2: 运行 RED**

Run: `flutter test test/duel_room_layout_test.dart test/docked_panel_shell_test.dart test/zone_browser_panel_test.dart test/confirm_cards_panel_test.dart`

Expected: FAIL，compact 仍返回 360dp 或左详情仍为 324dp。

- [ ] **Step 3: 实现统一宽度**

`DuelRoomLayoutSpec.resolve` 在 compact 下使用：

```dart
final compactWidth = (safeWidth * 0.35).clamp(220.0, 300.0);
final panelWidth = math.min(compactWidth, contentWidth);
```

regular/wide 保持 `440dp`。左详情 `cardDetailDrawerRect` 和 `CardDetailDrawer` 使用 `spec.dockedPanelWidth`，不再独立夹紧到 `324dp`。

- [ ] **Step 4: 适配内容密度**

紧凑左详情根据 `LayoutBuilder` 将卡图宽度限制为内容宽度，高度保持卡片比例；标题与关闭固定，正文继续滚动。右侧区域和确认网格在 compact 固定 2 列，桌面保持现有列数。

- [ ] **Step 5: 验证相机不受侧栏影响**

测试侧栏打开前后不调用 `DuelFieldGame.setLayoutSpec` 或其他相机 API；现有面板互斥 provider 测试继续通过。运行全部模块测试与 analyzer。

Run: `flutter test && flutter analyze ../../modules/duel_room1`

Expected: 全部 PASS。
