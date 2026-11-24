# App 页面流程与多端响应式设计

日期：2026-10-29
状态：已批准（用户确认「确认，开始实施」）

## 背景

当前 `apps/uniygopro` 只有一个全局等比缩放入口：

- `app.dart` 用 `FittedBox(fit: BoxFit.fill)` 把整棵树按 `kAppDesignSize = 1280×800` 布局后拉伸到实际窗口；
- `_DesignMediaQuery` 把 `MediaQuery` 强制改写为 1280×800、insets 全零。

后果：

1. 所有 `MediaQuery.sizeOf` 读到的都是常量，页面内部的断点（`card_live_page` 的 700、`deck_editor_page` 的 600、`deck_square_page` 的 1200/900/600）在真机上全部失效。
2. `BoxFit.fill` 对非 16:10 屏幕（如 2340×1080、2560×1600）产生非等比变形，圆形被拉成椭圆、卡图模糊。
3. 窗口从小屏拉到大屏，信息密度不变 —— 大屏只是把 1280×800 放大，没有利用多出来的空间。

同时产品层面缺失首启链路：

- 无开屏页，`main.dart` 直接 `runApp`。
- 无独立登录页，只有一个 `showMyCardLoginDialog` 弹窗，按需在匹配/上传时弹出。
- 首页是纵向 8 张服务器卡片的 `ListView`，不是主流手游的「游戏大厅」形态。
- 卡组能力分散在 `/deck-hub`（市场 + 我的卡组）与 `/deck-editor`（组卡器）两个独立路由。

## 目标

1. 建立 **开屏页 → 登录页 → 大厅（首页） → 决斗 / 卡组 / 观战 / 我的 → 结算** 的完整页面链路。
2. 移除全局等比缩放，改为**真实分辨率下的响应式自适应**：移动端横屏触控优先，桌面端利用更大空间承载更多信息。
3. 移动端与桌面端共享同一套页面实现，只由断点驱动结构差异（导航形态、栏数、信息密度）。

## 目标范围

### 支持平台

- Android / iOS 原生横屏（`lockAppLandscape` 保持），最低验收 `640×360`。
- PC 浏览器，最低验收 `800×450`。
- macOS / Windows / Linux 桌面。

竖屏不在范围内（移动端已锁横屏）。

### 覆盖页面

- 开屏页、登录页、大厅壳与 4 个分区（决斗 / 卡组 / 观战 / 我的）。
- 决斗场地（`DuelRoomLayoutSpec` 真自适应）。
- 结算页（`duel_room1` 的 `DuelResultPage`、`duel_room3` 的 `DuelResultOverlay`）。

### 非目标

- 不改变对决业务逻辑、服务端协议、Riverpod 状态模型。
- 不重做 `HudTheme` 赛博视觉令牌（复用）。
- 不改变 Flame 棋盘的世界坐标常量（只在世界→屏幕映射链路上按真实分辨率重算相机几何）。
- 不为每个平台维护独立页面实现。

## 全局响应式架构

### 断点体系

与 `duel_room1/lib/layout/duel_room_layout.dart` 已有定义对齐，判定优先级从上到下，边界归入更大档：

| 档位 | 条件 | 典型设备 |
| --- | --- | --- |
| `compact` | 可用宽 `< 1024` 或可用高 `< 600` | 手机横屏 640×360 / 2340×1080（逻辑 780×360 级） |
| `regular` | 非 compact，且宽 `< 1600` 或高 `< 900` | 1280×720、1440×900、iPad 横屏 |
| `wide` | 宽 `>= 1600` 且高 `>= 900` | 1920×1080、2560×1600 |

「可用尺寸」= 真实 `MediaQuery.size` 减去 `padding`（安全区）。

### 新增 `AppLayoutSpec` / `AppLayout`

放在 `apps/uniygopro/lib/layout/app_layout.dart`：

