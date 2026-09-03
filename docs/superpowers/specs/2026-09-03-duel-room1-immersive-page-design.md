# duel_room1 沉浸式页面设计

## 目标

`DuelRoomPage` 在 Android/iOS 原生端进入全屏沉浸式，移除页面 AppBar。等待阶段显示页面内浮动回退按钮，进入对局后隐藏所有可见回退按钮；离开页面后恢复系统栏。

桌面和 Web 同样移除页面 AppBar，但不调用原生系统 UI API。

## 系统 UI 生命周期

- `DuelRoomPage` 挂载后，Android/iOS 调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`。
- 页面销毁时，Android/iOS 调用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`，恢复状态栏和系统导航栏。
- 系统 UI 调用异步执行，不阻塞首帧，也不在 `build` 中产生副作用。
- Web 和桌面不切换系统 UI 模式。

## 页面结构

- `DuelRoomPage` 的 `Scaffold` 永久移除 `appBar` 与 `extendBodyBehindAppBar`。
- 房间内容直接铺满整个 Flutter 视口。
- 非 `RoomInDuel` 阶段在房间级 Stack 顶层显示浮动回退按钮，包括等待室、猜拳、猜拳结果、选择先后攻和换备阶段。
- `RoomInDuel` 阶段不显示房间级回退按钮。
- `DuelFieldPage` 对局 HUD 中现有回退按钮移除，避免对局阶段仍出现第二个入口。
- 结算弹层显示时不显示浮动回退按钮，结算保持最高交互层级。

## 回退交互

- 浮动按钮位于安全区左上角，偏移为安全区加页面紧凑间距。
- 按钮视觉延续现有 HUD 风格，实际命中区域至少 `44×44dp`。
- 点击浮动按钮继续调用现有 `backHomeDialog`，不改变退出、投降或断连业务。
- Android 系统返回键、系统返回手势和桌面快捷键继续由现有 `PopScope`/快捷键逻辑处理。

## 测试与验收

- 纯生命周期测试验证 Android/iOS 进入时请求 `immersiveSticky`、销毁时请求 `edgeToEdge`，非移动平台不调用。
- Widget 测试验证页面不再构建 AppBar。
- 阶段显示策略测试验证等待/猜拳/换备显示按钮，对局隐藏，结算时隐藏。
- 浮动按钮测试验证位于安全区内、命中区域至少 `44×44dp`，点击调用退出确认入口。
- 回归 `duel_room1` 全量测试、模块静态检查和 Android 真机预览。
