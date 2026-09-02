# duel_room1 多平台响应式 UI 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `duel_room1` 全部 UI 建立统一响应式规格，使桌面原生、PC 浏览器 `800×450` 以上窗口及 Android/iOS 原生 `640×360` 以上横屏均可完成全流程。

**Architecture:** 在房间根部生成不可变 `DuelRoomLayoutSpec`，通过 InheritedWidget 向 Flutter UI 提供档位、安全内容区、HUD/面板/对话框几何和最小命中尺寸。Flame 棋盘继续使用现有世界坐标，但相机 fit 改为消费同一规格导出的不可压缩安全区和可压缩 HUD 预留；页面只在排列、列数、停靠方式变化时按档位分支，其余尺寸连续夹紧。

**Tech Stack:** Dart 3.12 / Flutter / Flame 1.38 / Riverpod 3 / flutter_portal / flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-01-duel-room1-responsive-ui-design.md`

---

## 文件结构

- **Create** `modules/duel_room1/lib/layout/duel_room_layout.dart`：纯响应式规格、档位判定、安全内容区、面板和网格几何。
- **Create** `modules/duel_room1/lib/layout/responsive_panel.dart`：选择器/结算页共用的安全区面板壳，仅处理约束、滚动区和固定操作区。
- **Create** `modules/duel_room1/test/duel_room_layout_test.dart`：规格边界和几何纯函数测试。
- **Create** `modules/duel_room1/test/responsive_test_harness.dart`：四档视口和 overflow 捕获测试工具。
- **Create** `modules/duel_room1/test/waiting_responsive_test.dart`：等待室、猜拳和先后攻尺寸矩阵。
- **Create** `modules/duel_room1/test/selector_responsive_test.dart`：选择器、确认层和菜单尺寸矩阵。
- **Create** `modules/duel_room1/test/duel_result_responsive_test.dart`：结算页尺寸矩阵。
- **Create** `modules/duel_room1/test/camera_viewport_layout_test.dart`：Flame 相机可用区纯几何测试。
- **Modify** `modules/duel_room1/lib/duel_room_page.dart`：安装布局作用域、统一阶段面板宿主、修正结算层级及日志按钮命中区。
- **Modify** `modules/duel_room1/lib/waiting/waiting_room_page.dart` 与 `lib/waiting/widgets/*.dart`：等待室滚动策略、长文本和触控区。
- **Modify** `modules/duel_room1/lib/field/duel_field_page.dart`、`lib/field/duel_flame_game.dart`、`lib/field/util/ui_scale.dart`：统一 HUD 规格和 Flame 相机可见区。
- **Modify** `modules/duel_room1/lib/field/widgets/docked_panel_shell.dart`、`inspector/*.dart`、`confirm/*.dart`：响应式停靠、网格列数、边界夹紧和关闭命中区。
- **Modify** `modules/duel_room1/lib/field/widgets/selector/*.dart`：共用面板约束、内部滚动和自适应选项布局。
- **Modify** `modules/duel_room1/lib/field/widgets/menus/*.dart`：菜单宽高约束、滚动和安全区避让。
- **Modify** `modules/duel_room1/lib/duel_result_page.dart`：安全区、固定操作区和长文本处理。

## 实施纪律

- 每项生产代码前先运行对应失败测试，严格执行 RED → GREEN → REFACTOR。
- 命令均以仓库根目录为工作目录；模块测试使用 `flutter test modules/duel_room1/test/<file>.dart`。
- 每个任务提交前运行 `dart format`、任务定向测试和 `flutter analyze modules/duel_room1`。
- 只提交任务列出的路径，不带入并行工作产生的其他改动。

---

### Task 1: 建立统一布局规格与测试工具

**Files:**
- Create: `modules/duel_room1/lib/layout/duel_room_layout.dart`
- Create: `modules/duel_room1/test/duel_room_layout_test.dart`
- Create: `modules/duel_room1/test/responsive_test_harness.dart`
- Modify: `modules/duel_room1/lib/field/util/ui_scale.dart`
- Modify: `modules/duel_room1/test/ui_scale_test.dart`

- [ ] **Step 1: 写档位、缩放、安全区和网格列数失败测试**

创建 `duel_room_layout_test.dart`，覆盖精确边界和四个验收尺寸：

```dart
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuelRoomLayoutSpec', () {
    test('按安全区后的可用尺寸选择档位', () {
      expect(DuelRoomLayoutSpec.resolve(const Size(640, 360)).sizeClass,
          DuelRoomSizeClass.compact);
      expect(DuelRoomLayoutSpec.resolve(const Size(800, 450)).sizeClass,
          DuelRoomSizeClass.compact);
      expect(DuelRoomLayoutSpec.resolve(const Size(1280, 720)).sizeClass,
          DuelRoomSizeClass.regular);
      expect(DuelRoomLayoutSpec.resolve(const Size(1920, 1080)).sizeClass,
          DuelRoomSizeClass.wide);
      expect(DuelRoomLayoutSpec.resolve(const Size(1024, 600)).sizeClass,
          DuelRoomSizeClass.regular);
      expect(DuelRoomLayoutSpec.resolve(const Size(1600, 900)).sizeClass,
          DuelRoomSizeClass.wide);
    });

    test('安全区不可压缩且内容尺寸不为负', () {
      final spec = DuelRoomLayoutSpec.resolve(
        const Size(640, 360),
        safePadding: const EdgeInsets.fromLTRB(44, 0, 21, 16),
      );
      expect(spec.safeRect, const Rect.fromLTWH(44, 0, 575, 344));
      expect(spec.dialogMaxSize.width, greaterThan(0));
      expect(spec.dialogMaxSize.height, greaterThan(0));
    });

    test('网格列数不以缩小卡片换取固定列数', () {
      expect(DuelRoomLayoutSpec.resolve(const Size(640, 360)).gridColumns, 2);
      expect(DuelRoomLayoutSpec.resolve(const Size(800, 450)).gridColumns, 3);
      expect(DuelRoomLayoutSpec.resolve(const Size(1280, 720)).gridColumns, 4);
    });

    test('非法视口返回可布局的安全值', () {
      final spec = DuelRoomLayoutSpec.resolve(Size.zero);
      expect(spec.viewport, const Size(1, 1));
      expect(spec.hudScale, 1.0);
      expect(spec.safeRect.width, 1.0);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/duel_room_layout_test.dart`

Expected: FAIL，提示 `layout/duel_room_layout.dart` 或 `DuelRoomLayoutSpec` 不存在。

- [ ] **Step 3: 实现纯规格与作用域**

`duel_room_layout.dart` 定义以下公开契约；数值集中于该文件，不再散落新的平台判断：

```dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

enum DuelRoomSizeClass { compact, regular, wide }

@immutable
class DuelRoomLayoutSpec {
  const DuelRoomLayoutSpec._({
    required this.viewport,
    required this.safePadding,
    required this.safeRect,
    required this.sizeClass,
    required this.hudScale,
    required this.pagePadding,
    required this.dialogMaxSize,
    required this.dockedPanelWidth,
    required this.gridColumns,
  });

  final Size viewport;
  final EdgeInsets safePadding;
  final Rect safeRect;
  final DuelRoomSizeClass sizeClass;
  final double hudScale;
  final double pagePadding;
  final Size dialogMaxSize;
  final double dockedPanelWidth;
  final int gridColumns;

  bool get isCompact => sizeClass == DuelRoomSizeClass.compact;
  double get minimumTapExtent => 44;
  double get topHudHeight => 52 * hudScale;
  double get handBarHeight => 96 * hudScale;
  double get panelGap => isCompact ? 8 : 18;

  factory DuelRoomLayoutSpec.resolve(
    Size rawViewport, {
    EdgeInsets safePadding = EdgeInsets.zero,
  }) {
    final viewport = Size(
      rawViewport.width > 0 ? rawViewport.width : 1,
      rawViewport.height > 0 ? rawViewport.height : 1,
    );
    final safeWidth = math.max(0.0,
        viewport.width - safePadding.horizontal);
    final safeHeight = math.max(0.0,
        viewport.height - safePadding.vertical);
    final sizeClass = safeWidth < 1024 || safeHeight < 600
        ? DuelRoomSizeClass.compact
        : safeWidth >= 1600 && safeHeight >= 900
            ? DuelRoomSizeClass.wide
            : DuelRoomSizeClass.regular;
    final hudScale = rawViewport.height <= 0
        ? 1.0
        : (safeHeight / 760).clamp(0.60, 1.0);
    final pagePadding = sizeClass == DuelRoomSizeClass.compact ? 8.0 : 18.0;
    final contentWidth = math.max(0.0, safeWidth - pagePadding * 2);
    final contentHeight = math.max(0.0, safeHeight - pagePadding * 2);
    final columns = safeWidth < 720 ? 2 : safeWidth < 1024 ? 3 : 4;
    return DuelRoomLayoutSpec._(
      viewport: viewport,
      safePadding: safePadding,
      safeRect: Rect.fromLTWH(
        safePadding.left,
        safePadding.top,
        safeWidth,
        safeHeight,
      ),
      sizeClass: sizeClass,
      hudScale: hudScale,
      pagePadding: pagePadding,
      dialogMaxSize: Size(math.min(860, contentWidth), contentHeight),
      dockedPanelWidth: math.min(
        sizeClass == DuelRoomSizeClass.compact ? 360 : 440,
        contentWidth,
      ),
      gridColumns: columns,
    );
  }
}

class DuelRoomLayout extends InheritedWidget {
  const DuelRoomLayout({super.key, required this.spec, required super.child});
  final DuelRoomLayoutSpec spec;

  static DuelRoomLayoutSpec of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuelRoomLayout>()?.spec ??
      DuelRoomLayoutSpec.resolve(
        MediaQuery.sizeOf(context),
        safePadding: MediaQuery.paddingOf(context),
      );

  @override
  bool updateShouldNotify(DuelRoomLayout oldWidget) => oldWidget.spec != spec;
}
```

让 `ui_scale.dart` 的旧 API 委托相同的 `760/0.60` 契约，保留现有调用方但不再扩展第二套规则。

- [ ] **Step 4: 增加统一尺寸测试工具并运行 GREEN**

`responsive_test_harness.dart` 提供唯一测试入口：

```dart
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const responsiveViewports = <Size>[
  Size(640, 360), Size(800, 450), Size(1280, 720), Size(1920, 1080),
];

Future<void> pumpResponsiveWidget(
  WidgetTester tester,
  Widget child,
  Size size, {
  EdgeInsets safePadding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, padding: safePadding),
      child: DuelRoomLayout(
        spec: DuelRoomLayoutSpec.resolve(size, safePadding: safePadding),
        child: Scaffold(body: child),
      ),
    ),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
}
```

Run: `dart format modules/duel_room1/lib/layout modules/duel_room1/test/duel_room_layout_test.dart modules/duel_room1/test/responsive_test_harness.dart && flutter test modules/duel_room1/test/duel_room_layout_test.dart modules/duel_room1/test/ui_scale_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add modules/duel_room1/lib/layout/duel_room_layout.dart modules/duel_room1/lib/field/util/ui_scale.dart modules/duel_room1/test/duel_room_layout_test.dart modules/duel_room1/test/responsive_test_harness.dart modules/duel_room1/test/ui_scale_test.dart
git commit -m "feat(duel_room1): add responsive layout specification"
```

---

### Task 2: 安装根布局作用域并适配等待/阶段面板

**Files:**
- Modify: `modules/duel_room1/lib/duel_room_page.dart`
- Modify: `modules/duel_room1/lib/waiting/waiting_room_page.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/hand_select_panel.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/select_hand.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/turn_select_panel.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/select_turn.dart`
- Create: `modules/duel_room1/test/waiting_responsive_test.dart`

- [ ] **Step 1: 写四档视口和 44dp 命中区失败测试**

在 `waiting_responsive_test.dart` 使用 `responsiveViewports` 循环 pump `HandSelectPanel`、`TurnSelectPanel` 和可独立构造的等待室子树，断言无 overflow；并断言三个猜拳 Key 与两个先后攻 Key 的 `tester.getSize()` 宽高至少 44。另加长标题/`textScaler: TextScaler.linear(1.3)` 用例。

```dart
for (final size in responsiveViewports) {
  testWidgets('猜拳在 $size 内可操作', (tester) async {
    await pumpResponsiveWidget(tester, HandSelectPanel(
      isResult: false, enabled: true, onSendHand: (_) {},
    ), size);
    for (final key in const ['hand-select-scissors', 'hand-select-rock', 'hand-select-paper']) {
      final hit = tester.getSize(find.byKey(ValueKey(key)));
      expect(hit.width, greaterThanOrEqualTo(44));
      expect(hit.height, greaterThanOrEqualTo(44));
    }
  });
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/waiting_responsive_test.dart`

Expected: FAIL，`640×360` 阶段面板或猜拳按钮命中尺寸不满足断言。

- [ ] **Step 3: 安装作用域并实现统一阶段面板宿主**

在 `duel_room_page.dart` 用 `LayoutBuilder` 与当前 `MediaQuery.padding` 构建 spec，再包裹原 `Stack`：

```dart
return LayoutBuilder(builder: (context, constraints) {
  final size = constraints.biggest;
  final spec = DuelRoomLayoutSpec.resolve(
    size,
    safePadding: MediaQuery.paddingOf(context),
  );
  return DuelRoomLayout(
    spec: spec,
    child: PopScope(/* 保留现有退出逻辑和 Scaffold */),
  );
});
```

新增私有 `_ResponsiveStagePanel`，使用 `SafeArea + Padding + Center + ConstrainedBox + SingleChildScrollView` 承载猜拳与先后攻；`maxWidth` 为 `min(520, spec.dialogMaxSize.width)`。结算存在时隐藏/禁用日志抽屉和按钮，并让结算层成为 Stack 最后一个子项；结算期间返回键直接返回，不叠加退出弹窗。日志按钮保持 36px 视觉，但外层 `SizedBox.square(dimension: 44)`。

- [ ] **Step 4: 改造等待室与阶段按钮**

`waiting_room_page.dart` 使用 `DuelRoomLayout.of(context).safeRect` 和 `pagePadding`，保持“滚动内容 + 固定控制条”；若 `spec.isCompact`，把控制条放进同一个 `SingleChildScrollView`，确保极低高度不会由固定控制条挤出 overflow。

`select_hand.dart` 和 `select_turn.dart` 用 `Wrap(alignment: WrapAlignment.center)` 替代强制 `Row`，每个手势/按钮用 `ConstrainedBox(constraints: BoxConstraints(minWidth: 44, minHeight: 44))`。标题允许最多两行并居中。

- [ ] **Step 5: 运行 GREEN 与回归测试**

Run: `dart format modules/duel_room1/lib/duel_room_page.dart modules/duel_room1/lib/waiting modules/duel_room1/test/waiting_responsive_test.dart && flutter test modules/duel_room1/test/waiting_responsive_test.dart`

Expected: PASS，所有验收尺寸无 overflow，五个选择控件命中区达标。

- [ ] **Step 6: 提交**

```bash
git add modules/duel_room1/lib/duel_room_page.dart modules/duel_room1/lib/waiting modules/duel_room1/test/waiting_responsive_test.dart
git commit -m "feat(duel_room1): adapt room overlays for compact screens"
```

---

### Task 3: 修复等待室长文本与控制区适配

**Files:**
- Modify: `modules/duel_room1/lib/waiting/widgets/playerslot.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/deck_selector.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/control_bar.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/automation_switch.dart`
- Modify: `modules/duel_room1/lib/waiting/widgets/side_decking_panel.dart`
- Modify: `modules/duel_room1/test/waiting_responsive_test.dart`

- [ ] **Step 1: 写长内容和高文字倍率失败测试**

增加以下真实风险用例：60 字玩家名且带房主/踢人、80 字卡组名、80 字换备卡名、长错误状态、`TextScaler.linear(1.3)`。分别在 `640×360` 与 `800×450` 宽度 pump，并断言 `tester.takeException()` 为 null；踢人按钮和 Switch 整体命中高度至少 44。

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/waiting_responsive_test.dart`

