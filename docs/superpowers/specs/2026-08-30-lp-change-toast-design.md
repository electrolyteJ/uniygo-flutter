---
date: 2026-08-30
status: approved
---

# LP 变动锚定提醒（duel_room1）

## 背景与目标

当前对局中 LP 变动（伤害/回复/支付）只在战报日志里留一行文字，玩家经常被连锁烧血打掉了血都没察觉。目标：给玩家造成生命值变动时，在**受影响玩家自己的状态卡旁**弹出 toast 式提醒，谁掉血谁那里弹，不阻断操作。

决策记录（来自头脑风暴）：

- 范围：**双方全部 LP 变动**——伤害（MSG_DAMAGE）、回复（MSG_RECOVER）、支付（MSG_PAY_LP_COST）、直接变值（MSG_LP_UPDATE）。
- 呈现：锚定在受影响玩家的状态卡旁，**不做屏幕中央大 toast**。
- 模块：只做 **duel_room1**（biz 状态层改动天然共享，room2/room3 后续推广成本低）。
- 连续变动：**同侧合并累加**（0.8s 窗口），避免连锁烧血刷屏。

## 现状

- room1 的双方状态卡是 Flame 组件 `PlayerStatusCardComponent`
  （`modules/duel_room1/lib/field/components/player_status_card_component.dart`），
  每帧直读 `DuelFlameGame.snapshot` 渲染，无补间、无浮字。旧 widget 版
  `PlayerStatusCard`（带浮字动画）已不再被 room1 页面使用。
- Flame 侧已有成熟的瞬时事件管线：`summonEffectTick + summonEffectEvent`、
  `cardMoveTick + cardMoveEvent`——biz 状态层维护单调 tick + 最新事件对象，
  随 `FlameFieldSnapshot` 推入，Flame 组件在 update 中按 tick diff 消费。
  本特性复用同一模式。
- LP 相关 handler 现况（`packages/biz/lib/duel/field/duel_field_state.dart`）：
  `handleDamage` / `handleRecover` / `handlePayLife` 走 `_applyLpChange`
  （更新 LP 数值 + lpDelta/lpEventId + 日志）；`handleLpUpdate` 单独更新。
  `lpDelta/lpEventId` 被旧 widget 浮字占用且不带类型，本特性**不复用**，
  走独立事件通道。

## 数据流

```
MSG_DAMAGE / MSG_RECOVER / MSG_PAY_LP_COST / MSG_LP_UPDATE
  → duel_message_router
  → DuelFieldNotifier.handleDamage / handleRecover / handlePayLife / handleLpUpdate
  → DuelFieldState.lpChangeTick（自增）+ lpChangeEvent（最新一条）
  → DuelFieldPage.listenManual 组装 FlameFieldSnapshot（新增两字段）
  → DuelFlameGame.applySnapshot
  → LpChangeToastComponent.update() 按 tick diff 消费 → LpToastFeed 合并 → 渲染
```

## biz 状态层

### 新模型 `LpChangeEvent`

`packages/biz/lib/duel/models/lp_change_event.dart`：

```dart
enum LpChangeKind { damage, recover, pay, set }

class LpChangeEvent {
  final int player;      // 控制器编号 0/1
  final int delta;       // 带符号变动值（伤害/支付为负，回复为正；set 为新旧差值）
  final LpChangeKind kind;
  const LpChangeEvent({required this.player, required this.delta, required this.kind});
}
```

### DuelFieldState 新字段

- `lpChangeTick`（int，单调自增）、`lpChangeEvent`（`LpChangeEvent?`，最新一条）。
- `handleDamage` → kind=damage，delta=-value
- `handleRecover` → kind=recover，delta=+value
- `handlePayLife` → kind=pay，delta=-value
- `handleLpUpdate` → kind=set，delta=newLp-oldLp（delta 为 0 时**不发事件**）
- 四个 handler 在现有逻辑之外追加事件，不改 `_applyLpChange` 现有行为
  （lpDelta/lpEventId/日志原样保留）。
- 同帧多条只保留最新（与 `cardMoveEvent` 同语义；连锁烧血的消息实际跨帧
  到达，丢帧概率极低，作为已知简化接受）。

## Flame 组件

### `LpChangeToastComponent`

`modules/duel_room1/lib/field/components/lp_change_toast_component.dart`，
`PositionComponent`，两个实例（isSelf true/false）由 `DuelFieldWorld.onLoad`
与两张状态卡一并挂载。

- **锚定**：用 `PlayerStatusLayout` + `world.project3D` 取对应状态卡中心，
  向场地内侧（+x）偏移一个固定量；每帧 `_syncPosition()`（与状态卡同法）。
- **呈现**：大字号变动数字（Orbitron，与状态卡 LP 数字同族）+ 小字类型标签。
  伤害红「-2000 伤害」、回复绿「+500 回复」、支付黄「-1000 支付」、
  变动灰蓝「±N 变动」。
- **动画**（手写 timer 驱动，与现有 Flame 组件同风格，不引动画库）：
  缩放弹入（easeOutBack，~150ms）→ 停留（~900ms）→ 上飘 + 淡出（~350ms），
  全程约 1.4s。
- **消费**：`update(dt)` 中直读 `snapshot.lpChangeTick/lpChangeEvent`，
  tick > lastSeen 且事件属于本侧（event.player 与 isSelf 对应 myController
  映射）则交给 feed；tick < lastSeen（新一局重置）则 feed 重置。
- 快照新增 `lpChangeTick` / `lpChangeEvent` 两字段归入 HUD 组：
  **不参与 `==/hashCode`**（避免 LP 频繁变化击穿 `applySnapshot` 的
  changed 短路导致 `world.rebuildField()` 全量重建），带默认值不影响
  既有构造点。

### `LpToastFeed`（纯 Dart，可单测）

`modules/duel_room1/lib/field/models/lp_toast_feed.dart`：每侧一个，
持有当前 toast 状态（累计 delta、kind、阶段计时），时钟可注入。

合并规则：

1. 同 kind 且距上条事件 ≤0.8s → delta 累加，动画计时重置；
2. 异 kind（罕见，如支付后紧跟伤害）→ 新事件直接替换当前 toast，
   以最新信息为准；
3. 距上条事件 >0.8s → 作为新条目开始（同样是替换当前槽位；
   同侧同时最多一条 toast，这是接受的简化）。

组件只读 feed 状态渲染，不含合并逻辑。

## 测试

- biz 单测（`packages/biz/test/`）：四个 handler 推事件的
  player/delta/kind 正确、tick 自增；handleLpUpdate delta=0 不发事件。
- `LpToastFeed` 单测（`modules/duel_room1/test/`）：0.8s 窗口内同 kind
  合并累加、超时后新事件重新开始、异 kind 替换、时钟重置。

## 非目标

- 不做音效/震动。
- 不动 LP 大数字本身（快照直读、无补间的现状保留）。
- room2 / room3 不做。
- 效果选项弹窗（MSG_SELECT_OPTION 的选项文案/卡位样式/连锁来源提示）
  是另一份 spec，本次不包含。
