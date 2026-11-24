# 响应式冲刺设计评审（设计 + 叙事视角）

日期：2026-11-04
评审人：文策渊（design-strategist）
被评审 spec：`docs/superpowers/specs/2026-10-29-app-page-flow-responsive-design.md`（已批准，未跟踪）
评审基线：`bee45df4` → `f3c109df`

## 0. 评审范围与方法

### 实际被评审的提交

| # | hash | 内容 |
| --- | --- | --- |
| 1 | `01ab21a0` | 响应式基线：AppLayout + 开屏/登录/大厅壳 + 决斗真自适应 |
| 2 | `238e0868` | 结算页统一（room1 + room3） |
| 3 | `4866545a` | `main()` 调用 `restore()`（范围外热修） |
| 4 | `c12a2ef9` | 卡组三段式整合 |
| 5 | `f3c109df` | 换备阶段「返回首页」加弃权二次确认（**不在主理人给的 4 笔清单内**，见 §3-F） |

合计 21 文件改动，+3547 / −486（≥ 主理人清单）。第 5 笔提交在我开始评审时已进入 main，故纳入评审。

### 工作区未收尾状态（评审时点）

- `apps/uniygopro/pubspec.yaml` 有未提交改动（dev_dependencies 增 `flutter_riverpod`，注释说明「仅测试用：尺寸矩阵需包一层 ProviderScope」）。
- 3 个新增测试文件**未被 git 跟踪**：
  - `apps/uniygopro/test/layout/app_layout_test.dart`
  - `apps/uniygopro/test/layout/duel_room_layout_test.dart`
  - `apps/uniygopro/test/widget/responsive_matrix_test.dart`

  spec 第 275-283 行的「纯函数测试 + Widget 尺寸矩阵」实体就在这三个文件里。**只提交已跟踪改动会把这批测试整批丢掉**，属于收尾级别的遗漏（不是设计问题，但必须在主理人提交前处理）。

### 方法说明与局限

逐条 `rg`/`Read`/`git show` 静态核对，所有结论附 `文件:行号`。
本机 `flutter_tester` 无法启动（`WebSocketException: Invalid WebSocket upgrade request`，3 个测试文件均加载失败），因此**没有拿到运行时证据**：溢出、命中区、动画类断言一律留给 S3 质量门（engineering-lead），本文只对「结构/契约/信息架构」下判断。凡属推断的，文中明确标注「静态判定，待运行时确认」。

---

## 1. 评审结论

**CONCERNS**

一句话理由：21 个 key 与 13 条文案**零丢失**（这是本冲刺最高优先级目标，达成），但开屏分流把「集成测试启动即见大厅」这一入口契约打断了（P0，spec 第 287/310 行要求集成测试全绿）；同时 spec 第 308 行的信息密度验收项**未达成**——`regular` 与 `wide` 的决斗分区结构完全相同，1920×1080 只是把 1280×720 的卡片放大，没有变多。

评审项汇总：

| 项 | 结论 |
| --- | --- |
| A 契约零破坏（key / 文案） | **PASS**（20/20 key ✓、13/13 文案 ✓），但入口链路契约 **CONCERNS** |
| B 大厅 4 分区与导航形态 | **CONCERNS**（导航形态对；`app_last_tab` 未实现；观战/我的分区内容不全） |
| C 卡组三段式 | **PASS**（断点与死按钮均按 spec 落地），附 2 条设计债 |
| D 结算页 | **PASS**（含 1 条已批准偏差） |
| E 信息密度验收 | **FAIL（未达标）**（产品判断：不是信息变多，是卡片变大） |
| F 范围蔓延 | **CONCERNS**（1 笔方向相反的改动 + 1 笔 spec 未回写的交互 + 收尾遗漏） |

---

## 2. 契约零破坏核对表

### 2.1 计数勘误（先纠两个数）

主理人派单说「21 个 key + 12 条文案」，spec 原文实际是：

- 第 291 行：**20 个 key**（逐个数：home-server-ai-room、ai-room-start-local、ai-room-start-server233、duel-room-page、duel-room3-page、waiting-room-ready、waiting-room-content、waiting-room-controls、duel-result-panel、duel-result-action、side-decking-confirm、responsive-panel-safe-padding、responsive-panel-chrome、duel-room-back-button、duel-log-button、mycard-login-username、mycard-login-password、mycard-login-error、mycard-login-remember、mycard-login-submit）。
- 第 293 行：**13 条文案**（竞技匹配 / 娱乐匹配 / 自由房间 / 残局房 / 开始匹配 / 加入房间 / 对战环境 / 正在搜索对手... / 开始人机对战 / 233 服 AI / 卡组编辑器 / 登录 MyCard 账号 / 取消）。