Expected: FAIL，至少一个长文本 Row overflow 或点击区域不足。

- [ ] **Step 3: 最小化修复各子组件**

- `playerslot.dart`：玩家名包 `Expanded`，设 `maxLines: 1, overflow: TextOverflow.ellipsis`；房主徽章保留；踢人按钮外层 44px 命中区。
- `deck_selector.dart`：已选项和菜单项统一单行省略；编辑按钮宽度不足时由父 `Wrap` 换行。
- `control_bar.dart`：按钮宽度使用 `min(120, constraints.maxWidth)`，保持最小高度 44；已有两个 Wrap 不改视觉。
- `automation_switch.dart`：整体用 `ConstrainedBox(minHeight: 44)`，文字用 `Flexible`，不使用缩小命中区的 `shrinkWrap`。
- `side_decking_panel.dart`：卡名 chip 宽度限制为当前约束；状态文字用 `Expanded`；底部按钮由 Row 改 Wrap，窄屏时换行。

省略契约统一使用：

```dart
Text(value, maxLines: 1, overflow: TextOverflow.ellipsis)
```

- [ ] **Step 4: 运行 GREEN**

Run: `dart format modules/duel_room1/lib/waiting/widgets modules/duel_room1/test/waiting_responsive_test.dart && flutter test modules/duel_room1/test/waiting_responsive_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add modules/duel_room1/lib/waiting/widgets modules/duel_room1/test/waiting_responsive_test.dart
git commit -m "fix(duel_room1): prevent compact waiting room overflow"
```

