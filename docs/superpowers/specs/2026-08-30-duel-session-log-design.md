# 决斗房间会话日志落盘 — 设计规格

日期：2026-08-30
状态：已批准（用户两轮确认）

## 背景与目标

项目内 `console.log` 实为 `import 'dart:developer' as console` 的别名调用
（47 个文件、256 处调用，遍布 biz / duelink_* / resource_* / ocgcore* 等包）。
`dart:developer` 的 `log()` 没有全局拦截钩子，无法直接落盘。

目标：**每次进入决斗房间（connect）创建/重写一份磁盘日志文件**，捕获整个房间
会话期间（连接、组卡、准备、猜拳、换备、多局决斗直到离房 disconnect）所有
`console.log` 输出，便于事后把日志交给 AI 分析问题。

## 已确认的决策

| 决策点 | 结论 |
|---|---|
| 捕获范围 | 全局捕获：替换全部 47 个文件的 import，调用点零改动 |
| 会话边界 | 整个房间会话：`DuelService.connect()` 开始，`disconnect()` 结束 |
| 存储策略 | 单一日志文件 `duel_latest.log`，每次新会话**覆盖重写**，不保留历史 |
| facade 位置 | **新建 `packages/applog` 小叶包**；`service_loader` 是基础包保持纯净，其内部继续用 dart:developer |

## 设计

### 1. 新包 `packages/applog`

叶子包，仅依赖 flutter sdk（dart:io / dart:developer），不依赖任何项目内包，
无循环依赖风险。

**`lib/console.dart`** — 与 `dart:developer` 兼容的 facade：

- 顶层 `log(String message, {DateTime? time, int? sequenceNumber, int level = 0, String name = '', Zone? zone, Object? error, StackTrace? stackTrace})`，签名对齐 `dart:developer log`
- 行为：先调用 `dart:developer log`（保留控制台/VSCode 调试体验），若全局 sink 已挂接则追加写文件
- 写文件失败静默吞掉（日志系统绝不能让决斗逻辑崩溃）

**`lib/src/duel_log_session.dart`** — 会话管理：

- `DuelLogSession.start(String filePath)`：创建父目录，以**覆盖模式**打开文件，
  写入会话头（`===== Duel session <时间> (<平台>) =====`）；幂等：重复 start 会先 stop 旧会话
- `DuelLogSession.stop()`：flush + close，解除 sink
- `DuelLogSession.currentFilePath`：供 UI/调试读取当前日志路径
- 写入策略：行缓冲 + fire-and-forget（`IOSink` 异步写，不 await 在调用链上）
- Web 平台（`kIsWeb`）：退化为仅控制台，start/stop 为 no-op
- 日志行格式：`HH:mm:ss.SSS [name] message`（含 error/stackTrace 时追加）

### 2. 各包接入（机械改动）

- 23 个用到 console 的包的 `pubspec.yaml` 增加：
  ```yaml
  applog:
    path: ../applog
  ```
  （apps/modules 内则用相应相对路径）
- 47 个文件 import 行替换：
  `import 'dart:developer' as console;` → `import 'package:applog/console.dart' as console;`
- 调用点 256 处零改动

### 3. biz 层接线（`packages/biz/lib/duel_service.dart`）

- `connect(Uri)`：先 `DuelLogSession.start('<应用文档目录>/logs/duel_latest.log')`，
  再走原有协议路由；启动后 `console.log('Duel log file: <绝对路径>')` 让路径出现在控制台与日志首行附近
- `disconnect()`：原有逻辑后 `DuelLogSession.stop()`
- 应用文档目录经 `path_provider getApplicationDocumentsDirectory()` 获取
  （biz 新增 path_provider 依赖）；获取失败时退化为仅控制台，不影响进房

### 4. 验证

- `flutter analyze` 全量无新增告警
- `dart test`（biz / duelink 相关测试不被破坏：测试直连底层服务不经 biz DuelService，不产生文件）
- 手动/脚本跑一次房间会话，确认 `duel_latest.log` 生成且内容覆盖全链路，再次进房确认文件被重写

## 明确不做（Out of Scope）

- 日志轮转/多文件保留（用户明确只要一份）
- 拦截 `print`、FlutterError 框架异常（仅 console.log 渠道）
- service_loader 内部改造
- 日志上传/远程收集
