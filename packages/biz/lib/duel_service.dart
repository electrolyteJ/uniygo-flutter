import 'dart:typed_data';

import 'package:applog/console.dart' as console;
import 'package:duelink/duelink.dart';
import 'package:path_provider/path_provider.dart';
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
    // 进房即开启房间会话日志：覆盖重写 duel_latest.log，直至 disconnect。
    // 日志系统失败只退化为仅控制台，绝不影响进房。
    await _startDuelLogSession();
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
  Future<void> disconnect() async {
    try {
      await _svc.disconnect();
    } finally {
      await console.DuelLogSession.stop();
    }
  }

  /// 开启房间会话日志：应用文档目录/logs/duel_latest.log（覆盖写）。
  Future<void> _startDuelLogSession() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      // 正斜杠拼接：dart:io File 全平台（含 Windows）均接受。
      final path = '${docs.path}/logs/duel_latest.log';
      await console.DuelLogSession.start(path);
      if (console.DuelLogSession.isActive) {
        console.log('Duel log file: $path', name: 'DuelService');
      }
    } catch (e) {
      console.log('Duel log session unavailable: $e', name: 'DuelService');
    }
  }

  @override
  void setPlayerName(String name) => _svc.setPlayerName(name);

  @override
  void enterRoom(String password) => _svc.enterRoom(password);

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck, [Uint8List? sideDeck]) =>
      _svc.submitDeck(mainDeck, extraDeck, sideDeck);

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
