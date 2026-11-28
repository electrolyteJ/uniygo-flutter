# duel_room3 —— 纯 flame_3d 3D 决斗房间

设计文档：`docs/superpowers/specs/2026-08-27-duel-room3-3d-duel-scene-design.md`

## 特性

- **纯 flame_3d 3D 场景**：悬浮竞技场 + 星空穹顶 + 区域地砖网格（32 槽位）
- **3D 卡图立牌**：卡图纹理竖直 quad（CardImageLoader → ImageTexture），
  支持攻击/守备（面内横置）/里侧（卡背）/XYZ 素材堆叠
- **全套 3D 效果**：召唤门+光柱+粒子爆发 / 攻击前扑+光束+命中爆发 /
  伤害数字 billboard / 抽牌飞牌 / 破坏倒地 / 洗牌粒子
- **运镜**：MDPro3 式俯视默认机位 + 召唤推近 + 命中震屏
- **MDPro3 风格 UI**：底部扇形手牌、左右竖向 LP 条、右侧阶段轨道、
  左侧滑入卡片详情、操作胶囊条、全新等待室
- **交互**：射线拾取立牌/地砖 → 就地选择/放置选择/操作菜单/区域检视
- **房间邀请**：等候厅二维码邀请 + 扫码/粘贴邀码加入（见下文「房间邀请与扫码」）

## 房间邀请与扫码

- 等候厅邀请弹窗的二维码内容是深链
  `uniygo://duel?room=<邀码>&h=<host>&p=<port>`（`waiting/invite/duel_invite.dart`）。
  `h`/`p` 是房主所在服务器，扫码方据此选用同一环境；老二维码只有 `room`，
  解析时允许缺失。
- `waiting/invite/qr_scan_dialog.dart` 的 `showRoomQrScanDialog()`：Android/iOS 用
  `mobile_scanner` 实时取景扫二维码；macOS/Windows/Linux/Web 自动退化为
  「粘贴邀请码」，也可以传 `cameraSupported: false` 强制走粘贴。
- 模块只返回扫到的原文；解析、选环境、真正进房都由宿主负责。
  uniygopro 把入口挂在建房页页壳右上角「加入房间 · 扫码」
  （`apps/uniygopro/lib/create_room/widgets/join_room_button.dart`）。
- 相机权限：Android `CAMERA`（同时声明
  `<uses-feature android:name="android.hardware.camera" android:required="false">`，
  无相机设备仍可安装）；iOS `NSCameraUsageDescription`。

## 状态层

零改动复用 `packages/biz`（与 duel_room2 相同的 ProviderScope 接线）。
`Duel3DBridge` 把 Riverpod 快照 diff/tick 事件翻译成 3D 指令。

## 运行

flame_3d 依赖 Flutter GPU（Impeller 场景），**不支持 Web**（Web 端显示降级提示）：

```bash
# 3D 场景预览（免服务器，自动循环演出）
flutter run -d macos --enable-flutter-gpu -t apps/uniygopro/lib/main_preview3d.dart

# 完整应用（主页 AppBar 的 3D 图标切换决斗房 2D/3D，长按打开 3D 预览）
flutter run -d macos --enable-flutter-gpu -t apps/uniygopro/lib/main.dart
```

## flame_3d vendor 说明

`packages/flame_3d` 为 monorepo 修复提交 `0453bad6` 的本地拷贝
（0.3.0 未适配 Flutter 3.47 的 flutter_gpu API），另含 uniygo 补丁：
`GpuBackend._preloadShaderLibraries` 逐资产 try/catch —— 与 flutter_scene
共存时其 data_assets 注入的 shaderbundle 无法被本运行时解包，
原版遇错中断会导致内建材质随机缺失（ShaderLibrary 初始化失败）。

## 赛博朋克皮肤（决斗²）

对应 Ardot 设计稿「05 对战-决斗 · 3D」的赛博强化版视觉稿
`website/05-duel-cyberpunk.html`。改动只换皮，不动 `Duel3DBridge` /
`CardStandee` / `CameraRig` / 射线拾取：

- `theme/cyber_palette.dart` + `theme/cyber_skin.dart`：赛博色板与
  「演出增强层」开关（shared_preferences 持久化，默认开）
- `theme/hud_theme.dart`：HUD 常量整体换成深黑蓝 + 亮青 + 品红/酸绿
- `field/hud/cyber_overlay.dart`：扫描线 / 雨丝 / 噪点 / 暗角 / 故障条 /
  四角切角线框（纯 Flutter CustomPaint，内置 IgnorePointer）
- `field/scene3d/arena_component.dart`：矩形悬浮平台 + 双层霓虹边框 +
  法阵环 + 四角光柱 + 城市天际线穹顶 + 无限延伸地面网格
- `field/scene3d/zone_grid_component.dart`：32 槽霓虹配色 + 逐格流动微光
- `field/scene3d/fx/effects_manager.dart`：召唤门三层 / 双光柱 / 地面冲击波 /
  双色光束 / 双层命中闪光 / 异色粒子
- `field/scene3d/duel_3d_game.dart`：品红 + 亮青双色侧光
- `field/duel_field_page.dart`：叠层挂载 + 右上角闪电按钮即时切换

开关控制的是**动态演出强度**，关掉后回到接近经典的观感；皮肤底板
（HUD 色板、灯光、天际线、地面网格）常驻，不随开关变化。所有 3D
组件都在 `update` / 特效播放时读取开关，因此切换即时生效，不需要
重建 `Duel3DGame`。粒子池上限仍为 260，复杂动画靠分层与复用实现，
不靠堆粒子数。

**限制**：flame_3d 的 `BlendState` 是整帧 render pass 的全局状态，
无法按材质设 additive，也没有 bloom 后处理，因此霓虹辉光靠高饱和
自发光色 + 多层叠加近似，做不到 HTML 原型里 `lighter` 合成的真辉光；
真辉光仍需设计文档里列的自定义 Material + shaderbundle spike。
Web 端不支持：本模块**只服务原生平台**，内部不做 `kIsWeb` 判断。
「Web 走哪个页面」由宿主的降级路由决定（`duel_room2`）。

## 已知简化（v1）

- 换备（siding）界面为简化版：仅数量校验 + 确认，不支持拖动换卡
- 连锁标记暂无 3D 呈现（HUD 顶栏有连锁计数）
- 卡面 ATK/DEF 数字暂不贴在立牌上（详情面板查看）