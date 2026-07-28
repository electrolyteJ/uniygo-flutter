import 'package:flutter/material.dart';
import 'package:ygo_card/card_info.dart';
import 'styles/summon_style.dart';
import 'styles/style_provider.dart';

/// 召唤管理器 —— 统一入口，负责根据卡牌信息确定召唤类型和样式
class SummonManager {
  SummonManager._();

  static final SummonManager instance = SummonManager._();

  /// 根据 CardInfo 推导召唤类型
  SummonType deduceType(CardInfo card) {
    return SummonStyle.deduceType(card.type, card.attribute);
  }

  /// 根据召唤类型获取样式
  SummonStyle styleFor(CardInfo card) {
    return styleForType(deduceType(card));
  }

  /// 是否需要召唤动效（怪兽/魔法/陷阱都需要）
  bool shouldAnimate(CardInfo card) => true;

  /// 获取召唤标签文字
  String labelFor(CardInfo card) {
    return styleFor(card).label;
  }

  /// 获取召唤主色
  Color primaryColorFor(CardInfo card) {
    return styleFor(card).primaryColor;
  }
}
