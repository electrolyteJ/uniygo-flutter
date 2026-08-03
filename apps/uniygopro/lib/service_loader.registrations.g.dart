// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:duelink_ai/duelink_ai.dart';
import 'package:duelink_lan/duelink_lan.dart';
import 'package:duelink_online/duelink_online.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';
import 'package:duelink_online/duelink_online.dart' as _i1;
import 'package:duelink_ai/duelink_ai.dart' as _i2;
import 'package:ygo_card_mycard/ygo_card_mycard.dart' as _i3;

/// 注册本包内所有标注了 [Service] 的服务。
void registerAllServices() {
  _i1.onServiceRegister();
  _i2.onServiceRegister();
  _i3.onServiceRegister();
  ServiceFactory.register<OnlineDuelService>(() => OnlineDuelService());
  ServiceFactory.register<LanDuelService>(() => LanDuelService());
  ServiceFactory.register<AiDuelService>(() => AiDuelService());
  ServiceFactory.register<CardService>(createMyCardCardService);
  ServiceFactory.register<DeckService>(() => DeckService());
}
