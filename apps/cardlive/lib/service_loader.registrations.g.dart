// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:service_loader/service_loader.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';
import 'package:duelink_websocket/duelink_websocket.dart' as _i1;
import 'package:duelink_ai/duelink_ai.dart' as _i2;
import 'package:ygo_card_mycard/ygo_card_mycard.dart' as _i3;
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart' as _i4;

void registerAllServices() {
  _i1.onServiceRegister();
  _i2.onServiceRegister();
  _i3.onServiceRegister();
  _i4.onServiceRegister();
  ServiceFactory.register<ICardService>(createMyCardCardService);
  ServiceFactory.register<IDeckService>(() => DeckService());
  ServiceFactory.register<IBanlistService>(() => createMyCardBanListService());
}
