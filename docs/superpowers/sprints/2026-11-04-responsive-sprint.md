# 冲刺收尾报告：响应式页面流 spec 收口

日期：2026-11-04
被收口的设计文档：`docs/superpowers/specs/2026-10-29-app-page-flow-responsive-design.md`（已批准）
质量门结论：**CONCERNS**（剩 1 条阻塞：真机集成测试未执行）
起点提交：`bee45df4` → 终点提交：`2b186e7e`

## 1. 冲刺目标

spec 的实施顺序共 7 步。冲刺开始时第 1、2、5 步已有约 +1156 行未提交的在制品，且**编译不通过**。本冲刺目标是把在制品验收入库，并补齐第 4（卡组分区整合）、6（结算页重设计）、7（测试与回归验收）步。

## 2. 结果概览

| 指标 | 结果 |
| --- | --- |
| 提交 | **18 笔**（工程 11 / 质量 6 / 文档 1 待提交） |
| 代码改动 | 37 个文件，**+6510 / −563** |
| 测试 | 5 包 **378 项全绿**（uniygopro 84 / deck_editor1 10 / deck_editor3 25 / duel_room1 161 / duel_room3 98） |
| 静态检查 | 全部 0 error（uniygopro 余 24 条既有 warning/info，均已归因到早于本冲刺的提交） |
| 尺寸矩阵 | 640×360 / 800×450 / 1280×720 / 1920×1080，40 格全 PASS |
| 契约 | spec 保护的 **20 个 key + 13 条文案零丢失** |

## 3. 故事交付

| ID | 故事 | 结果 | 关键提交 |
| --- | --- | --- | --- |
| S0 | 在制品收尾、编译救绿 | 完成。根因不是缺 import，而是 `apps/uniygopro/pubspec.yaml` 未声明 `flutter_riverpod`（宿主只有 `provider`） | `01ab21a0` |
| S1 | 卡组分区三段式 | 完成。唯一实现收敛到 `deck_editor3.DeckHubPage`，宿主为 12 行适配层；组卡器真内嵌 + 懒构建；死按钮接上抽屉 | `c12a2ef9` |
| S2 | 结算页统一 | 完成。room1/room3 信息层级对齐（徽记→标题→LP 条→原因→动作），三档宽度与按钮排布 | `238e0868` |
| S2b | 渲染器偏好不恢复 | 完成。`main()` 补 `await restore()`（HEAD 既有 bug，2D/3D 选择跨启动丢失） | `4866545a` |
| S3 | 响应式测试门 | 完成，判 CONCERNS。新增纯函数边界 + 四尺寸矩阵 + 集成链路改写，并自行修掉 4 处真缺陷 | `a86b1552` `e8478664` `d2856f03` `b04c27c4` `2b186e7e` |
| G | 设计评审 | 完成，判 CONCERNS：契约零破坏，但 wide 信息密度未达标、`app_last_tab` 未实现、登录门控仍弹窗 | 评审文档 |
| W | 收尾修正 | 完成。`app_last_tab` 持久化、重复常量合并、room3 退出补 pop、无用导出回滚 | `5063ec6f` `dbe7263d` `a2ac6528` `1c9eba03` |

冲刺期内由质量门与工程互相暴露并修复的真缺陷（**均非计划内**）：

1. compact 登录页「返回 / 游客进入」被滚动区覆盖，`hitTestable=false` —— **首启链路断在登录页**（`e8478664`）
2. 残局房 sheet 在 640×360 溢出 260px（`e8478664`）
3. `/deck-editor` 路由在 640×360 溢出 463px（且 `columns` 传 null 导致桌面误判三栏）（`e8478664`）
4. 组卡器内嵌态在 640×360 溢出 58.2px（顶栏 56 + 搜索栏 186 + 底栏 73 = 315 > 可用 256.8）（`6290fb86`）
5. 结算面板把按钮区放进滚动区，compact 下次按钮被裁掉半截（`6895fbb2`）
6. `home_page`「我的」分区 `ListTile` 被 `DecoratedBox` 直接包裹 → debug 断言崩溃、点击水波纹被遮（`a86b1552`）
7. 「快速对战」主按钮 compact 档写死 40 高 < 44 触控下限（`a86b1552`）
8. `app_last_tab` 首版用 `prefs.getInt()`，存量值类型不符时抛 `_TypeError`（异步未捕获）（`5063ec6f`）