两者各差 1。下文按 spec 原文 20 + 13 逐条核对（多核对一条不会漏，但数字要有据可查）。

### 2.2 Key 核对（20/20 ✓，0 ✗）

| # | key | 结论 | 位置（lib 内） |
| --- | --- | --- | --- |
| 1 | `home-server-ai-room` | ✓ | `apps/uniygopro/lib/pages/home_page.dart:622-624`（挂在 `_ModeTile` 的 InkWell 上，仅 `ServerType.aiRoom` 分支） |
| 2 | `ai-room-start-local` | ✓ | `apps/uniygopro/lib/pages/create_room/ai_room_sheet.dart` |
| 3 | `ai-room-start-server233` | ✓ | `apps/uniygopro/lib/pages/create_room/ai_room_sheet.dart` |
| 4 | `duel-room-page` | ✓ | `modules/duel_room1/lib/duel_room_page.dart`、`modules/duel_room2/lib/duel_room_page.dart` |
| 5 | `duel-room3-page` | ✓ | `modules/duel_room3/lib/duel_room_page.dart` |
| 6 | `waiting-room-ready` | ✓ | `modules/duel_room1/lib/waiting/waiting_room_page.dart`（+ room2 `waiting/widgets/control_bar.dart`） |
| 7 | `waiting-room-content` | ✓ | `modules/duel_room1/lib/waiting/waiting_room_page.dart` |
| 8 | `waiting-room-controls` | ✓ | `modules/duel_room1/lib/waiting/waiting_room_page.dart` |
| 9 | `duel-result-panel` | ✓ | `modules/duel_room1/lib/duel_result_page.dart:221`、`modules/duel_room3/lib/duel_result_overlay.dart:219` |
| 10 | `duel-result-action` | ✓ | `duel_result_page.dart:179`、`duel_result_overlay.dart:169` |
| 11 | `side-decking-confirm` | ✓ | `duel_room1` / `duel_room2` / `duel_room3` 三份 `waiting/widgets/side_decking_panel.dart` |
| 12 | `responsive-panel-safe-padding` | ✓ | `modules/duel_room1/lib/layout/responsive_panel.dart`（本冲刺未改此文件） |
| 13 | `responsive-panel-chrome` | ✓ | 同上 |
| 14 | `duel-room-back-button` | ✓ | `modules/duel_room1/lib/duel_room_page.dart` |
| 15 | `duel-log-button` | ✓ | `modules/duel_room1/lib/duel_room_page.dart` |
| 16 | `mycard-login-username` | ✓ | `apps/uniygopro/lib/pages/login_page.dart:252` **与** `widgets/mycard_login_dialog.dart:146`（两处，见 §3-F 双实现） |
| 17 | `mycard-login-password` | ✓ | `login_page.dart:266` + `mycard_login_dialog.dart:160` |
| 18 | `mycard-login-error` | ✓ | `login_page.dart:290` + `mycard_login_dialog.dart:184` |
| 19 | `mycard-login-remember` | ✓ | `login_page.dart:298` + `mycard_login_dialog.dart:191` |
| 20 | `mycard-login-submit` | ✓ | `login_page.dart:324` + `mycard_login_dialog.dart:223` |

### 2.3 文案核对（13/13 ✓，0 ✗）

