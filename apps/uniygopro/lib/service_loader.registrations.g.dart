// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:duelink_ai/duelink_ai.dart';
import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:duelink_ai_edo/src/puzzle_service.dart';
import 'package:duelink_websocket/duelink_websocket.dart';
import 'package:resource_banlist_mycard/ygo_banlist_mycard.dart';
import 'package:resource_card_baige/ygo_card_baige.dart';
import 'package:resource_card_mycard/ygo_card_mycard.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:resource_deck_mdpro3/ygo_deck_mdpro3.dart';
import 'package:resource_deck_mycard/ygo_deck_mycard.dart';
import 'package:service_loader/service_loader.dart';
import 'package:duelink_websocket/duelink_websocket.dart' as _i1;
import 'package:duelink_ai/duelink_ai.dart' as _i2;
import 'package:duelink_ai_edo/duelink_puzzle.dart' as _i3;
import 'package:resource_card_baige/ygo_card_baige.dart' as _i4;
import 'package:resource_card_mycard/ygo_card_mycard.dart' as _i5;
import 'package:resource_banlist_mycard/ygo_banlist_mycard.dart' as _i6;
import 'package:resource_deck_mdpro3/ygo_deck_mdpro3.dart' as _i7;
import 'package:resource_deck_mycard/ygo_deck_mycard.dart' as _i8;

/// 注册本包内所有标注了 [Service] 的服务。
void registerAllServices() {
  _i1.onServiceRegister();
  _i2.onServiceRegister();
  _i3.onServiceRegister();
  _i4.onServiceRegister();
  _i5.onServiceRegister();
  _i6.onServiceRegister();
  _i7.onServiceRegister();
  _i8.onServiceRegister();
  ServiceFactory.register<WebSocketDuelService>(() => WebSocketDuelService());
  ServiceFactory.register<AiDuelService>(() => AiDuelService());
  ServiceFactory.register<PuzzleDuelService>(() => PuzzleDuelService());
  ServiceFactory.register<IPuzzleService>(() => PuzzleService());
  ServiceFactory.register<BaigeCardService>(() => BaigeCardService());
  ServiceFactory.register<MyCardCardService>(() => MyCardCardService());
  ServiceFactory.register<IBanlistService>(createMyCardBanListService);
  ServiceFactory.register<MdPro3DeckService>(() => MdPro3DeckService());
  ServiceFactory.register<MycardDeckService>(() => MycardDeckService());
}
