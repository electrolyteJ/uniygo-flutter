# duel_room3 设计文档 —— 纯 flame_3d 3D 决斗场景

日期：2026-08-27
状态：已确认（用户选定方案二）

## 背景与目标

`apps/duel_room3` 目前为空壳（仅有空 README）。目标：实现完整决斗房间（等待室 + 3D 决斗场），决斗场景用 flame_3d 纯 3D 渲染，UI 参考 MDPro3 全新设计（不沿用 duel_room1 / duel_room2 的皮肤）。

与 room1/room2 的差异：

| | duel_room1 | duel_room2 | duel_room3 |
|---|---|---|---|
| 场地渲染 | Flame 2D | 纯 Flutter Widget | flame_3d 纯 3D |
| 状态层 | 全局单例 | Riverpod + packages/biz | Riverpod + packages/biz（同 room2） |
| UI 风格 | 自有 | 自有（原型风） | MDPro3 风 |

## 用户已确认的关键决策

1. **范围**：完整房间 + MDPro3 风格全新等待室（选项 C）
2. **怪兽表现**：3D 立牌（卡图贴片竖直 quad，全卡可用；选项 B）
3. **平台**：仅原生（依赖 Flutter GPU），Web 降级提示 —— 可接受
4. **效果**：全套 —— 3D 悬浮竞技场 / 卡牌 3D 化摆放 / 召唤特效（光束+粒子）/ 攻击特效 / 伤害数字 / 镜头运镜 / 抽牌动画
5. **架构**：方案二 —— 纯 flame_3d 单层，粒子与伤害数字也全部手写 MeshComponent 实现，不引入 2D Flame overlay 层

## flame_3d 技术核实结论

锁定与 cardlive 相同的 git 提交（`0453bad6`，flame monorepo，`packages/flame_3d`；pub 上 0.3.0 未适配 Flutter 3.47 的 flutter_gpu API）。

已核实的 API 能力：

- `UnlitMaterial`（`albedoColor` × `albedoTexture`，无光照计算）—— 立牌 / 粒子 / 伤害数字 / 3D UI 面板的默认材质
- `SpatialMaterial`（PBR：metallic/roughness + 环境光/点光）—— 竞技场平台
- 内建网格：`PlaneMesh` / `CuboidMesh` / `CylinderMesh` / `SphereMesh` / `ConeMesh`；自定义网格可经 `Mesh` + `Surface` 手写顶点（召唤门 RingMesh）
- `ImageTexture.create(ui.Image)` —— 直接消费 `CardImageLoader`（packages/biz）的 L1 缓存卡图，无需网络/解码改造
- `CameraComponent3D.position` / `target` 可变 —— 运镜 = 每帧缓动 lerp
- 灯光：仅 ambient + point（点光 1/d² 衰减，距离 ~5 时强度需给到 22~40，参考 cardlive 注释）；无平行光、无 IBL
- 后端 `BlendState` 支持 `alphaBlend` / `additive`，但**材质层未暴露**；additive 发光需要自定义 Material 子类 + 自编译 shaderbundle（flame_3d 自带 `bin/_build_shaderbundle.dart` 工具）——最大技术风险
- 渲染前必须 `await GpuBackend.initialize()`（幂等，cardlive 模式）

## 架构

```
┌────────────────────────────────────────────────┐
│ Flutter Widget HUD（MDPro3 风格）               │
│  手牌横排 / LP 条 / 阶段按钮 / 卡片详情 / 对话框  │
├────────────────────────────────────────────────┤
│ Duel3DGame extends FlameGame3D<World3D, ...>   │  ← 唯一渲染层（纯 3D）
│  ├─ ArenaComponent      悬浮竞技场 + 星空背景    │
│  ├─ ZoneGridComponent   区域地砖 + 高亮脉冲      │
│  ├─ StandeeController   立牌生命周期与摆放       │
│  ├─ EffectsManager      粒子/光束/数字/飞牌      │
│  └─ CameraRig           运镜与震屏               │
├────────────────────────────────────────────────┤
│ Duel3DBridge（Riverpod → Game 指令桥）           │
│  监听 duelFieldProvider 等快照 diff，             │
│  翻译成 3D 指令（摆放/召唤/攻击/伤害/抽牌）        │
├────────────────────────────────────────────────┤
│ packages/biz 状态层（零改动复用）                 │
└────────────────────────────────────────────────┘
```

### 状态桥接

duel_room3 房间入口照 duel_room2 的 `ProviderScope` 房间级隔离模式（overrides：`duelRoomProvider` / `duelChatProvider` / `duelFieldProvider` / `selectWindowProvider` / `cardConfirmProvider` / `fieldOverlayProvider` / `duelMessageRouterProvider`），packages/biz 零改动。

