# 对局消息节奏泵（Duel Message Pacing Pump）设计

日期：2026-08-30
状态：已确认（用户于 2026-08-30 批准设计）

## 背景与问题

进入竞技观战（尤其是中途加入进行中的对局）时，服务器会把从开局以来的整段
对局消息（STOC_GAME_MSG）一次性推给客户端，量级可达数百条。当前
`DuelMessageRouter._handleServerMessage` 收到一条即同步分发：状态更新、
音效、战报日志全部瞬时触发，导致 UI 在极短时间内刷新几百次，画面
"超级快超级乱"，观战者完全无法看清过程。

玩家自己的对局在开局同样存在小规模消息爆发（洗牌、先后手、各抽 5 张等）。

## 目标体验

- **带节奏地快速回放**：历史/爆发消息按自适应节奏逐条播放，观战者能看到
  召唤、抽卡、连锁等过程，积压越深播放越快，追平后恢复实时。
- **全部消息统一节奏**：玩家与观战走同一套节奏机制；队列空闲时直通，
  玩家正常操作零感知延迟。

## 方案总览

在 `packages/biz/lib/duel/field/duel_message_router.dart` 内新增消息泵，
把"收到即分发"改为"入队 → 按节奏消费"。四个子状态 Notifier
（duelField / selectWindow / cardConfirm / fieldOverlay）、UI 页面、
`DrawAnimationQueue` 等现有机制零改动。

### 已排除的备选

- 协议层（duelink）统一节流：duelink 是协议层，不应携带 UI 节奏策略，
  且会牵连聊天、房间状态等其它消费者。
- UI 每帧合并刷新：只解决重建卡顿，消息仍瞬间灌完，不符合
  "带节奏回放"的体验目标。

## 详细设计

### 1. MessagePump（router 内部类）

- 持有 `Queue<YgoStocMsg>` FIFO 队列与一个调度 `Timer`。
- `enqueue(msg)`：入队；若泵空闲（无待执行 Timer）立即开始消费。
- 每消费一条消息（调用现有 `_handleServerMessage` 逻辑）后，按当前
  积压量调度下一条：

  | 积压量 | 间隔 | 效果 |
  |---|---|---|
  | 0（队列空） | 0ms 直通 | 正常对局/操作零感知延迟 |
  | 1~20 | 120ms | 可读的节奏播放 |
  | 21~100 | 40ms | 快速回放 |
  | >100 | 12ms | 观战追赶（约 80 条/秒） |

- 档位表抽为常量（如 `kPaceTiers`），便于后续调参。
- `ref.onDispose` 时取消 Timer 并清空队列。

### 2. 接入点

- `_msgSub = service.onServerMessage.listen(_pump.enqueue)` 替代
  直接调用 `_handleServerMessage`。
- `STOC_TIME_LIMIT` 保持直通：计时必须实时，且现有代码已在分发前
  单独处理，不入队。

### 3. 相位消息并入队列

目前 `MSG_NEW_PHASE` 经由 `BaseDuelService.onDuelPhaseMessage` 独立流
直通 `_boardN.setPhaseFromStream`。若保持独立流，阶段标签会超前于场上
画面。设计改为：

- router 不再订阅 `onDuelPhaseMessage`（移除 `_phaseSub`）；
- 在消费到 `MSG_NEW_PHASE` 时于 `_handleServerMessage` 分支内同步调用
  `_boardN.setPhaseFromStream(phase, _phaseLabel?.call(phase))`；
- 音效、阶段、战报、画面全部同源同节奏。

### 4. MSG_START 清队列

Match 局间收到 `MSG_START`（新一局开始）时，先丢弃队列中残留的上局
消息再消费本条，与现有"清空上一局作答/浮层"逻辑对齐，防止跨局串台。

### 5. 不受影响的行为

- 玩家 `MSG_SELECT_*` 响应：队列空时直通，无新增延迟；爆发时虽有
  延迟但严格保序，不出现错乱。
- 音效风暴自然消除：音效跟随消息消费节奏逐条触发。
- `MSG_RETRY` 等交互恢复逻辑不变，仅到达时机延后。

## 测试

新增 `duel_message_router` 单测（packages/biz/test/）：

1. 模拟 300 条消息爆发入队 → 断言按积压降档消费，追平后转 0ms 直通；
2. `MSG_START` 到达时队列残留消息被丢弃；
3. `STOC_TIME_LIMIT` 直通（不入队）；
4. dispose 后泵停止、Timer 取消，不再消费；
5. 消费到 `MSG_NEW_PHASE` 时相位与画面同步更新（不再走独立流）。

## 改动文件

- `packages/biz/lib/duel/field/duel_message_router.dart`（核心）
- `packages/biz/test/duel_message_router_test.dart`（新增，如已有同名文件则扩展）