---

### Task 4: 提取并应用 Flame 相机可见区几何

**Files:**
- Create: `modules/duel_room1/lib/field/util/camera_viewport_layout.dart`
- Create: `modules/duel_room1/test/camera_viewport_layout_test.dart`
- Modify: `modules/duel_room1/lib/field/duel_flame_game.dart`
- Modify: `modules/duel_room1/lib/field/duel_field_page.dart`
- Modify: `modules/duel_room1/lib/field/components/hand_card/hand_bar_component.dart`
- Modify: `modules/duel_room1/lib/field/components/phase_rail/phase_rail_component.dart`

- [ ] **Step 1: 写非对称安全区和 HUD 预留失败测试**

`camera_viewport_layout_test.dart` 直接测试纯函数；系统安全区不得被压缩，HUD 设计预留可压缩，输出可见 Rect 始终为非负：

```dart
test('左右刘海与上下 HUD 共同形成相机可见区', () {
  final layout = CameraViewportLayout.resolve(
    viewport: const Size(844, 390),
    safePadding: const EdgeInsets.fromLTRB(44, 0, 21, 16),
    hudInsets: const EdgeInsets.fromLTRB(0, 96, 0, 64),
  );
  expect(layout.visibleRect.left, 44);
  expect(layout.visibleRect.right, 823);
  expect(layout.visibleRect.top, greaterThanOrEqualTo(0));
  expect(layout.visibleRect.bottom, lessThanOrEqualTo(374));
});

test('极矮视口只压缩 HUD 不压缩安全区', () {
  final layout = CameraViewportLayout.resolve(
    viewport: const Size(640, 120),
    safePadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    hudInsets: const EdgeInsets.fromLTRB(0, 100, 0, 100),
  );
  expect(layout.visibleRect.left, 20);
  expect(layout.visibleRect.bottom, lessThanOrEqualTo(100));
  expect(layout.visibleRect.height, greaterThanOrEqualTo(1));
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/camera_viewport_layout_test.dart`

