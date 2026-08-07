import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';

/// 统一决斗服务门面 — 根据 connect 的协议 scheme 自动路由到底层实现。
///
/// | Scheme     | 底层服务              |
/// |------------|----------------------|
/// | `ai://`    | [AiDuelService]      |
/// | `puzzle://`| [PuzzleDuelService]  |
/// | `ws://` / `wss://` | [WebSocketDuelService] |
/// | `tcp://`   | [SocketDuelService]  |
/// | (无 scheme) | 默认 WebSocket       |
class DuelService implements IDuelService {
  final IDuelService _wsDuelService;
  final IDuelService _socketDuelService;
  final IDuelService _aiDuelService;
  final IDuelService _puzzleDuelService;

  IDuelService? _activeService;

  DuelService({
    required IDuelService wsDuelService,
    required IDuelService socketDuelService,
    required IDuelService aiDuelService,
    required IDuelService puzzleDuelService,
  }) : _wsDuelService = wsDuelService,
       _socketDuelService = socketDuelService,
       _aiDuelService = aiDuelService,
       _puzzleDuelService = puzzleDuelService;

  /// 当前活跃的底层服务。
  ///
  /// 若尚未调用 [connect]，回退到 WebSocket。
  IDuelService get _svc => _activeService ?? _wsDuelService;

  @override
  Future<void> connect(Uri address) async {
    final scheme = address.hasScheme ? address.scheme : null;
    switch (scheme) {
      case 'ai':
        _activeService = _aiDuelService;
        break;
      case 'puzzle':
        _activeService = _puzzleDuelService;
        break;
      case 'tcp':
        _activeService = _socketDuelService;
        break;
      case 'ws':
      case 'wss':
      default:
        _activeService = _wsDuelService;
        break;
    }

    await _activeService!.connect(address);
  }

  @override
  ConnectionState get connectionState => _svc.connectionState;

  @override
  Future<void> disconnect() => _svc.disconnect();

  @override
  void setPlayerName(String name) => _svc.setPlayerName(name);

  @override
  void enterRoom(String password) => _svc.enterRoom(password);

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck) =>
      _svc.submitDeck(mainDeck, extraDeck);

  @override
  void ready() => _svc.ready();

  @override
  void unready() => _svc.unready();

  @override
  void startDuel() => _svc.startDuel();

  @override
  void kickPlayer(int pos) => _svc.kickPlayer(pos);

  @override
  void becomeObserver() => _svc.becomeObserver();

  @override
  void becomeDuelist() => _svc.becomeDuelist();

  @override
  void chooseHand(HandType hand) => _svc.chooseHand(hand);

  @override
  void chooseTurnOrder(bool goFirst) => _svc.chooseTurnOrder(goFirst);

  @override
  void playGameResponse(CtosGameMsgResponse response) =>
      _svc.playGameResponse(response);

  @override
  void surrender() => _svc.surrender();

  @override
  void confirmTime() => _svc.confirmTime();

  @override
  void sendChat(String message) => _svc.sendChat(message);

  @override
  Stream<YgoStocMsg> get onServerMessage => _svc.onServerMessage;

  @override
  Stream<YgoStocMsg> get onChatServerMessage => _svc.onChatServerMessage;

  @override
  Stream<RoomStage> get onRoomStageChange => _svc.onRoomStageChange;

  @override
  Stream<DuelPhase> get onDuelPhaseMessage => _svc.onDuelPhaseMessage;
}
