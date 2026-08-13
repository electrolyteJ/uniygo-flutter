# duel_room2

duel_room1（Provider + ChangeNotifier）的 Riverpod 重实现：等待室 + 决斗场地，
**不含 Flame 渲染**（场地固定为 Flutter 原型的 `PrototypePlaymatField`）。

## 设计总览

### 作用域

`DuelRoomPage` 每次进房创建独立的 `ProviderScope`，房间/对局/聊天状态随页面
销毁自动回收，替代 duel_room1 的「全局单例 + 手动 reset 三件套」。
宿主路由无需任何 provider 装配。

房间 scope 以应用级容器 `duelRoomServiceContainer` 为 parent：服务 provider
未在房间 scope override，解析上溯到应用级容器，保持单例；房间级 provider
（`duelRoomProvider` / `duelChatProvider` / `duelFieldProvider` /
`selectWindowProvider` / `cardConfirmProvider` / `fieldOverlayProvider` /
`duelFieldControllerProvider`）在房间 scope 内 override，保证每次进房都是
全新状态。

### 状态划分（lib/pages/）

| Provider | 类型 | 职责 |
| --- | --- | --- |
| `duelRoomProvider` | `NotifierProvider<DuelRoomNotifier, DuelRoomState>` | 房间阶段机：等待室/猜拳/先后攻/对局中，玩家列表、卡组选择与禁限校验、自动操作开关（SharedPreferences 持久化） |
| `duelChatProvider` | `NotifierProvider<DuelChatNotifier, DuelChatState>` | 房间/对局聊天：订阅 STOC 聊天流、按房间玩家列表解析发送者名字 |
| `duelFieldProvider` | `NotifierProvider<DuelFieldNotifier, DuelFieldState>` | 对局战场：服务器写入的对局事实（场面/手牌/LP/阶段/连锁） |
| `selectWindowProvider` | `NotifierProvider<SelectWindowNotifier, SelectWindowState>` | 必须回包的选择窗口与响应编码 |
| `cardConfirmProvider` | `NotifierProvider<CardConfirmNotifier, CardConfirmState>` | 只展示不回包的卡片确认状态 |
| `fieldOverlayProvider` | `NotifierProvider<FieldOverlayNotifier, FieldOverlayState>` | 玩家自己打开的本地查看浮层 |
| `duelFieldControllerProvider` | `Provider<DuelFieldController>` | 跨状态编排：MSG_* 分发、音效、确认消息与交互入口 |

服务层（`duelServiceProvider` / `dataServiceProvider` /
`ygoSoundServiceProvider`，以及中间层 `cardServiceProvider` /
`aiDuelServiceProvider`）在 `lib/providers/service_providers.dart` 中直接
构造，不再依赖 `ServiceSingleton`：dataService 的卡片缓存、ygoSoundService
的 AudioPlayer 池都是应用级单例，不随进出房间反复重建。与 duel_room1 相同，
宿主需先调用 `registerAllServices()`（service_loader 的 `ServiceFactory`
依赖此注册）。

### 关键取舍

- **对局状态已 Notifier 化**：`DuelFieldNotifier` / `SelectWindowNotifier` /
  `CardConfirmNotifier` / `FieldOverlayNotifier` 各自维护不可变快照，
  `DuelFieldController` 只做跨状态编排，不再保留 `DuelFieldStore` 门面。
- **控制器不持有 BuildContext**：导航由页面 `ref.listen(stage)` 负责；
  l10n 文案（阶段名）以闭包 `phaseLabel` 注入 store；准备失败原因经
  `toggleReady()` 返回值交给页面弹 SnackBar。
- **流订阅生命周期**：`connect()` 完成后由页面调用各 controller 的 `start()`
  （过早订阅会被路由到默认 WebSocket 服务）；取消收敛在 `ref.onDispose` /
  store 的 `dispose()`。
- **Flame 不实现**：`duel_flame_game` / `flame_playmat_field` /
  `field/component/*` / `render_mode_toggle` 均未移植，页面固定走
  `PrototypePlaymatField` 分支。

### 退出与结算

`backHome`：取出 `duelResult` → `context.go('/')`（房间 ProviderScope 随之销毁，
各订阅自动清理）→ 有结算则跳 `/duel-result`。
结算页（`DuelResultPage`）此时已脱离房间作用域，不读写任何房间 provider；
「返回首页」走 `backHomeAfterDuel`（全局单例兜底 + 导航）。

## 目录

```
lib/
  constants.dart            # 常量 + getDuelPhaseText 等 l10n 文案
  debug/                    # ocgcore Web 调试探测
  l10n/                     # 本地化文案
  pages/duel/               # 对局特征：四子状态/协调器、模型、场地/HUD/弹窗组件
  pages/waiting/            # 等待室特征：聊天状态、模型、等待室组件
  pages/duel_room_page.dart # 房间入口 + 房间级 ProviderScope 装配
  pages/duel_room_state.dart # 房间阶段机状态
  pages/duel_result_page.dart # 结算页
  pages/duel_room_exit.dart  # 退出与结算导航
  providers/                # 全局服务的 Riverpod 包装
  util/                     # 纯工具函数
  widgets/                  # 表现层组件（从 duel_room1 复制，不含 Flame）
```