Expected: FAIL，文件/API 不存在。

- [ ] **Step 3: 实现纯相机布局并替换硬编码预留**

`CameraViewportLayout.resolve` 输入 viewport、不可压缩 `safePadding`、可压缩 `hudInsets`，输出 `visibleRect`、`center` 与可用宽高。HUD 总预留超过安全区内高度时，按比例压缩 HUD，但保留至少 1px 可见区。

`DuelFlameGame` 新增 `setLayoutSpec(DuelRoomLayoutSpec spec)`，替代只推 `setViewPadding` 的页面调用；`_applyImmersiveCamera()` 使用纯布局结果计算 zoom 与中心，减去左右安全区。最终用户 zoom 应满足：

```dart
final zoom = (_fitZoom * _userZoom).clamp(_minZoom, _maxZoom);
camera.viewfinder.zoom = zoom;
```

`DuelFieldPage` 从 `DuelRoomLayout.of(context)` 推规格，并用 `spec.topHudHeight`、`spec.handBarHeight` 计算对手手牌位置和紧凑模式；阶段轨道命中 Rect 最小扩展到 44px。手牌最大宽度减去左右安全区。

- [ ] **Step 4: 运行 GREEN 和现有 Flame 几何回归**

Run: `dart format modules/duel_room1/lib/field modules/duel_room1/test/camera_viewport_layout_test.dart && flutter test modules/duel_room1/test/camera_viewport_layout_test.dart modules/duel_room1/test/ui_scale_test.dart modules/duel_room1/test/phase_rail_layout_test.dart modules/duel_room1/test/slot_hit_area_test.dart modules/duel_room1/test/hand_fan_layout_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add modules/duel_room1/lib/field modules/duel_room1/test/camera_viewport_layout_test.dart modules/duel_room1/test/ui_scale_test.dart modules/duel_room1/test/phase_rail_layout_test.dart modules/duel_room1/test/slot_hit_area_test.dart modules/duel_room1/test/hand_fan_layout_test.dart
git commit -m "feat(duel_room1): fit duel camera to responsive safe viewport"
```