```dart
enum AppLayoutTier { compact, regular, wide }

@immutable
class AppLayoutSpec {
  final AppLayoutTier tier;
  final Size viewport;        // 真实逻辑尺寸
  final EdgeInsets safePadding;
  final bool isTouch;         // 触控为主：移动端 / 平板
  final double pagePadding;   // compact 12 / regular 20 / wide 28
  final double gutter;        // 板块间距：12 / 16 / 22
  final double railWidth;     // 桌面导航栏：compact 64 / regular 88 / wide 104
  final int contentColumns;   // 大厅内容列数：1 / 2 / 3
  final double minTapExtent;  // 固定 44
  final double maxContentWidth; // wide 下内容区最大宽度，超出居中（1600）

  static AppLayoutSpec resolve(Size size, EdgeInsets padding);
  static const fallback = ...; // 零尺寸兜底，避免负约束
}
```

`AppLayout` 为 `InheritedWidget`，`AppLayout.of(context)` / `maybeOf`。注入点唯一：`MaterialApp.router` 的 `builder`。

### 移除等比缩放

- 删除 `kAppDesignSize`、`_ScaledApp`（`FittedBox`）、`_DesignMediaQuery`。
- `MaterialApp.router` 的 `builder` 改为：
  `AppLayoutScope(child: child)`（读真实 `MediaQuery`，不改写 size/padding）。
- 安全区处理下放到各页面：由 `AppLayoutSpec.safePadding` 提供，页面自行 `SafeArea` 或按 spec 留白。

### 触控与命中

- 所有可点区域有效命中 `>= 44dp`（`spec.minTapExtent`）。
- 桌面端鼠标悬停态保留；移动端无悬停依赖。
- 视觉元素可小于 44，但用透明 padding / `GestureDetector.behavior` 扩展命中区。

## 页面布局

### 1. 开屏页 `/splash`

职责：品牌展示 + 启动期初始化（读取账号持久化、预热图片解析器、恢复渲染偏好）。约 1.2s 或初始化完成后跳转。

```
┌──────────────────────────────────────────────┐
│                                              │
│              [LOGO / 标题]                    │
│                                              │
│         ─── 进度条 / 光晕动效 ───              │
│                                              │
│  版本号 vX.Y.Z（右下角）   健康检查点（左下角） │
└──────────────────────────────────────────────┘
```

| 档位 | 差异 |
| --- | --- |
| compact | LOGO 宽度 = `viewport.width * 0.42`，垂直居中偏上 8% |
| regular | LOGO 宽度 = `min(520, width * 0.34)` |
| wide | LOGO 宽度固定 `560`，四角装饰线展开 |

跳转规则：已存在有效登录态 → `/`（大厅）；否则 → `/login`。两者都允许用户后续在「我的」里登录。

### 2. 登录页 `/login`

游客可进（用户已确认）。独立页面而非弹窗。

```
compact / regular（竖切，单列居中）
┌──────────────────────────────────────────────┐
│ [返回]                            [游客进入]  │
│                                              │
│           ┌──────────────────┐                │
│           │  LOGO / 标题      │                │
│           │  用户名  [     ]  │                │
│           │  密码    [  👁 ]  │                │
│           │  ☑ 记住密码        │                │
│           │  [    登录    ]   │                │
│           │  错误提示区        │                │
│           └──────────────────┘                │
└──────────────────────────────────────────────┘

wide（左右分栏）
┌────────────────────┬─────────────────────────┐
│  左：品牌视觉 + 特色 │  右：登录表单（宽 420）  │
│  轮播/插画（60%）    │  居中，与左侧等高        │
└────────────────────┴─────────────────────────┘
```

- 复用现有表单控件与 `SharedPreferences` 键（`mycard_credentials`）。
- 保留原有 ValueKey：`mycard-login-username` / `mycard-login-password` / `mycard-login-error` / `mycard-login-remember` / `mycard-login-submit`。
- 「游客进入」按钮：直接 `context.go('/')`。
- 登录成功后：回到进入登录页前的目标（`state.extra` 记录 `from`），默认 `/`。
- 未登录时，竞技匹配、卡组上传等动作仍走 `requireMyCardAccount`，改为跳 `/login`（携带 `from`）而不是弹窗。

### 3. 大厅（首页 `/`）

游戏大厅式多板块主界面，4 个一级入口：**决斗 / 卡组 / 观战 / 我的**。

#### 导航形态

| 档位 | 导航 | 说明 |
| --- | --- | --- |
| compact | 底部 Tab（高 56，图标 + 10px 文字） | 横屏时贴底，左右分 4 等分 |
| regular | 左侧 Rail（宽 88，图标 + 文字） | 可折叠为 64 |
| wide | 左侧 Rail（宽 104）+ 顶部全局条 | 顶部条含搜索/通知/账号 |

