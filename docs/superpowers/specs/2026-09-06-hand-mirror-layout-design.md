# 双方手牌镜像排布设计

日期：2026-09-06
状态：已批准（用户确认「彻底镜像」）

## 背景

duel_room1 的双方手牌栏（HandBarComponent）当前**不是镜像关系**：

1. 扇形朝向：HandFanLayout.angleAt 与 centerDx 都乘以 _direction（对方 -1），
   两者抵消 —— 视觉同一位置的卡两侧倾斜角**相同**（最左侧卡都向左倾），
   对方手牌是我方手牌的平移复制，不是倒影。
2. 垂直定位：我方 baseLineY = size.y - selfBottomInset - bottomPadding - cardHeight/2
   （贴底、出血 20px）；对方 baseLineY = hudTopY + barHeight - bottomPadding - cardHeight/2
   （避让状态栏 + 顶部 HUD + 10px 间隙）。顶/底边距不相等。

## 目标

- 对方手牌 = 我方手牌关于**屏幕水平中线**的精确镜像（彻底镜像，用户批准）：
  - 视觉同一位置的卡倾斜角反号（对方最左侧卡向右倾）；
  - 凸弧朝场地中心（已满足，保留）；
  - 对方手牌到屏顶的间距 == 我方手牌到屏底的间距（含出血，不再避让顶部 HUD）。
- 接受的影响：对方手牌可能与顶部状态栏/倒计时 HUD 重叠。

## 方案（方案 A：纯几何镜像）

### hand_fan_layout.dart

- angleAt(index) 去掉 _direction 系数：(index - centerIndex) * rotationStep。
  镜像侧下标仍右→左排布（centerDx 保留 _direction）→ 视觉倾斜角自然反号成倒影。
- centerAt.dy 的 _direction 翻转保留（凸弧朝场地中心）。
- 更新 mirrored 文档注释为「上下镜像（轴为屏幕水平中线）」语义。

### hand_bar_component.dart

- 对方 baseLineY 取我方公式的镜像：

  ```
  isSelfSide ? size.y - edgeInset - bottomPadding - cardHeight/2
             : edgeInset + bottomPadding + cardHeight/2
  ```

  恒等式 size.y - baseLineY_opp == baseLineY_self 成立 ⇒ 顶/底边距严格相等。
  抽纯函数（组件级静态方法）便于单测该等式。
- 移除 hudTopY / setHudTopY；cardSlotRect 越界兜底同步镜像（size.y - 50 ↔ 50）。
- HandBarViewportGeometry.selfBottomInset 改用语义更宽的 edgeInset
  （顶/底共用的边距，仍取底部安全区值）。

### 级联清理

- DuelFieldGame：删 _oppHandTopY / setOppHandTopY。
- DuelFieldPage：删 _oppHandTopY / _opponentHandGap 及全部调用点
  （_ensureFlameGame、didChangeDependencies、build 路径）。
- LpChangeToastComponent：对方 toast 锚点改为我方公式的水平镜像
  （viewPadding.bottom + barVisualH + bottomPadding + _gap + halfH），
  与手牌栏的镜像排布保持一致。

## 测试（TDD）

1. 更新 hand_fan_layout_test.dart 镜像用例：
   - 视觉镜像断言：mirrored.angleAt(n-1-i) == -normal.angleAt(i)（倾斜角反号）；
   - centerDx / centerAt.dy / 凸弧对称性断言按新语义修订。
2. 新增 baseLineY 镜像等式用例：viewportHeight - oppBaseLineY == selfBaseLineY
   （含 edgeInset=0 与 >0 两组）。
3. 既有 hand_bar_hit_test / hand_component_lifecycle_test 不受角度/位置公式
   变更影响（只断言命中与生命周期），跑通即可。

## 非目标

- 不动相机预留（_topReserved=230 / _bottomReserved=116）与棋盘内容尺寸。
- 不动对方手牌不可交互、抽卡飞行动画等逻辑（均读取实际卡位矩形，自动跟随）。
