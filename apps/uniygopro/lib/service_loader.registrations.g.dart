// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:duelink_ai/duelink_ai.dart';
import 'package:duelink_puzzle/duelink_puzzle.dart';
import 'package:duelink_puzzle/src/puzzle_service.dart';
import 'package:duelink_socket/duelink_socket.dart';
import 'package:duelink_websocket/duelink_websocket.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';
import 'package:duelink_websocket/duelink_websocket.dart' as _i1;
import 'package:duelink_ai/duelink_ai.dart' as _i2;
import 'package:duelink_puzzle/duelink_puzzle.dart' as _i3;
import 'package:ygo_card_mycard/ygo_card_mycard.dart' as _i4;
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart' as _i5;
import 'package:ygo_deck_mdpro3/services/deck_service.dart' as _i6;

/// 注册本包内所有标注了 [Service] 的服务。
void registerAllServices() {
  _i1.onServiceRegister();
  _i2.onServiceRegister();
  _i3.onServiceRegister();
  _i4.onServiceRegister();
  _i5.onServiceRegister();
  _i6.onServiceRegister();
  ServiceFactory.register<WebSocketDuelService>(() => WebSocketDuelService());
  ServiceFactory.register<SocketDuelService>(() => SocketDuelService());
  ServiceFactory.register<AiDuelService>(() => AiDuelService());
  ServiceFactory.register<PuzzleDuelService>(() => PuzzleDuelService());
  ServiceFactory.register<IPuzzleService>(() => PuzzleService());
  ServiceFactory.register<ICardService>(createMyCardCardService);
  ServiceFactory.register<IBanlistService>(createMyCardBanListService);
  ServiceFactory.register<IDeckService>(() => DeckService());
}