## 4. 决策记录

**D1 结算页按钮从 3 颗降为 1~2 颗**（已批准偏差）。spec 草图写 `[返回首页][再来一局][复盘]`，但「再来一局」「复盘」功能不存在（无重赛协议、无日志抽屉可交互）。取舍：不为凑版式造死按钮；换备阶段给「进入换备阶段」+「返回首页」，非换备阶段单按钮撑满。

**D2 卡组分区唯一实现落在 `deck_editor3` 而非宿主**。硬约束：`DeckHubPage` 还被 `apps/debug` 的 `main.dart:57` / `main_deck3.dart:39` 引用，而 debug app 不能依赖 `apps/uniygopro`。代价：模块不能读宿主 `AppLayout`，改以 `pagePadding` / `columns` 参数注入。

**D3 死按钮接上抽屉而非删除**。单栏/双栏布局此前没有移卡入口，删按钮会让紧凑端永远无法编辑卡组。

**D4 否决「内嵌态删掉移动 AppBar 省 56px」**（该建议由主理人最初提出并推荐，被工程以两条可量化证据推翻）。理由：① 该 AppBar 是 `Row[卡组名输入, 保存]`，**单栏下唯一的保存/重命名入口**（桌面 `_AppBarActions` 单栏不渲染）；② 删后仍差 2.2px（200.8 vs 186+73=259）；③ 要过必须把筛选压到 40 高，违反 44 触控下限。已补守卫用例 `b58e5092` 把该约束编码为测试。

**D5 room3 退出确认补 `pop()` 的理由被更正**。原归因为「弹窗会悬浮在首页上」，负向验证（临时删除 `pop` 重跑）显示正常退出路径**依然通过**——`context.go('/')` 的 page reconciliation 会连带清掉 imperative dialog 路由。真正会卡死用户的是**早退路径**：`markLeaving()` 返回 false → `backHome` 直接 return 不导航 → 只有 `pop` 能关弹窗。修复必要，理由已改写。

**D6 wide 档 `maxContentWidth` 上限降级到下一冲刺**。它与信息密度缺口同源，单独定宽度无意义。

**D7 任务板认领撞车处置**。`engineering-lead` 交完 S1 后从共享任务板接走了 `quality-lead` 正在做的 S3，导致两套重复矩阵。处置：`Task #4` owner 改为 `quality-lead`，工程回归自己 S1 的溢出缺陷。教训见 §8。

## 5. spec 偏差

| 项 | 偏差 | 状态 |
| --- | --- | --- |
| 结算页按钮 | 3 颗 → 1~2 颗 | 已批准（D1），spec 第 255 / 261 行需回写 |
| wide 信息密度 | spec 第 308 行要求「1920×1080 信息量明显多于 1280×720」，实测 wide 与 regular 均 3 列、卡片 82 高，仅宽度 +56%，新增信息 0 条 | **未达标**，转下一冲刺 |
| 桌面 4 栏信息架构 | 2026-10-29 设计稿给的是 1440×900 顶部导航 + 4 栏栅格，代码落成通用 2/3/3 卡片网格 | **未落地**，转下一冲刺 |
| `app_last_tab` | spec 第 178 行要求持久化，冲刺中段仍为硬编码 `_index = 0` | 已在 W 补齐（`5063ec6f`） |
| 登录门控 | spec 第 136 / 164 行要求跳 `/login` 携带 `from`，现状仍走弹窗（`mycard_gate.dart:26`） | 转下一冲刺 |

## 6. 质量门结论

**CONCERNS**。无 Blocker / Critical。唯一阻塞：

**真机集成测试未执行** —— 3 个用例已全部改走真实首启链路（开屏 → 游客进入 → 大厅），`flutter analyze integration_test/` 0 error，但本机装不上机：

