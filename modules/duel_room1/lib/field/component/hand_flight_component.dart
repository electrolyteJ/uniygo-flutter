/// 抽卡/发牌飞行动画的兼容别名：实现已泛化为 [CardFlightComponent]
///（全区域双向联动飞牌共用），本文件仅保留旧名转发，既有抽卡调用点
///（DuelFlameGame.playDrawFlight 等）不受影响。
library;

export 'card_flight_component.dart' show CardFlightComponent;

import 'card_flight_component.dart';

/// 旧名别名（构造签名与常量经 typedef 透明转发）。
typedef HandFlightComponent = CardFlightComponent;