---

### Task 5: 适配停靠面板、详情抽屉和确认浮卡

**Files:**
- Modify: `modules/duel_room1/lib/field/widgets/docked_panel_shell.dart`
- Modify: `modules/duel_room1/lib/field/widgets/inspector/card_detail_drawer.dart`
- Modify: `modules/duel_room1/lib/field/widgets/inspector/zone_browser_panel.dart`
- Modify: `modules/duel_room1/lib/field/widgets/confirm/confirm_cards_panel.dart`
- Modify: `modules/duel_room1/lib/field/widgets/confirm/confirm_floating_card.dart`
- Modify: `modules/duel_room1/lib/field/widgets/confirm/duel_confirm_dialog.dart`
- Modify: `modules/duel_room1/lib/field/duel_field_page.dart`
- Modify: `modules/duel_room1/test/zone_browser_panel_test.dart`
- Modify: `modules/duel_room1/test/confirm_cards_panel_test.dart`
- Modify: `modules/duel_room1/test/confirm_floating_card_test.dart`
- Create: `modules/duel_room1/test/duel_confirm_dialog_test.dart`

- [ ] **Step 1: 写安全区、动态列数和边缘锚点失败测试**

在 `640×360`、`800×450`、带 `left=44/right=21/bottom=16` 安全区的 `844×390` 下断言面板 Rect 完全包含于 `spec.safeRect`。确认列表分别断言 2/3/4 列；浮卡锚点置于四角时断言其 Rect 不越界；详情关闭按钮尺寸至少 44。

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/zone_browser_panel_test.dart modules/duel_room1/test/confirm_cards_panel_test.dart modules/duel_room1/test/confirm_floating_card_test.dart modules/duel_room1/test/duel_confirm_dialog_test.dart`

Expected: FAIL，固定列数、固定 right/top/bottom 或浮卡越界断言失败。

- [ ] **Step 3: 统一停靠几何和面板互斥规则**

`DockedPanelShell` 从 `DuelRoomLayout.of(context)` 读取宽度、safePadding、top HUD 和 hand bar 高度；`right = safePadding.right + panelGap`，top/bottom 同样叠加不可压缩安全区。暴露 `gridColumns` 给子组件，不再保留固定 4 列常量。

`ZoneBrowserPanel` 与 `ConfirmCardsPanel` 使用 `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: spec.gridColumns)`。`compact` 下确认面板优先于区域浏览面板；父 `DuelFieldPage` 在确认列表显示时不同时构建区域面板，但保留 provider 状态，关闭确认后区域面板可恢复。

- [ ] **Step 4: 修复详情抽屉和浮卡边界**

详情抽屉 left/top/bottom 全部由 spec 计算，compact 底边必须包含 `safePadding.bottom + handBarHeight + 8`；关闭按钮外层改 44px。

在 `duel_confirm_dialog.dart` 增加纯函数 `clampFloatingCardRect` 并用于 Positioned：

```dart
Rect clampFloatingCardRect(Rect desired, Rect safeRect) {
  final width = desired.width.clamp(0.0, safeRect.width);
  final height = desired.height.clamp(0.0, safeRect.height);
  final left = desired.left.clamp(safeRect.left, safeRect.right - width);
  final top = desired.top.clamp(safeRect.top, safeRect.bottom - height);
  return Rect.fromLTWH(left, top, width, height);
}
```

浮卡视觉尺寸在 compact 下按 spec 缩放，但关闭命中区固定至少 44。

- [ ] **Step 5: 运行 GREEN**

Run: `dart format modules/duel_room1/lib/field/widgets modules/duel_room1/lib/field/duel_field_page.dart modules/duel_room1/test && flutter test modules/duel_room1/test/zone_browser_panel_test.dart modules/duel_room1/test/confirm_cards_panel_test.dart modules/duel_room1/test/confirm_floating_card_test.dart modules/duel_room1/test/duel_confirm_dialog_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add modules/duel_room1/lib/field/widgets modules/duel_room1/lib/field/duel_field_page.dart modules/duel_room1/test/zone_browser_panel_test.dart modules/duel_room1/test/confirm_cards_panel_test.dart modules/duel_room1/test/confirm_floating_card_test.dart modules/duel_room1/test/duel_confirm_dialog_test.dart
git commit -m "feat(duel_room1): make duel side panels responsive"
```

---

### Task 6: 建立响应式选择器面板并迁移全部选择器

**Files:**
- Create: `modules/duel_room1/lib/layout/responsive_panel.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/announce_choice_dialog.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/announce_card_dialog.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/duel_select_prompt.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/yes_no_dialog.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/card_selector.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/position_selector.dart`
- Modify: `modules/duel_room1/lib/field/widgets/selector/counter_select_dialog.dart`
- Modify: `modules/duel_room1/test/card_selector_test.dart`
- Create: `modules/duel_room1/test/selector_responsive_test.dart`

- [ ] **Step 1: 写全部 selector 尺寸矩阵失败测试**

为七种 selector 构造最小真实 `SelectState`，循环四个验收尺寸并断言无 overflow、主要按钮存在且在安全区。补充：PositionSelector 1/2/4 项、长标签；CardSelector 20 张与长 option；CounterSelectDialog 10 张；YesNo 长消息；AnnounceChoice 长标题/长选项；AnnounceCard 软键盘 `viewInsets.bottom=180`。

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/selector_responsive_test.dart modules/duel_room1/test/card_selector_test.dart`

