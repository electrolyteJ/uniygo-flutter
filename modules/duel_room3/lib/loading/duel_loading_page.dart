import 'package:flutter/material.dart';

import 'intro/duel_intro_overlay.dart';
import 'intro/intro_phases.dart';

/// 决斗场地**加载页**：等候页 → **[本页]** → 决斗场地页。
///
/// 设计稿：`07 对战-载入`（预加载 + 入场动画 2700ms · 全程可跳过）。
///
/// 层面定位与邻居：
/// - 上一页是等候页（组卡 / 等对手）；
/// - 本页是房间进入对局后的第一屏，职责单一：**播入场演出**
///   （tunnel → field → vs），播完回调 [onFinished] 交出画面；
/// - 下一页 [DuelFieldPage3D] 自己完成 3D 装配。
///
/// 本页**不持有、不预热 3D**。曾经为了让 3D 提前准备好，这里挂过一份
/// `revealed: false` 的场地页当预加载载体，但那样一来 3D 实例就必须跨页
/// 传递（flame 的 `_gameRenderBox` 是单值，同一 `Game` 不能被两个
/// `GameWidget` 同时持有），而 [TabBarView] 底层是 [PageView]、**不保活**，
/// 离开的页会被销毁——两个约束叠在一起，交接链路极其脆弱。
///
/// 现在 3D 完全属于第 ③ 页，页面之间不共享实例；第 ③ 页建场景的那一下
/// 开销由本页余下的演出遮住，玩家感知不到。
///
/// 业界术语：**Seamless Loading Screen**（无缝加载画面）——用一段过场
/// 演出盖住下一屏的就绪过程，而不是一块转圈占位。
class DuelLoadingPage extends StatelessWidget {
  const DuelLoadingPage({
    super.key,
    required this.data,
    required this.onFinished,
  });

  /// 双方席位数据（名字 / 先攻 / 观战）。
  final DuelIntroSceneData data;

  /// 入场演出播完回调（交出画面，房间页据此切到场地页）。
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return DuelIntroOverlay(data: data, onFinished: onFinished);
  }
}