| # | 文案 | 结论 | 位置 |
| --- | --- | --- | --- |
| 1 | 竞技匹配 | ✓ | `config/servers.dart:144`（displayName，经 `_ModeTile` 渲染）+ `create_room/match_page.dart:100` |
| 2 | 娱乐匹配 | ✓ | `config/servers.dart:154` + `match_page.dart:105` |
| 3 | 自由房间 | ✓ | `config/servers.dart:183` + `widgets/create_room/free_room_sheet.dart:161` |
| 4 | 残局房 | ✓ | `config/servers.dart:199` |
| 5 | 开始匹配 | ✓ | `pages/create_room/match_join_sheet.dart:142` |
| 6 | 加入房间 | ✓ | `widgets/create_room/join_room_form.dart:195`、`free_room_sheet.dart:161` |
| 7 | 对战环境 | ✓ | `widgets/create_room/env_selector.dart:24` |
| 8 | 正在搜索对手... | ✓ | `pages/home_page.dart:155`（大厅搜索遮罩）+ `match_page.dart:92` |
| 9 | 开始人机对战 | ✓ | `widgets/create_room/join_room_form.dart:152`、`ai_room_sheet.dart:205` |
| 10 | 233 服 AI | ✓ | `ai_room_sheet.dart:23`（枚举文案，sheet 内可点） |
| 11 | 卡组编辑器 | ✓ | `modules/deck_editor1/lib/src/pages/deck_editor_page.dart:85`（AppBar 标题，双引号 `"卡组编辑器"`）+ `home_page.dart:444`（tooltip） |
| 12 | 登录 MyCard 账号 | ✓ | `login_page.dart:237`、`:388`、`home_page.dart:915`、`mycard_login_dialog.dart:131` |
| 13 | 取消 | ✓ | `login_page.dart:349`、`mycard_login_dialog.dart:220`、`deck_edit_panel.dart:165` 等 |

补充核对：以 `bee45df4` 的 `home_page.dart` 中文串集合与 HEAD 做差集，唯一消失的串是 `'卡组中心（市场/我的卡组/组卡）'`（旧 tooltip），不在保护清单内，且功能已被「卡组」Tab 取代 —— 判定不影响契约。

### 2.4 但存在「入口链路」级契约破坏（P0，详见 §4）

key 与文案本身完好，**但自动化回归跑不到它们了**。spec 第 287 行「`integration_test/app_flow_test.dart` 现有链路必须继续通过」与第 310 行「集成测试全绿」未达成：

- `config/route.dart:33` 把 `initialLocation` 改成 `Routes.splash`，`splash_page.dart:48-49` 在无登录态时 `go(Routes.login)`。
- 而 `integration_test/app_flow_test.dart:18-23`、`ai_room_flow_test.dart:30-37`、`ai_room_233_test.dart:26` 都是 `app.main()` → `pumpAndSettle()` → 直接找大厅控件（`find.text('竞技匹配')` / `find.byKey('home-server-ai-room')`）。
- `git diff bee45df4..HEAD -- apps/uniygopro/integration_test/` 为空 —— 7 个集成测试文件一个都没改。

静态判定（待运行时确认）：全新 prefs 下 App 首屏落在 `/login`，这 3 个用例的第一处断言/点击就会失败。这与 spec 的目标（建立首启链路）并不矛盾，**缺的是把测试也迁到新链路上**（先过开屏 → 游客进入 → 再断言大厅）。因为 `home-server-ai-room`、`ai-room-start-local`、`ai-room-start-server233` 等 key 的唯一自动化覆盖就在这 2 个 AI 流程用例里，链路一断，这些 key 等于失去了回归保护 —— 正是本清单最在意的风险。

---

## 3. 分节结论与证据

### B. 大厅 4 分区与导航形态 —— CONCERNS

**达成项**

| spec 要求 | 结论 | 证据 |
| --- | --- | --- |
| compact 底部 Tab，高 56，4 等分，图标 + 10px 文字 | ✓ | `app_layout.dart:105`（bottomTabHeight 56）、`home_page.dart:131-141`（compact 走 bottomNavigationBar）、`:283-297`（`Row` + 4×`Expanded` 等分）、`:322-329`（`fontSize: 10`） |
| regular 左侧 Rail 宽 88 | ✓ | `app_layout.dart:114`、`home_page.dart:113-124` |
| wide 左侧 Rail 宽 104 | ✓ | `app_layout.dart:126` |
| 4 个分区（决斗/卡组/观战/我的） | ✓ | `home_page.dart:66-71`（`_destinations`）、`:87-95`（`_pageFor` switch） |
| 8 个 Server 入口收敛为「对战模式」网格，文案与枚举保留 | ✓ | `ServerType` 8 项全在（`servers.dart:27-51`）；决斗分区 6 项（`home_page.dart:49-56` `_duelModeOrder`）+ 观战分区 2 项（`:792-798`）= 8，一个没丢；`home_page.dart:363` 分区标题「对战模式」 |
| 快速对战为唯一巨型 CTA | ✓ | `home_page.dart:489-560`（`_QuickBattleCard`，:541 key `quick-battle-start`；全页仅此一处 FilledButton 大卡） |

