// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:duelink_ai/duelink_ai.dart';
import 'package:duelink_lan/duelink_lan.dart';
import 'package:duelink_online/duelink_online.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';

/// 注册本包内所有标注了 [ServiceRegister] 的服务。
void registerAllServices() {
  ServiceFactory.register<OnlineDuelService>(() => OnlineDuelService());
  ServiceFactory.register<LanDuelService>(() => LanDuelService());
  ServiceFactory.register<AiDuelService>(() => AiDuelService());
  ServiceFactory.register<CardService>(createMyCardCardService);
  ServiceFactory.register<DeckService>(() => DeckService());
}
