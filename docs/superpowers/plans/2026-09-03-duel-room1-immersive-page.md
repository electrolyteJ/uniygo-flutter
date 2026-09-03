# duel_room1 沉浸式页面实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `DuelRoomPage` 在 Android/iOS 进入沉浸式全屏，移除 AppBar，并仅在非对局阶段显示安全区内的浮动回退按钮。

**Architecture:** 用独立页面生命周期组件封装移动端 `SystemChrome` 进入/恢复调用，避免在 build 中执行副作用。房间 Stack 依据阶段和结算状态构建浮动按钮；对局场地 HUD 删除现有回退入口。

**Tech Stack:** Dart 3 / Flutter / Riverpod / SystemChrome / flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-03-duel-room1-immersive-page-design.md`

---

### Task 1: 实现页面沉浸式生命周期与阶段回退按钮

**Files:**
- Create: `modules/duel_room1/lib/platform/duel_immersive_mode.dart`
- Modify: `modules/duel_room1/lib/duel_room_page.dart`
- Modify: `modules/duel_room1/lib/field/duel_field_page.dart`
- Create: `modules/duel_room1/test/duel_immersive_mode_test.dart`
- Create: `modules/duel_room1/test/duel_room_navigation_ui_test.dart`

- [ ] **Step 1: 写失败测试**

测试移动端生命周期进入/恢复、桌面/Web 不调用、阶段显示策略、浮动按钮 44dp、安全区位置，以及对局 HUD 不再包含回退按钮。

```dart
test('only waiting stages show the room back button', () {
  expect(shouldShowDuelRoomBackButton(isInDuel: false, hasResult: false), isTrue);
  expect(shouldShowDuelRoomBackButton(isInDuel: true, hasResult: false), isFalse);
  expect(shouldShowDuelRoomBackButton(isInDuel: false, hasResult: true), isFalse);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/duel_immersive_mode_test.dart test/duel_room_navigation_ui_test.dart`

Expected: FAIL，沉浸式生命周期和阶段按钮 API 尚不存在。

- [ ] **Step 3: 实现沉浸式生命周期**

`duel_immersive_mode.dart` 提供可注入的 UI mode setter；Android/iOS 在 `initState` 请求 `immersiveSticky`，在 `dispose` 请求 `edgeToEdge`，其他平台不调用。

```dart
class DuelImmersiveMode extends StatefulWidget {
  const DuelImmersiveMode({super.key, required this.child});
  final Widget child;
  // State 在 initState/dispose 中按 PlatformAdaptive 移动端判定切换模式。
}
```

- [ ] **Step 4: 移除 AppBar 并迁移回退按钮**

`DuelRoomPage` Scaffold 不再设置 `appBar`/`extendBodyBehindAppBar`。在 Stack 中按以下策略构建按钮：

```dart
bool shouldShowDuelRoomBackButton({
  required bool isInDuel,
  required bool hasResult,
}) => !isInDuel && !hasResult;
```

按钮位置由 `DuelRoomLayout.of(context).safePadding` 与 `panelGap` 计算，视觉沿用 HUD 样式，实际命中 `44×44`。点击继续调用 `backHomeDialog`。

- [ ] **Step 5: 删除对局 HUD 回退入口**

从 `DuelFieldPage._buildTopHud` 删除 `Icons.arrow_back` 按钮和退出回调；紧凑模式仅保留对方状态芯片、Spacer 和计时器，普通模式无顶部 Flutter HUD 内容时返回 `SizedBox.shrink()`。

- [ ] **Step 6: 验证**

Run: `flutter test test/duel_immersive_mode_test.dart test/duel_room_navigation_ui_test.dart && flutter test && flutter analyze ../../modules/duel_room1`

Expected: 全部 PASS，analyzer 无问题。