**未达成 / 缺失项**

1. **`app_last_tab` 持久化完全没做**（spec 第 178 行）。全仓库 `rg "app_last_tab|lastTab|last_tab"` **零命中**；`home_page.dart:73` 是裸的 `int _index = 0;`，冷启永远回「决斗」，而且没有 `SharedPreferences` 读写。这是 spec 明写的功能，属漏项而非取舍。
2. **Rail 不可折叠为 64**（spec 第 175 行「可折叠为 64」）。`_LobbyRail`（`home_page.dart:182-216`）没有折叠态、没有折叠按钮、没有宽度状态。
3. **wide 顶部全局条缺失**（spec 第 176 行「顶部条含搜索/通知/账号」）。三种档位共用同一个 `_PlayerBar`（`home_page.dart:393-486`），差异只有头像半径与字号（`:403`、`:428`）；没有搜索框、没有通知入口，也没有 `wide` 专属顶部条。spec 第 185 行草图里的 `[设置][通知]` 只落了 `[设置]`（`:451-481`）。
4. **观战分区内容不全**（spec 第 221-227 行要求「竞技观战 / 娱乐观战两档，附房间列表与最近观战历史」）。实现 `home_page.dart:786-840` 只有两张入口卡 + 一段说明，无房间列表、无最近观战历史；而该说明文案（`:827`）写的是「房间列表随对局实时刷新」，**承诺了不存在的列表**——这句文案本身需要改，属诚实性问题。
5. **我的分区内容不全**（spec 第 225-227 行要求「账号卡、对局统计、设置入口、渲染器切换、关于与版本」）。实现 `home_page.dart:846-957` 有账号卡 ✓、全局设置 ✓、3D 渲染器开关 ✓，缺**对局统计**与**关于/版本**（`rg "版本|关于|统计|胜率" home_page.dart` 零命中）。

**设计理论风险**：`app_last_tab` 缺失下，高频用户每次冷启都要从「决斗」重新导航 —— 这不算主导策略或经济失衡，但它是「大厅壳」这个设计支柱（spec 目标 1：完整页面链路）的一处断口，用户路径的可预期性受损。建议列入本冲刺收尾修（改动量极小：一处 prefs 读写 + initState 恢复 + `_selectTab` 落盘）。

### C. 卡组三段式 —— PASS

| spec 要求 | 结论 | 证据 |
| --- | --- | --- |
| 三段（市场 / 我的卡组 / 组卡器）用分段控件切换 | ✓ | `modules/deck_editor3/lib/src/deck_hub_page.dart:98-121`（`SegmentedButton`，label「卡组市场 / 我的卡组 / 组卡器」）；`_segmentCount` 在无 `editorBuilder` 时降为 2 段（`:73`），apps/debug 复用时不出现打不开的入口 |
| compact 单栏（组卡器用 deck_editor1 移动布局） | ✓ | `app_layout.dart:103`（contentColumns 1）→ `home_page.dart:776-777` 注入 → `deck_editor_page.dart:101-105`（`columns<=1` → `_buildMobileLayout`） |
| regular 双栏 | ✓ | `app_layout.dart:115`（2）→ `deck_editor_page.dart:106` + `:125-141`（`_buildTwoColumnLayout`：卡组列表 240 + 主区 + 底部卡组栏/抽屉） |
| wide 三栏 240 / flex / 380 | ✓ | `app_layout.dart:127`（3）→ `deck_editor_page.dart:144-160` `_buildDesktopLayout`（`SizedBox(width:240)` + `Expanded` + 右侧 `width: 380`（`:153`），与 spec 一致） |
| 「展开编辑」死按钮修复 | ✓ | `deck_editor_page.dart:348` 改为 `_isDrawerOpen ? null : _openEditSheet`；`:364-377` 真开 `showModalBottomSheet` 承载 `DeckEditPanel`；`:390-436` `_DeckEditSheet`。原实现只翻转 `_isDrawerOpen` 无人读取（`_isDrawerOpen` 现在真正驱动禁用态与防重复开层），单栏因此第一次有了移卡入口 |
| embedded 不叠双层 AppBar / 不误触 pop | ✓ | `deck_editor_page.dart:67-69`（内嵌直接返回内容，不自建 Scaffold）、`:296-299`（内嵌隐藏返回键，避免死按钮）；`deck_hub_page.dart:41-46`、`:152-155`（内嵌不自建 Scaffold） |