Expected: FAIL，PositionSelector clamp、CardSelector 固定 tile 或低高度 Dialog overflow。

- [ ] **Step 3: 实现共用 ResponsivePanel**

共用壳保持现有颜色/圆角/阴影，接口明确分离标题、可滚动内容和固定 actions：

```dart
class ResponsivePanel extends StatelessWidget {
  const ResponsivePanel({
    super.key,
    required this.maxWidth,
    required this.header,
    required this.body,
    this.actions,
  });
  final double maxWidth;
  final Widget header;
  final Widget body;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    return SafeArea(child: Padding(
      padding: EdgeInsets.all(spec.pagePadding),
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(0, spec.dialogMaxSize.width),
          maxHeight: spec.dialogMaxSize.height,
        ),
        child: DecoratedBox(
          decoration: responsivePanelDecoration,
          child: Padding(
            padding: EdgeInsets.all(spec.isCompact ? 12 : 20),
            child: Column(children: [
              header,
              const SizedBox(height: 12),
              Expanded(child: body),
              if (actions != null) ...[
                const SizedBox(height: 12), actions!,
              ],
            ]),
          ),
        ),
      )),
    ));
  }
}
```

- [ ] **Step 4: 逐个迁移选择器**

- `CardSelector`：tile 不再固定 100px；使用 `LayoutBuilder` 让 tile 填满 grid cell，列数来自 spec，卡图 `AspectRatio(59/86)`。
- `PositionSelector`：删除下界大于上界的 `clamp`；宽度不足时横滚，item 高度用约束夹紧，标签最多两行。
- `CounterSelectDialog`：列表行在 compact 使用较小卡图，步进按钮仍 44px；`didUpdateWidget` 在 options 长度变化时重建 counts。
- `YesNoDialog`：卡图区域可收缩，消息进入滚动 body，按钮固定。
- `AnnounceChoiceDialog`：单个长选项限制到内容宽度并换行。
- `AnnounceCardDialog`：搜索框和列表置于 body，使用 `MediaQuery.viewInsets.bottom` 后的有效高度。
- `DuelSelectPrompt`：移除 modal 外层重复 padding；place/inline 位置使用 spec，inline 提示用 Flexible，按钮 Wrap。

