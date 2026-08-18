import 'package:flutter/material.dart';
import 'package:ygo_data/card_info.dart';

import 'category.dart';
import 'twod/themes/summon_theme.dart';
import 'twod/themes/theme_provider.dart';

/// 召唤门面 —— 卡片场景的统一入口：由 [CardInfo] 确定类别、主题、
/// 标签与主色（供卡组编辑器/鉴赏入口使用）。
class SummonManager {
  SummonManager._();

  static final SummonManager instance = SummonManager._();

  /// 根据 CardInfo 推导召唤类别。
  SummonCategory deduceType(CardInfo card) => summonCategoryFromCard(card);

  /// 根据 CardInfo 获取主题。
  SummonTheme styleFor(CardInfo card) => themeFor(deduceType(card));

  /// 是否需要召唤动效（怪兽/魔法/陷阱都需要）。
  bool shouldAnimate(CardInfo card) => true;

  /// 获取召唤标签文字。
  String labelFor(CardInfo card) => deduceType(card).label;

  /// 获取召唤主色。
  Color primaryColorFor(CardInfo card) => styleFor(card).primaryColor;
}