小差异（不计阻塞）：spec 第 210 行草图分段栏右侧的 `[搜索]` 未实现——搜索能力在「卡组市场」内部，分段栏本身没有搜索入口。草图为示意，可接受。

### D. 结算页 —— PASS（含 1 条已批准偏差）

**信息层级**（spec 第 246-256 行）：实现为 标题（含胜负强调色）→ 副标题 → 分隔线 → LP 行 → 分隔线 → 结束原因 → 动作。
- room1：`duel_result_page.dart:242-292`（title/subtitle/divider/LP/divider/reason）
- room3：`duel_result_overlay.dart:236-288`（同序）

与草图差异：草图第一层是「结果徽记」，实现用 34px 强调色大标题承担同一语义（无徽记图形/图标）。属视觉表达差异，层级顺序一致，不计阻塞。

**配色**（spec 第 262 行）：room3 直接用 `HudTheme.gold / cyan / textSecondary`（`duel_result_overlay.dart:121-125`）；room1 不依赖 room3 模块，本地复刻同值常量并注明来源（`duel_result_page.dart:19-21`，值 `0xFFFFD75A / 0xFF37E2FF / 0xFF8A93A8` 与 `hud_theme.dart:8-14` 逐字一致）。✓ 未自造色值。

**响应式**（spec 第 259-260 行）：
- 面板宽：room1 wide/regular 560（`kDuelResultPanelMaxWidth`，:27/:164）、room3 520（`_panelMaxWidthWide`，:14/:158）✓
- compact 宽 `min(viewport.width*0.9, 420)`：room1 `:162-164`、room3 `:156-158` ✓
- compact 按钮纵向堆叠 + 最小高 48：`_ResultActionRow(stacked: isCompact)`（room1 :298/:309-338、room3 :290/:305-336）+ `minButtonHeight = isCompact ? 48 : 44`（room1 :165、room3 :159）✓。单按钮分支（room1 :317、room3 :313-315）不做行容器，交给 ResponsivePanel/全宽容器撑满，仍是整行主按钮 ✓
- LP 条只在大屏展示：`showBar: !isCompact`（room1 :269/:281、room3 :265/:277）✓

**已批准偏差（不计入阻塞项）**：spec 草图 3 按钮 `[返回首页][再来一局][复盘]`，实际只落 1~2 颗，因为「再来一局」「复盘」在仓库中没有协议/能力支撑（无重赛协议、无日志抽屉）。当前实现是「返回首页」单按钮，换备阶段追加「进入换备阶段 + 返回首页」双按钮。**判定：可接受**——做 2 个点不动的死按钮比少做按钮更伤设计（死交互是明确红线），且 spec 第 261 行要求保留的两颗 key 与「进入换备阶段」文案均完好（`duel_result_page.dart:152`、`duel_result_overlay.dart:141`）。

### E. 信息密度验收（spec 第 308 行）—— FAIL（未达标）

spec 原文：「桌面端在 1920×1080 下可见信息量明显多于 1280×720」。

读 `home_page.dart` 的决斗分区布局逻辑，结论是**结构完全相同，只是放大**：

1. **列数在 regular 与 wide 之间没有差别**：`home_page.dart:349-353`
   ```dart
   final columns = switch (spec.tier) {
     AppLayoutTier.compact => 2,
     AppLayoutTier.regular => 3,
     AppLayoutTier.wide => 3,
   };
   ```
   regular=3、wide=3。模式网格 6 项 → 两档都是 2 行 × 3 列。
2. **卡片高度固定、只有宽度被拉伸**：`tileExtent = spec.tier == compact ? 68 : 82`（`:354`），regular 与 wide 都是 82。1280×720 下内容区宽 `1280−88(rail)−40(padding)=1152`，单卡约 373 宽；1920×1080 下 `1920−104−56=1760`，单卡约 583 宽 —— **+56% 宽度，0 条新增信息**（卡内是图标 42 + 一行标题 + 一行描述，`:631-673`）。
3. **内容块集合完全相同**：玩家条（`:359`）→ 快速对战（`:361`）→ 「对战模式」标签 + 网格（`:363-381`）→ 公告（`:382-385`，仅 compact 隐藏）。两档都是这四块，没有 wide 专属板块（不是三栏、不是左右分栏、没有排行榜/最近战报/卡组速览之类的密度增量）。
4. **连排版留白都没利用宽度做结构变化**：wide 只是 pagePadding 28 / gutter 22（`app_layout.dart:124-125`），比 regular 各多 8 / 6 px。
5. **`maxContentWidth`（1600）在的大厅里没有被应用**：全仓库唯一消费点是 `login_page.dart:187`。1920 宽时大厅内容区会撑到 1760，即 spec 第 87 行「超出居中（1600）」的约束在超宽屏（≥1600）上根本没生效。