- Android：`assembleDebug` 成功（`app-debug.apk` ✓，59.2s）→ `adb: failed to install ... INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`；`adb uninstall` 亦 `DELETE_FAILED_INTERNAL_ERROR`
- macOS：`xcodebuild: sandbox_apply: Operation not permitted`（关闭 Bash 沙箱仍失败）
- Chrome：`Web devices are not supported for integration tests yet`

解除条件：机主在手机端允许「USB 安装」并手动卸载旧包，然后执行

```bash
flutter test \
  integration_test/app_flow_test.dart \
  integration_test/ai_room_flow_test.dart \
  integration_test/ai_room_233_test.dart \
  -d <device>
```

（`ai_room_233_test.dart` 另需能访问 ygo233.com。）

## 7. 已知空白与问题

1. 三个集成测试未在设备执行（唯一阻塞），`home-server-ai-room` / `ai-room-start-local` / `ai-room-start-server233` 三个 key 目前仅有 widget 级覆盖（`app_flow_smoke_test.dart`），不能替代 integration 证据
2. `DeckSquarePage` / `MyDecksPage` 依赖真实网络，仅覆盖错误态
3. `waiting_room_page` 无四尺寸矩阵（依赖真实房间流，成本过高）
4. room3「服务端是否总下发 LP」客户端无法证明，需真机跑一局 3D 对局
5. 设计评审的像素观感无真机截图，仅几何断言替代
6. **compact 640×360 结算页「结束原因」首屏完全不可见**，需滚动一次：room1 原因 rect 250.4–262.4 vs 滚动视口 58.4–195.6；room3 228.8–239.8 vs 35.8–208.2。按钮区常驻是对的取舍，但用户要多滚一次
7. 组卡器内嵌态与 `/deck-editor` 共享 app 级 `DeckEditorStore` 单例，存在跨路由脏状态风险

## 8. 下一冲刺候选（按优先级）

1. **桌面 4 栏信息架构落设计稿**（含 `maxContentWidth` 决策）。这是本冲刺唯一未达标的产品验收项，且设计稿已存在，属实现补齐而非重新设计
2. **抽 `duel_result_kit` 收敛三份结算实现**。room1 用 `ResponsivePanel` + 本地色常量（圆角 14/18），room3 用 `ConstrainedBox` + `HudTheme`（12/14），`_reasonText` 的 61 行码表逐字复制两份，room2 是第三份且已漂移
3. **登录双实现收敛**：`requireMyCardAccount` 改 `push(Routes.login, extra:{from})`，下线 236 行的弹窗，消除 430 行 LoginPage 与它的重复
4. **组卡器会话隔离与头部重设计**：内嵌态需把「卡组名 + 保存 + 筛选」合并成 40–48 高一行的头部才能彻底解掉紧凑档挤压（属重新设计）；同时给 `deck_editor1` 支持注入 store，避免与 `/deck-editor` 共享单例
5. **compact 结算页信息层级调整**：把「结束原因」提到 LP 行之前，或压缩标题区，避免首屏不可见

## 9. 过程教训

1. **管道退出码不可信**。后台任务报 `flutter test ... | tail` 返回 exit 0，那是 `tail` 的退出码，不是测试的。必须用重定向单独捕获真实退出码，否则会把「APK 构建成功」误读成「集成测试通过」。
2. **并行派单必须先上锁归属**。向共享任务板投放任务后若不立刻写 `owner`，空闲成员会按团队规则「看到未认领就接」，导致两人重复产出。本冲刺因此浪费了一套重复矩阵。
3. **提删减建议前先验证该 UI 承担什么功能**。主理人推荐的「删内嵌 AppBar 省 56px」被推翻，根因是把「56px 的头部」当成纯排版成本，没验证里面装的是单栏唯一的保存/重命名入口。
4. **修复理由错的严重性不亚于修复本身**。room3 的 `pop()` 修对了但归因错了，若不纠正，后续会有人基于错误机制去「优化」掉这行代码。负向验证（删掉看是否变红）是区分「必要」与「偶然有效」的唯一手段。