`last visited tab` 持久化到 SharedPreferences（key `app_last_tab`），冷启恢复。

#### 「决斗」分区

```
wide
┌─────┬──────────────────────────────────────────────────────┐
│Rail │ 玩家信息条（头像/昵称/段位/金币）        [设置][通知]  │
│     ├──────────────────────────────────────────────────────┤
│ 决斗 │ ┌────────────────────────┐ ┌───────────────────────┐ │
│ 卡组 │ │  快速对战（主 CTA 大卡） │ │ 竞技匹配 / 娱乐匹配    │ │
│ 观战 │ │  最近使用的卡组 + 开始   │ │ 自由房间 / AI 对决     │ │
│ 我的 │ └────────────────────────┘ └───────────────────────┘ │
│     │ ┌──────────────────────────────────────────────────┐ │
│     │ │ 公告 / 活动 横向卡片流                            │ │
│     │ └──────────────────────────────────────────────────┘ │
└─────┴──────────────────────────────────────────────────────┘

regular：玩家条 + 快速对战（上），服务器入口 2×2（中），公告（下）
compact：玩家条（可折叠） + 快速对战大按钮（首屏）+ 服务器入口 2 列网格，纵向滚动
```

「快速对战」是唯一的巨型 CTA，展示最近卡组与「开始」；其余 8 个 `Server` 入口收敛为「对战模式」网格（保留 `ServerType` 枚举与全部文案）。

必须保留：`home-server-ai-room` key 挂在 AI 对决入口上；文案「竞技匹配 / 娱乐匹配 / 自由房间 / 残局房 / 开始匹配 / 加入房间 / 对战环境 / 开始人机对战 / 233 服 AI / 正在搜索对手...」不变。

#### 「卡组」分区

合入现有的卡组市场、我的卡组、组卡器，用分段控件切换：

```
┌─────────────────────────────────────────────────────┐
│ [市场] [我的卡组] [组卡器]                 [搜索]   │
├─────────────────────────────────────────────────────┤
│ 市场：DeckSquarePage（网格）                          │
│ 我的卡组：MyDecksPage（列表 + 新建/上传）              │
│ 组卡器：DeckEditorPage（三栏 / 单栏 自适应）           │
└─────────────────────────────────────────────────────┘
```

- 断点：`compact` 单栏（组卡器用 deck_editor1 现有移动布局）；`regular` 双栏；`wide` 三栏（240 / flex / 380 保持不变）。
- 顺带修复 deck_editor1 的「展开编辑」死按钮：`_isDrawerOpen` 要么接上抽屉，要么移除按钮。

#### 「观战」分区

竞技观战 / 娱乐观战两档，附房间列表与「最近观战」历史。数据源沿用 `SpectateRoomSheet` 能力。

#### 「我的」分区

账号卡（未登录时展示「登录 MyCard 账号」）、对局统计、设置入口（`ygo_settings`）、渲染器切换（2D / 3D）、关于与版本。

### 4. 决斗

`DuelRoomLayoutSpec.fixed` 改为按真实分辨率计算：

```dart
static DuelRoomLayoutSpec resolve(Size size, EdgeInsets safePadding);
```

- `duel_room_page.dart` 的注入点改为 `LayoutBuilder` + `DuelRoomLayoutSpec.resolve(constraints.biggest, MediaQuery.paddingOf(context))`。
- 三档派生量：`pagePadding`（12/18/24）、`dockedPanelWidth`（compact `min(360, w*0.42)` / regular 440 / wide 520）、`gridColumns`（2/4/5）、`dialogMaxSize`（`min(w*0.94, 860)` × `min(h*0.92, 764)`）、`topHudHeight`（44/52/56）、`handBarHeight`（72/96/108）。
- Flame 侧无需改世界坐标：`CameraViewportFit.resolve` 已按相机可用区域计算 `_fitZoom`，只确保传入的 safeRect 来自真实分辨率。
- 结算与等待室沿用 `ResponsivePanel`，其尺寸随 spec 变化。

### 5. 结算

`duel_room1/lib/duel_result_page.dart` 与 `duel_room3/lib/duel_result_overlay.dart` 统一信息层级：