也就是说：spec 第 17 行批评基线「窗口从小屏拉到大屏，信息密度不变 —— 大屏只是把 1280×800 放大，没有利用多出来的空间」。**这一条在当前实现上只是从「整棵树放大」变成了「卡片放大」**，验收项没有真正翻篇。

这是产品判断，我给 FAIL 而非 CONCERNS：spec 把「信息量变多」写成验收标准（第 308 行）和设计目标（第 29-30 行「桌面端利用更大空间承载更多信息」），而实现明确没有承载更多信息。建议的修复方向（供工程侧评估，不是要求本冲刺做完）：wide 档把决斗分区改成「快速对战（左）+ 模式网格/公告（右）」双栏，或把 `contentColumns` 真正接到网格上（regular 2 / wide 3 且改变卡片容量），让可见条目数或板块数在 wide 档真的增加。

### F. 范围蔓延检查

| 改动 | 是否 spec 要求 | 判定 |
| --- | --- | --- |
| `4866545a` `main.dart` +6 行 `restore()` | 否（spec 只要求开屏页负责「恢复渲染偏好」，实现放在 `main()`） | **可接受**（已由主理人批准）；事实上比「开屏页里恢复」更早生效，路由表 `_is3D`（`route.dart:31`）读的就是它，合理 |
| `f3c109df` 换备阶段「返回首页」+ 弃权二次确认 | 否（spec 第 246-256 行只有 3 按钮、无二次确认流程；新增 key `duel-result-leave` / `duel-result-leave-cancel` / `duel-result-leave-confirm`，新增文案「放弃本场比赛？」「放弃并返回首页」） | **可接受，但必须回写 spec**。它修的是真问题：换备阶段原本被模态锁死、唯一出口是「进入换备阶段」（`duel_result_page.dart:40-44` 注释），离房 = 判负所以需要确认。属「补齐 spec 漏写的出口」，不是炫技式扩写。**但 spec 第 255 行按钮组与第 261 行 key 清单必须同步更新**，否则下一轮评审会把它当成未申报的偏差 |
| `mycard_login_dialog.dart` +76 行（加 `reason` 参数） | **方向与 spec 相反**（spec 第 136 行「独立页面而非弹窗」、第 164 行「改为跳 `/login`（携带 `from`）而不是弹窗」） | **CONCERNS**：门控 `services/mycard_gate.dart:26` 仍然 `showMyCardLoginDialog(...)`，spec 要求的「跳登录页」没落地；这一笔反而把弹窗补得更完整（`:131` 标题、`:138-144` reason 展示），并复制了登录页的表单逻辑 |
| `deck_editor1` `embedded` / `columns` / 抽屉 | 是（spec 第 219 行点名修死按钮；embedded 是卡组分区复用的必要支撑） | **可接受** |
| `deck_editor3.dart` 新增 3 个导出（`deck_square_page` / `my_decks_page` / `my_decks_controller`） | 否 | **建议回滚（低优先）**：`rg` 显示 `apps/` 与其它 `modules/` 对这三者**零引用**，只是扩大了模块 API 面 |
| `home_page.dart` 删除 `context.push(Routes.deckHub)` 入口 | 是（卡组分区取代旧入口） | **可接受**；副作用是 `/deck-hub` 变成只能深链到达的路由（`route.dart:79`），但它现在是「共享实现宿主」，保留合理 |
| `pubspec.yaml` dev_dependencies + `flutter_riverpod`（未提交） | 是（矩阵测试需要 ProviderScope 包裹结算页） | **应收尾提交**，不要留在工作区 |
| `apps/debug` 相关（未改动） | — | 未受影响，`DeckHubPage` 的 `editorBuilder` 为空时自动降为两段（`deck_hub_page.dart:73`），兼容 |

