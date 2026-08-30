---
date: 2026-08-30
topic: 决斗场地 HUD 下沉 Flame 化（duel_room1）
status: approved
---

# 决斗场地 HUD 下沉为 Flame 组件

## 背景
顶部 HUD（widget）承载：返回按钮、双方 PlayerStatusCard（横排宽条）、
PhaseBar（TURN 回合徽章 + 当前回合方倒计时）。用户要求把这些信息下沉为
Flame component——它们本质上是场地的一部分。

## 决策（用户已确认）
1. TURN 信息并入 PhaseRailComponent：**轨道顶部徽章**（DP 胶囊上方），
   文案 `T{n} · 我方/对方`，我方青色 #00F0FF / 对方粉红 #FF4B82。
2. 计时器：新组件 CenterTimerComponent，放在**卡槽区正中央**
   （世界原点，两个 EMZ 槽位之间），仅显示当前回合方 MM:SS，
   ≤30s 红 #FF4D4D，否则金 #FFD700，为 0 隐藏。
3. PlayerStatusCard → 新组件 PlayerStatusCardComponent：**紧贴场地左侧**
   （卡片右缘距棋盘左缘 x=-286 留 10px，中心 x=-342），两张竖排——
   对方卡 y=-165、我方卡 y=+165。紧凑竖版（宽 92）：头像圆+名字+
   LP 大数字+H/D/EX/GY/B 五行计数。
4. 保留功能：仅 **EX/GY/B 行点击** 开区域浏览器（TapCallbacks →
   game.onZoneInspect）。去掉 LP 滚动动画、浮动增减字、回合发光描边。

## 实现要点
- FlameFieldSnapshot 增加：turnCount/currentPlayer/selfTimeLeft/
  opponentTimeLeft/selfLp/opponentLp/六个区域计数/selfName/oppName。
  **这些字段不参与 ==**：计时每秒变化，若纳入判等会触发
  world.rebuildField() 全量重建；新组件在 render/update 直读快照，
  无需重建触发。
- 玩家名字在页面侧用现有 teamDisplayName/teamOfEnginePlayer 逻辑
  算好随快照推入（tag 双打映射不进 Flame）。
- PhaseRailLayout：徽章 64×22、间距 8 挂胶囊区正上方；徽章块
  （30px）与末端按钮块（30px）等大，actionButtonShift 净值为 0
  （胶囊区仍居中棋盘中线）。组件尺寸/dock 底板加高。
- 相机内容宽 PhaseRailLayout.boardContentWidth：704 → 792
  （2×(388+8)，覆盖左卡外缘）。_horizontalReserved 96 → 24
  （状态卡已入世界，不再占用 HUD 预留）。
- 页面 _buildTopHud 仅剩返回按钮；删除 room1 的
  phase_bar.dart / player_status_card.dart；_topHudBodyHeight 112 → 52。
- 热重载纪律：新组件在 onMount/update 续读快照游标（同既有组件），
  世界 reload 后自然重建。

## 测试
- phase_rail_layout_test：更新 actionButtonShift 期望（净值 0 公式）、
  新增徽章几何断言（不越界、内容宽覆盖左卡）。
- 新增 player_status_card 布局断言（左缘不越过内容半宽、双卡不重叠）。
- 全量回归 modules/duel_room1。
