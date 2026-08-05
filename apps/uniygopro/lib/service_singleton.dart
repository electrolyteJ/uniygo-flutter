import 'package:duelink_ai/duelink_ai.dart' show AiDuelService;
import 'package:duelink_socket/duelink_socket.dart' show SocketDuelService;
import 'package:duelink_websocket/duelink_websocket.dart' show WebSocketDuelService;
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/services/YgoDataService.dart';
import 'package:ygo_data/ygo_data.dart';

import 'services/DuelService.dart';

class ServiceSingleton {
  YgoDataService? _dataService;

  YgoDataService get dataService => _dataService ??= YgoDataService(
    cardService: ServiceFactory.create<ICardService>(),
    banlistService: ServiceFactory.create<IBanlistService>(),
    // deckService: ServiceFactory.create<IDeckService>(),
  );
  DuelService? _duelService;

  DuelService get duelService =>
      _duelService ??= DuelService(
        wsDuelService: ServiceFactory.create<WebSocketDuelService>(),
        socketDuelService: ServiceFactory.create<SocketDuelService>(),
        aiDuelService: ServiceFactory.create<AiDuelService>(),
      );

  ServiceSingleton._();

  static final ServiceSingleton instance = ServiceSingleton._();
}
