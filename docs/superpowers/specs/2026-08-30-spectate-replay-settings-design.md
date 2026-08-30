# 观战回放模式与回放速度设置 设计

日期：2026-08-30
状态：已确认（用户于 2026-08-30 批准设计）

## 背景

对局消息节奏泵（见 2026-08-30-duel-message-pacing-pump-design）解决了观战
爆发消息"过快过乱"的问题，固定为「带节奏地快速回放」。用户希望：

1. 设置中提供开关：进入观战时选择「带节奏地快速回放」或「直接跳到当前局面」。
2. 节奏泵的 paceTiers 档位表在设置中开放（以**回放速度倍率**形式，而非
   完整档位表编辑）。

## 设计

### 1. 设置契约（packages/biz/lib/ygo_settings.dart）

`YgoSettings` 新增：

- `spectateJumpToCurrent`（bool，默认 false = 带节奏回放，保持现行为）；
  仅观战局生效（MSG_START 的 isObserver 判定），玩家自己的对局不受
  影响，避免开局爆发被静默吞掉。
- `replaySpeedFactor`（double，默认 1.0，UI 可选 0.5/1/2/4）；
  消费间隔 = 档位间隔 ÷ 倍率。

`YgoSettingsNotifier` 加对应 setter；copyWith/==/hashCode 同步。
纯字段变化，不需重跑 build_runner。

### 2. 持久化与弹窗 UI（modules/ygo_settings）

- SharedPreferences 新增 key：
  `duel_settings.spectate_jump_to_current`、`duel_settings.replay_speed_factor`。
- 设置弹窗新增「观战」区块：
  - 分段按钮「带节奏回放 | 跳到当前局面」，说明文案"中途进入观战时，
    开局以来的历史消息如何呈现"；
  - 分段按钮回放速度「0.5x | 1x | 2x | 4x」，说明文案"带节奏回放的
    播放速度；跳到当前局面时无效"。
- 弹窗维持纯 StatefulWidget + 回调注入模式：新增
  `onSpectateJumpChanged`（ValueChanged<bool>）与
  `onReplaySpeedFactorChanged`（ValueChanged<double>），
  `showYgoSettingsDialog` / `showGlobalSettingsDialog` 两个入口同步接线。

### 3. 节奏泵（packages/biz/lib/duel/field/message_pump.dart）

- consume 签名改为 `void Function(T message, {required bool silent})`。
- 新增运行时可变字段：`bool jumpToCurrent`（默认 false）、
  `double speedFactor`（默认 1.0）。
- `intervalForBacklog` 从 static 改为实例方法，返回值除以 speedFactor。
- jump 触发：入队后 `jumpToCurrent && 积压 > kJumpBacklogThreshold(20)`
  → 取消节奏定时器，同步静音清空整条队列，随后排一个 120ms 冷却窗口
  （防止爆发中后续消息穿透直通、每条都带音效）。积压 ≤20 视为实时消息，
  正常节奏 + 音效。

### 4. 静音机制（YgoSoundService 最小改动）

- `YgoSoundService` 新增实例字段 `bool suppress = false`；
  `_playAt` 开头检查（在第一个 await 之前，同步生效）。
- `DuelMessageRouter._handleServerMessage` 改名为
  `_dispatchServerMessage`（大 switch 零改动），新增薄包装：

```dart
void _handleServerMessage(YgoStocMsg msg, {bool silent = false}) {
  if (!silent) return _dispatchServerMessage(msg);
  _sound.suppress = true; // 同步代码段，无 await 交错，安全
  try {
    _dispatchServerMessage(msg);
  } finally {
    _sound.suppress = false;
  }
}
```

### 5. Router 接线（duel_message_router.dart）

- 新增 `_isObserverDuel` 字段：`_onServerMessage` 见到 MSG_START 时从
  `MsgStart.isObserver` 捕获（switch 模式匹配，非 MsgStart 兜底 false），
  `start()` 时复位。
- `_applyReplaySettings()`：把 `spectateJumpToCurrent && _isObserverDuel`
  与 `replaySpeedFactor` 写入泵；`start()` 调用一次，`build()` 里
  `ref.listen(ygoSettingsProvider)` 使运行时改设置即时生效。

### 6. 测试

- 泵（message_pump_test.dart）：consume 签名与 intervalForBacklog 实例化
  适配；新增 jump 清场（超阈值同步静音、尾部不足阈值仍按节奏）、
  speedFactor 2x 间隔减半。
- router（duel_message_router_test.dart）：观战 + jump → 爆发同步落位且
  jump 期间音效调用时 suppress=true（recording 音效子类在 play 方法里
  记录调用时刻的 suppress 状态）；玩家身份 + jump 设置 → 不 jump，
  仍按节奏播放。
- ygo_sound_service：suppress=true 时不创建播放器（activePlayerCount 不增），
  恢复后正常。
- ygo_settings（模块）：弹窗新区块渲染与回调；两项设置持久化读写。

## 改动文件

- `packages/biz/lib/duel/field/message_pump.dart`
- `packages/biz/lib/ygo_settings.dart`
- `packages/biz/lib/ygo_sound_service.dart`
- `packages/biz/lib/duel/field/duel_message_router.dart`
- `modules/ygo_settings/lib/ygo_settings.dart`
- 测试：`packages/biz/test/message_pump_test.dart`、
  `packages/biz/test/duel_message_router_test.dart`、
  `packages/biz/test/ygo_sound_service_test.dart`（新增）、
  `modules/ygo_settings/test/ygo_settings_test.dart`
