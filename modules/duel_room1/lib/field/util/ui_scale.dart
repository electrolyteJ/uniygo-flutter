/// 视口自适应的 HUD 缩放系数（纯函数，供 widget 层与 Flame 层共用）。
///
/// 场地世界坐标按桌面 800 逻辑像素高的视口设计（卡槽 68×96、手牌栏 96、
/// 阶段轨道 44×20 等）。视口变矮时（手机横屏通常只有 360~430 高），
/// 屏幕空间 HUD 若保持原尺寸会吃掉棋盘高度（相机适配预留会把 zoom
/// 压到 0.4 以下），故按视口高度线性收缩 HUD，下限 0.60 保证可读性。
library;

import 'package:flutter/widgets.dart';

/// 从 [BuildContext] 读取当前视口 HUD 缩放系数（桌面 ≥760 恒 1.0，小屏收缩）。
extension DuelHudScaleX on BuildContext {
  double get hudScale => hudScaleForHeight(MediaQuery.sizeOf(this).height);
}

/// HUD 缩放的基准视口高度（达到该高度时 HUD 不缩放）。
const double kHudReferenceHeight = 760.0;

/// HUD 缩放系数下限：再小字号/触控热区就不可用。
const double kHudMinScale = 0.60;

/// 屏幕空间 HUD（手牌栏/顶栏/弹层）的缩放系数。
///
/// [viewportHeight] 为游戏视口逻辑高度。桌面窗口（≥760）恒为 1.0，
/// 手机横屏（~390）约 0.60。
double hudScaleForHeight(double viewportHeight) {
  if (viewportHeight <= 0) return 1.0;
  return hudScaleForAvailableHeight(viewportHeight);
}

/// 已经扣除安全区的可用高度对应的 HUD 缩放系数。
double hudScaleForAvailableHeight(double availableHeight) =>
    (availableHeight / kHudReferenceHeight).clamp(kHudMinScale, 1.0);

/// 是否进入紧凑 HUD 模式：世界内的玩家状态卡/中央计时器让位给
/// widget 层紧凑件（状态芯片 + 顶栏计时），阶段轨道反缩放为固定
/// 屏幕尺寸，避免随棋盘 zoom 缩到不可读。
bool isCompactHudHeight(double viewportHeight) =>
    viewportHeight > 0 && viewportHeight < kHudReferenceHeight;