`/match` 路由（`route.dart:48`）无任何 in-app 入口 —— 但基线 `bee45df4` 的 home 也没有指向它的入口（只有 deckHub/deckEditor/card-live/两个 preview），**属既有问题，不是本冲刺引入**，不计入蔓延。

---

## 4. 阻塞项清单（按严重度）

### P0 — 必须在进下一冲刺前处理

**P0-1 开屏分流打断了集成测试的入口契约（spec 第 287/310 行）**
`route.dart:33` `initialLocation: Routes.splash` + `splash_page.dart:48-49` 无登录态 → `go('/login')`；而 `app_flow_test.dart:18-23`、`ai_room_flow_test.dart:30-37`、`ai_room_233_test.dart:26` 都假定「启动即大厅」，且 7 个集成测试文件本冲刺**零改动**（`git diff -- .../integration_test/` 为空）。
影响：`home-server-ai-room` / `ai-room-start-local` / `ai-room-start-server233` 等 key 的唯一自动化覆盖失效。
修复：3 个用例启动后先过开屏 →「游客进入」（key `login-guest-entry`，`login_page.dart:176`）再断言大厅；或在测试内注入已登录态。**注意别用「让集成测试跳过开屏」的方式修，否则 spec 第 309 行的首启链路就永远没有自动化保护了。**

### P1 — 本冲刺收尾应修

**P1-1 E 项信息密度未达标（spec 第 308 行）** — 见 §3-E。至少让 `wide` 在结构上与 `regular` 不同（`home_page.dart:349-353` 的 3/3 是问题核心）。

**P1-2 `app_last_tab` 未实现（spec 第 178 行）** — 全仓库零命中，`home_page.dart:73` 硬编码 0。

**P1-3 未登录门控仍弹窗，且登录逻辑出现两份实现（spec 第 136/164 行）**
`services/mycard_gate.dart:26` 仍走 `showMyCardLoginDialog`。同时 `kMycardCredentialsKey` 在 `login_page.dart:22` 与 `mycard_login_dialog.dart:12` **重复定义同名顶层常量**（值相同，但任何文件同时 import 这两个库就会编译报错，是个埋着的雷），表单校验/凭证持久化/错误态逻辑也是两套逐字重复实现。

### P2 — 记入待办，不阻塞本冲刺

- **P2-1 观战/我的分区内容缺口**（spec 第 221-227）：观战无房间列表/最近观战，且 `home_page.dart:827` 的文案承诺了不存在的列表；我的缺对局统计与关于/版本。
- **P2-2 Rail 折叠（64）与 wide 顶部全局条未实现**（spec 第 175-176）。
- **P2-3 `maxContentWidth` 未在大厅生效**（spec 第 87）：唯一消费点是 `login_page.dart:187`，1920 宽下大厅会撑到 1760。
- **P2-4 `AppLayoutSpec` 字段语义漂移**：`contentColumns` 声称「大厅内容列数」（`app_layout.dart:52`），但大厅不用它（决斗分区自算 2/3/3，`home_page.dart:349-353`），实际只有组卡器用；`isTouch` 无任何生产代码消费；`railWidth` compact 档写 0 而 spec 第 84 行写 64。契约字段要么被消费，要么删掉，否则下一个接入者会按注释理解错。
- **P2-5 收尾遗漏**：`pubspec.yaml` 未提交改动 + 3 个测试文件未被 git 跟踪（见 §0）。
- **P2-6 决斗档位派生量与 spec 的三处微小偏差**（`duel_room_layout.dart`）：`dockedPanelWidth` compact 加了 280 下限（`:85`，spec 第 238 行是 `min(360, w*0.42)`，640 宽下 spec 得 268.8、实现得 280，比 spec 更宽，会挤占场地）；compact 的 `dialogMaxSize` 没有 860/764 上限（`:84` vs spec `min(w*0.94,860) × min(h*0.92,764)`）；wide `dialogMaxSize` 上限用 900/860（`:115-118`）而 spec 写 860/764。均为小差异，建议对齐或回写 spec。

---

## 5. 建议进入下一冲刺的设计债（优先级排序）

### 债 1（最高）：三份结算实现 → 抽共享包

- `modules/duel_room1/lib/duel_result_page.dart`（522 行）
- `modules/duel_room3/lib/duel_result_overlay.dart`（522 行）
- `modules/duel_room2/lib/duel_result_page.dart`（**第三份，本冲刺未动，现在与另两份视觉不一致**）

