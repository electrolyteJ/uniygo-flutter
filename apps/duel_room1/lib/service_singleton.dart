import 'package:duelink_ai/duelink_ai.dart' show AiDuelService;
import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:duelink_socket/duelink_socket.dart' show SocketDuelService;
import 'package:duelink_websocket/duelink_websocket.dart'
    show WebSocketDuelService;
import 'package:service_loader/service_loader.dart';
import 'package:duel_room1/services/ygo_data_service.dart';
import 'package:ygo_card_baige/ygo_card_baige.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_deck_mycard/ygo_deck_mycard.dart';
import 'services/duel_service.dart';
import 'services/ygo_sound_service.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
class ServiceSingleton {
  YgoDataService? _dataService;
  final aiDuelService = ServiceFactory.create<AiDuelService>();
  // final cardService = ServiceFactory.create<BaigeCardService>();
  final cardService = ServiceFactory.create<MyCardCardService>();

  YgoDataService get dataService =>
      _dataService ??= YgoDataService(
        cardService: cardService,
        banlistService: ServiceFactory.create<IBanlistService>(),
        deckService: ServiceFactory.create<MycardDeckService>(),
      );
  DuelService? _duelService;

  DuelService get duelService =>
      _duelService ??= DuelService(
        wsDuelService: ServiceFactory.create<WebSocketDuelService>(),
        socketDuelService: ServiceFactory.create<SocketDuelService>(),
        aiDuelService: aiDuelService,
        puzzleDuelService: ServiceFactory.create<PuzzleDuelService>(),
      );

  IPuzzleService? _puzzleService;
  final ygoSoundService = YgoSoundService();

  /// 残局目录服务（残局房列表/详情）。
  IPuzzleService get puzzleService =>
      _puzzleService ??= ServiceFactory.create<IPuzzleService>();

  ServiceSingleton._() {
    aiDuelService.setCardConverter(cardService.getCard);
  }

  static final ServiceSingleton instance = ServiceSingleton._();
}
