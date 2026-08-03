// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';

/// 注册本包内所有标注了 [Service] 的服务。
void registerAllServices() {
  onServiceRegister();
  ServiceFactory.register<CardService>(createMyCardCardService);
  ServiceFactory.register<DeckService>(() => DeckService());
}