- [ ] **Step 5: 运行 GREEN**

Run: `dart format modules/duel_room1/lib/layout/responsive_panel.dart modules/duel_room1/lib/field/widgets/selector modules/duel_room1/test/selector_responsive_test.dart modules/duel_room1/test/card_selector_test.dart && flutter test modules/duel_room1/test/selector_responsive_test.dart modules/duel_room1/test/card_selector_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add modules/duel_room1/lib/layout/responsive_panel.dart modules/duel_room1/lib/field/widgets/selector modules/duel_room1/test/selector_responsive_test.dart modules/duel_room1/test/card_selector_test.dart
git commit -m "feat(duel_room1): adapt all duel selectors responsively"
```

---

### Task 7: 约束操作菜单并适配结算页

**Files:**
- Modify: `modules/duel_room1/lib/field/widgets/menus/hand_action_menu.dart`
- Modify: `modules/duel_room1/lib/field/widgets/menus/hand_action_popover.dart`
- Modify: `modules/duel_room1/lib/field/widgets/menus/field_action_popover.dart`
- Modify: `modules/duel_room1/lib/field/widgets/menus/phase_action_menu.dart`
- Modify: `modules/duel_room1/lib/field/widgets/menus/duel_field_popover_layout.dart`
- Modify: `modules/duel_room1/lib/duel_result_page.dart`
- Create: `modules/duel_room1/test/action_menu_responsive_test.dart`
- Create: `modules/duel_room1/test/duel_result_responsive_test.dart`

