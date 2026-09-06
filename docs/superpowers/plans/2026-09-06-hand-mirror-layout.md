# 双方手牌镜像排布实施计划

> REQUIRED SUB-SKILL: subagent-driven-development / executing-plans。Steps use checkbox syntax.

**Goal:** 对方手牌成为我方手牌关于屏幕水平中线的严格镜像（倾斜角反号 + 顶/底边距相等）。

**Architecture:** 纯几何改动：HandFanLayout 负责扇形角度语义，HandBarComponent 负责垂直定位；
hudTopY 链路整体移除，依赖方（toast 锚点、cardSlotRect 兜底）改为镜像公式的对应物。

**Tech Stack:** Flutter / Flame / flutter_test。

设计文档：docs/superpowers/specs/2026-09-06-hand-mirror-layout-design.md

---

### Task 1: HandFanLayout.angleAt 镜像语义（倾斜角反号）

**Files:**
- Modify: modules/duel_room1/lib/field/util/hand_fan_layout.dart:80-82
- Test: modules/duel_room1/test/hand_fan_layout_test.dart:64-77

- [x] Step 1: 改测试为镜像断言（先失败）：
  - mirrored.angleAt(count-1-i) == -normal.angleAt(i)（视觉同位反号）；
  - mirrored.angleAt(i) == normal.angleAt(i)（公式与方向无关）；
  - centerDx / centerAt.dy / arcLift 对称性断言保留。
- [x] Step 2: 跑 `flutter test test/hand_fan_layout_test.dart`，确认镜像角度断言失败。
- [x] Step 3: 实现：angleAt 去掉 _direction；更新 doc 注释（mirrored = 上下镜像语义）。
- [x] Step 4: 重跑测试全绿。

### Task 2: HandBarComponent baseLineY 严格镜像

**Files:**
- Modify: modules/duel_room1/lib/field/components/hand_card/hand_bar_component.dart（_relayout + cardSlotRect 兜底）
- Modify: modules/duel_room1/lib/field/util/hand_fan_layout.dart（HandBarViewportGeometry.selfBottomInset → edgeInset）
- Test: modules/duel_room1/test/hand_mirror_layout_test.dart（新建）
- Test: modules/duel_room1/test/hand_fan_layout_test.dart（geometry 断言改名）

- [x] Step 1: 新建测试：静态纯函数 baseLineYFor(isSelfSide, viewportHeight, edgeInset)，
  断言恒等式 viewportHeight - opp == self（edgeInset=0 与 16 两组）→ 先失败。
- [x] Step 2: 实现静态纯函数并让 _relayout 调用；geometry 字段改名 edgeInset；
  cardSlotRect 兜底 `isSelfSide ? size.y - 50 : 50`。
- [x] Step 3: 跑 duel_room1 全部测试，确认绿。

### Task 3: 移除 hudTopY 链路

**Files:**
- Modify: hand_bar_component.dart（hudTopY / setHudTopY / 注释）
- Modify: duel_field_game.dart:131-132, 172, 238-245（_oppHandTopY / setOppHandTopY）
- Modify: duel_field_page.dart:79-87, 176-178, 324（_opponentHandGap / _oppHandTopY / 调用点）

- [x] Step 1: 删除字段/方法/调用点（重构，行为已由 Task 2 接手）。
- [x] Step 2: `dart analyze` 与模块测试绿。

### Task 4: LP toast 对方锚点镜像

**Files:**
- Modify: modules/duel_room1/lib/field/components/lp/lp_change_toast_component.dart:43-60

- [x] Step 1: 对方分支改为 viewPadding.bottom + barVisualH + bottomPadding + _gap + halfH
  （我方公式的水平镜像，删除对 hudTopY 的读取与相关注释）。
- [x] Step 2: `dart analyze` + 模块测试绿。

### Task 5: 全量验证

- [x] `cd modules/duel_room1 && flutter test && dart analyze`（无 warning）。
- [x] 人工/截图确认：对方扇形与我方倒影一致、顶底间距相等。