`_reasonText` 的 61 行 ocgcore reason 码 → 文案映射被逐字复制了两份（`duel_result_page.dart:370-434`、`duel_result_overlay.dart:368-431`），`_ResultRow`、`_ResultDivider`、`_ResultActionRow` 各一份，胜负/平局/观战者的标题-副标题分支（room1 `:132-146`、room3 `:121-135`）也是同一套逻辑。

代价已经显现：room1 用 `ResponsivePanel` + 本地色常量、room3 用 `ConstrainedBox` + `HudTheme`，同一张信息卡在两处渐行渐远（`wrapWidth` 策略、`_ResultRow` 圆角 14/18 vs 12/14、按钮单按钮宽度处理都不同）。建议抽出 `duel_result_kit`（纯 UI + reason 映射表，不依赖房间状态），room1/2/3 只注入 spec 与字段解析。**下一次「配色/文案/层级」调整否则要改三处**，这是最容易失控的设计债。

### 债 2：组卡器两套编辑器 + 全局 store 会话残留

- 大厅「卡组 → 组卡器」段用的是 **deck_editor1** `DeckEditorPage`（`home_page.dart:776-777`），消费 app 级 `DeckEditorStore`（`main.dart` 里 `ChangeNotifierProvider(create: (_) => DeckEditorStore())`）。
- 同一分区的「我的卡组 → 点某副卡组编辑」打开的却是 **deck_editor3** `DeckEditor3Page`（`deck_editor3/lib/src/my_decks/my_decks_page.dart:138-151`，`_openEditor` 自己 push 一层 `ProviderScope`）。

后果：① 同一个「卡组」分区里两套组卡器，用户在 A 里保存、在 B 里看不到；② 等待室从 `/deck-editor` 进组卡器时会 `configureSession({lockDeckSelection: true, initialDeckName: ...})`（`waiting_room_page.dart:95` 等三处），`_routeArgs` 存在 store 上（`deck_editor_store.dart:497-515`）；虽然 `DeckEditorPage.initState` 会 `configureSession(widget.args)`、内嵌时 args 为 null 可重置（`deck_editor_page.dart:50-56`），但 store 是应用级单例，`_lastSaveResult`、`_selectedBanlistHash`、`_editingDeck` 的脏态仍会跨路由残留。建议下一冲刺让组卡器会话 store 随宿主 scope 重建（或在 embedded 模式下显式 `configureSession(null)` + 清脏态），并收敛到**一套**编辑器。

### 债 3：登录双实现 + 门控未改跳转

`login_page.dart`（430 行）与 `mycard_login_dialog.dart`（236 行）承载同一件事：用户名/密码校验、`MyCardAuthException` 文案、`mycard_credentials` 读取/落盘、5 个 ValueKey。`kMycardCredentialsKey` 两处重复定义（`login_page.dart:22`、`mycard_login_dialog.dart:12`）。spec 第 164 行的目标是「门控跳 `/login`（携带 `from`）」，落地方式应是让 `requireMyCardAccount` 改走 `context.push(Routes.login, extra: {'from': ...})` 并删除弹窗，而不是给弹窗加 `reason`。建议下一冲刺一次性做掉：门控改跳转 → 弹窗下线 → 单实现。

### 债 4（候补）：大厅「信息架构」需要一次真正的 wide 档设计

E 项不是代码 bug，是设计缺口：目前 4 个分区的 wide 档都是「同样的板块、更宽」。建议下一冲刺先产出一版 wide 档信息架构草图（每个分区在 1920 下新增什么板块：最近战报/天梯进度/卡组速览/房间列表预览），再改代码。**先设计再实现**，否则容易继续变成「把卡片放大」。

---

## 6. 复查入口（给质量门）

按上表 P0/P1 修完后，建议按此顺序复验：

1. `flutter test apps/uniygopro/test/layout apps/uniygopro/test/widget` （3 个未跟踪文件先 `git add`）
2. `flutter test integration_test/app_flow_test.dart` + `ai_room_flow_test.dart` + `ai_room_233_test.dart`（P0-1 的判据）
3. 1280×720 与 1920×1080 并排截图对比决斗分区（P1-1 的判据，看条目数/板块数，不看留白）
4. 冷启 → 切到「卡组」→ 杀进程 → 冷启（P1-2 的判据，应回「卡组」）
