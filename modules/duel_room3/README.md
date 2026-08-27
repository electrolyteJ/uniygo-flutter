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

## 已知简化（v1）

- 换备（siding）界面为简化版：仅数量校验 + 确认，不支持拖动换卡
- 连锁标记暂无 3D 呈现（HUD 顶栏有连锁计数）
- 卡面 ATK/DEF 数字暂不贴在立牌上（详情面板查看）