`Duel3DBridge` 在页面侧监听 Riverpod 快照与事件流（`battle_presentation` / `summon_effect_event` / `draw_animation_event` 等 biz 现有模型），diff 后调用 Game 暴露的指令 API：`applySnapshot()` / `playSummon()` / `playAttack()` / `playDamage()` / `playDraw()` / `playDestroy()` 等。3D 场景自身不 import Riverpod。

## 3D 场景布局与坐标系

- Y 轴向上，场地在 XZ 平面；己方在 +Z（近相机端），对方在 -Z
- **悬浮竞技场**：压扁 `CylinderMesh` 主平台（`SpatialMaterial`）+ 边缘发光环（Unlit）+ 大反转球体贴程序化生成星空纹理作背景
- **区域地砖**：标准 YGO 场地（双方各 5 怪兽格 + 5 魔陷格 + 场地区/墓地/牌组/额外/除外），微凸起 `CuboidMesh`；可发动/可选中格子材质颜色脉冲高亮
- 灯光：环境光 + 2~3 盏点光（强度按 cardlive 量级）

## 立牌系统（CardStandee）

Object3D 组合：竖直 `PlaneMesh`（卡图 `UnlitMaterial`，宽高比 59:86）+ 薄 `CuboidMesh` 边框。状态表现：

- 攻击表示：竖直立牌，微微后仰朝向相机
- 守备表示：绕立轴转 90° 横置
- 里侧表示：显示卡背纹理
- XYZ 素材：缩小立牌横排在主卡下方堆叠
- 指示物：卡面上方悬浮小 `SphereMesh`
- 双方立牌均面向我方相机（都可读）；选中/可攻击时发光描边脉冲

## 相机与运镜（CameraRig）

每帧对 `position`/`target` 缓动 tween。默认视角（MDPro3 式己方身后俯视）：`position(0, 7.5, 8.5)` → `target(0, 0, -0.5)`，fovY 50。

运镜预案：召唤推近特写 → 攻击跟随 + 命中震屏 → 伤害轻晃 → 回默认位；手指滑动提供小幅度视差偏移。

## 效果系统（纯 flame_3d，全部手写 MeshComponent）

- **ParticleSystem3D**：池化 billboard 小 `PlaneMesh`（每帧朝向相机），属性：速度/重力/生命/尺寸/透明度衰减；发射器：爆发/锥形/喷泉/拖尾
- **召唤**：自研 RingMesh 召唤门 + `CylinderMesh` 光柱 + 粒子爆发 + 立牌缩放/翻转登场
- **攻击**：攻击方立牌前扑 tween + 命中闪光 + 粒子爆发 + 震屏；高攻怪追加 `CylinderMesh` 光束
- **伤害数字**：Canvas 预渲染 0-9/+/- 数字图集 → `ImageTexture`，billboard 数字上飘渐隐（池化）
- **抽牌**：卡背小立牌从牌组格沿 3D 弧线飞到手牌区
- **破坏**：碎裂粒子 + 倒地 → 飞向墓地
- **连锁**：场上悬浮连锁标记堆叠

## 交互

射线拾取：屏幕坐标 → 逆投影矩阵算射线 → 与区域平面/立牌 AABB 求交（自研 Raycaster 工具）。点己方怪兽/空格 → MDPro3 风格操作条（可用动作来自 biz 的 idle actions / duel menu 模型）；长按 → 卡片详情。

## HUD（Flutter Widget，MDPro3 风格全新设计）

- 底部：手牌横排扇形展开
- 左右边缘：竖向 LP 条 + 头像
- 右侧：竖排圆形阶段按钮（DP/SP/M1/BP/M2/EP）
- 左侧：滑入式卡片详情面板
- 中央：连锁堆叠 / 选择网格 / 是否确认等对话框 —— 按 biz overlay 状态驱动、全新 MDPro3 皮肤
- 日志/聊天：抽屉

## 等待室（MDPro3 风格）

复用 duel_room2 等待室状态逻辑，UI 全新：暗色科技风、玩家位以立牌式卡座呈现、卡组预览、准备状态动效。

## 平台与降级

- `kIsWeb` → 降级提示页（同 cardlive 策略）
- 原生平台需 `--enable-flutter-gpu` 运行，写入 README
- uniygopro 的 `servers.dart` 房间路由配置增加 duel_room3 选项

## 技术风险与 Spike 顺序

1. **additive 混合**（光束/粒子发光感）：第一个 spike；默认管线若仅 alphaBlend 则自定义 Material 子类 + 自编译 shaderbundle
2. 射线拾取、数字图集：低风险
3. 性能：约 30 立牌 + 数百粒子；flame_3d 有视锥剔除；spike 期验证帧率

## 测试策略

- 纯 Dart 单测：布局数学、射线拾取、快照 diff → 3D 指令转换
- 3D 渲染藏在 controller 接口后（测试环境无 GPU，可注入 fake）
- HUD 与等待室：widget test