- [ ] **Step 1: 写菜单与结算页失败测试**

菜单用 20 个长 action label，在 `640×360` 和 `800×450` 下断言菜单 Rect 位于安全区、可滚动且每项命中高度至少 44；空 actions 不留下箭头。结算页构造胜/负/平/观战和 80 字玩家名，在四个尺寸下断言无 overflow、主按钮始终可见、玩家名省略且 LP 可见。

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test modules/duel_room1/test/action_menu_responsive_test.dart modules/duel_room1/test/duel_result_responsive_test.dart`

Expected: FAIL，固定 220px 菜单高度无约束或结算页低高度 overflow。

- [ ] **Step 3: 适配操作菜单**

菜单宽度改为 `min(220, spec.safeRect.width - 2 * spec.pagePadding)`；高度限制为安全内容区的 70%，actions 使用 `ListView(shrinkWrap: true)`；每项 `minimumSize.height = 44`。`HandActionPopover` 无 actions 时直接返回 `SizedBox.shrink()`，箭头宽度从实际菜单宽度计算。fallback `fieldCardAnchor` 对 sequence 先 clamp，并把结果限制到 safeRect。

- [ ] **Step 4: 迁移结算页到 ResponsivePanel**

标题/结果信息进入可滚动 body，主按钮进入固定 actions；`_ResultRow` 的名称为单行省略，LP 不收缩；增加稳定 Key：

```dart
const ValueKey('duel-result-panel')
const ValueKey('duel-result-action')
```

保留现有结果判断、换备 dismiss 和返回首页逻辑，不改业务行为。

- [ ] **Step 5: 运行 GREEN**

Run: `dart format modules/duel_room1/lib/field/widgets/menus modules/duel_room1/lib/duel_result_page.dart modules/duel_room1/test/action_menu_responsive_test.dart modules/duel_room1/test/duel_result_responsive_test.dart && flutter test modules/duel_room1/test/action_menu_responsive_test.dart modules/duel_room1/test/duel_result_responsive_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add modules/duel_room1/lib/field/widgets/menus modules/duel_room1/lib/duel_result_page.dart modules/duel_room1/test/action_menu_responsive_test.dart modules/duel_room1/test/duel_result_responsive_test.dart
git commit -m "feat(duel_room1): adapt action menus and duel results"
```

---

### Task 8: 全矩阵回归、静态检查与人工验收

**Files:**
- Modify only if failures require scoped fixes: `modules/duel_room1/lib/**/*.dart`
- Modify only if assertions need coverage: `modules/duel_room1/test/**/*.dart`

- [ ] **Step 1: 运行模块全部测试**

Run: `flutter test modules/duel_room1/test`

Expected: PASS，输出无 overflow、异常或失败测试。

- [ ] **Step 2: 运行静态检查与格式检查**

Run: `dart format --output=none --set-exit-if-changed modules/duel_room1/lib modules/duel_room1/test && flutter analyze modules/duel_room1`

Expected: 两条命令 exit 0，无 analyzer issue。

- [ ] **Step 3: 运行宿主应用关键流程测试**

Run: `flutter test apps/uniygopro/integration_test/ai_room_flow_test.dart`

Expected: PASS；进入房间、准备、猜拳、选择先后攻和进入决斗的既有流程无行为回归。若本机缺少集成测试所需设备或服务，记录具体阻塞信息，不以单元测试替代该结论。

- [ ] **Step 4: 人工尺寸矩阵验收**

分别在 `640×360` 手机原生横屏、PC Web `800×450`、桌面 `1280×720` 与 `1920×1080` 验证：等待室、猜拳、先后攻、对局 HUD、卡片详情、区域浏览、确认列表、所有 selector、操作菜单、结算页。检查无黄黑 overflow、主要按钮始终可见、刘海/Home 指示条不遮挡、桌面大尺寸视觉基本不变。

- [ ] **Step 5: 检查最终差异**

Run: `git diff --check && git status --short && git diff --stat`

Expected: `git diff --check` 无输出；状态只包含本计划预期文件或用户已有的无关改动。

- [ ] **Step 6: 提交最终回归修正（仅当本任务产生修正）**

```bash
git add modules/duel_room1/lib modules/duel_room1/test
git commit -m "test(duel_room1): cover responsive viewport matrix"
```
