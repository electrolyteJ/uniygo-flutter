import 'dart:async';

import 'package:biz/duel_service.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' show IDuelService;
import 'package:duelink_ai/duelink_ai.dart' show AiDuelService;
import 'package:duelink_ai_edo/duelink_puzzle.dart' show PuzzleDuelService;
import 'package:duelink_socket/duelink_socket.dart' show SocketDuelService;
import 'package:duelink_websocket/duelink_websocket.dart'
    show WebSocketDuelService;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart' show MyCardCardService;
import 'package:ygo_data/ygo_data.dart' show IBanlistService;
import 'package:ygo_deck_mycard/ygo_deck_mycard.dart' show MycardDeckService;
import 'package:ygo_strings_mycard/ygo_strings_mycard.dart';

/// 服务层容器（应用级单例）。
///
/// DuelRoomPage 每次进房创建的 ProviderScope 都以它为 parent：
/// 房间/对局/聊天状态在房间 scope 内 override，随房间销毁回收；
/// 下列服务 provider 未 override，解析统一上溯到本容器，
/// 因此 dataService 的卡片缓存、ygoSoundService 的 AudioPlayer 池
/// 都是应用级单例（替代 duel_room1 的 ServiceSingleton），
/// 不随进出房间反复重建。
final duelRoomServiceContainer = ProviderContainer();

final cardServiceProvider = Provider<MyCardCardService>(
  (ref) => ServiceFactory.create<MyCardCardService>(),
);

/// AI 对局服务：需要注入卡片查询函数才能解析服务器下发的卡码。
final aiDuelServiceProvider = Provider<AiDuelService>((ref) {
  final ai = ServiceFactory.create<AiDuelService>();
  ai.setCardConverter(ref.watch(cardServiceProvider).getCard);
  return ai;
});

/// 按 URI scheme 路由到 ws/tcp/ai/puzzle 底层实现的对局服务门面。
final duelServiceProvider = Provider<IDuelService>(
  (ref) => DuelService(
    wsDuelService: ServiceFactory.create<WebSocketDuelService>(),
    socketDuelService: ServiceFactory.create<SocketDuelService>(),
    aiDuelService: ref.watch(aiDuelServiceProvider),
    puzzleDuelService: ServiceFactory.create<PuzzleDuelService>(),
  ),
);

final dataServiceProvider = Provider<YgoDataService>(
  (ref) => YgoDataService(
    cardService: ref.watch(cardServiceProvider),
    banlistService: ServiceFactory.create<IBanlistService>(),
    deckService: ServiceFactory.create<MycardDeckService>(),
  ),
);

final ygoSoundServiceProvider = Provider<YgoSoundService>(
  (ref) => YgoSoundService(),
);

/// 引擎字符串表（strings.conf）：MSG_HINT 提示文案。应用级单例，
/// 首次读取时后台抓取，未加载完成前 systemString 返回 null（降级为不显示文案）。
final stringsServiceProvider = Provider<StringsService>((ref) {
  final service = StringsService();
  unawaited(service.load());
  return service;
});