```
┌────────────────────────────────────┐
│           [结果徽记 胜利/失败/平局]  │
│           你赢下了这场决斗           │
│  ──────────────────────────────     │
│  我方 LP 8000   对方 LP 0            │  ← 大屏展示 LP 条
│  ──────────────────────────────     │
│  原因：LP 归零 / 卡组抽尽 / 认输     │
│  ──────────────────────────────     │
│  [ 返回首页 ]  [ 再来一局 ]  [ 复盘 ] │
└────────────────────────────────────┘
```

- `wide` / `regular`：面板宽 520（room3）~ 560，双按钮并排，附 LP 条。
- `compact`：面板宽 `min(viewport.width * 0.9, 420)`，按钮纵向堆叠，最小高 48。
- 保留 `duel-result-panel` / `duel-result-action` key；换备阶段文案「进入换备阶段」保持不变。
- 胜利用 `HudTheme.gold`、失败用 `HudTheme.cyan`、平局用灰（room3 既有规则）。

## 数据流与错误处理

- `AppLayoutSpec` 纯派生自视口，不引入新业务状态；`LayoutBuilder` 触发的重算只影响布局。
- 视口为 0 或负时使用 `AppLayoutSpec.fallback`（1280×800 档），不产生负约束。
- 开屏页初始化失败（prefs 读取异常）时降级为游客态直接进大厅，不阻塞。
- 登录页错误沿用 `MyCardAccountApi` 的现有错误文案展示在 `mycard-login-error`。

## 测试策略

### 纯函数测试

- `AppLayoutSpec.resolve`：三档边界（1023/1024、599/600、1599/1600、899/900）与零尺寸兜底。
- `DuelRoomLayoutSpec.resolve`：同上，并断言 `dockedPanelWidth <= viewport.width`、`dialogMaxSize` 非负。

### Widget 尺寸矩阵

在 `640×360` / `800×450` / `1280×720` / `1920×1080` 下运行：

- 开屏页、登录页（含错误态）、大厅 4 个分区、结算页。
- 断言：无 overflow 异常；主按钮在安全区内且命中 `>= 44`；compact 下为底部 Tab、regular/wide 下为 Rail。

### 集成测试

`integration_test/app_flow_test.dart` 现有链路必须继续通过。保留全部既有 key 与中文文案（见「必须保留」清单）。

### 必须保留的 key 与文案

key：`home-server-ai-room`、`ai-room-start-local`、`ai-room-start-server233`、`duel-room-page`、`duel-room3-page`、`waiting-room-ready`、`waiting-room-content`、`waiting-room-controls`、`duel-result-panel`、`duel-result-action`、`side-decking-confirm`、`responsive-panel-safe-padding`、`responsive-panel-chrome`、`duel-room-back-button`、`duel-log-button`、`mycard-login-username`、`mycard-login-password`、`mycard-login-error`、`mycard-login-remember`、`mycard-login-submit`。

文案：`竞技匹配 / 娱乐匹配 / 自由房间 / 残局房 / 开始匹配 / 加入房间 / 对战环境 / 正在搜索对手... / 开始人机对战 / 233 服 AI / 卡组编辑器 / 登录 MyCard 账号 / 取消`。

## 实施顺序

1. `AppLayoutSpec` / `AppLayout` + `app.dart` 去 FittedBox（其余页面随后逐个修）。
2. 开屏页 → 登录页（路由 + 游客态）。
3. 大厅壳（导航 + 4 分区）替换 `/`，服务器入口收敛为决斗分区的模式网格。
4. 卡组分区整合（市场 / 我的卡组 / 组卡器分段）。
5. `DuelRoomLayoutSpec.resolve` 真自适应 + 注入点改造。
6. 结算页重设计（room1 + room3）。
7. `dart analyze` + Widget 尺寸矩阵 + 集成测试回归。

## 验收标准

- 4 个基准尺寸下无溢出与布局异常；窗口连续缩放无突跳。
- 移动端全部主操作命中 `>= 44dp`；桌面端在 1920×1080 下可见信息量明显多于 1280×720。
- 首启链路可走通：开屏 → 登录（或游客） → 大厅 → 决斗 → 结算 → 返回大厅。
- 集成测试全绿，既有 key 与文案零破坏。
- 非 16:10 屏幕不再出现几何变形。
