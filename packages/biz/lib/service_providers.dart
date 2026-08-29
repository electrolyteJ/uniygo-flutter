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
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:service_loader/service_loader.dart';
import 'package:resource_card_mycard/ygo_card_mycard.dart' show MyCardCardService;
import 'package:resource_data/ygo_data.dart' show IBanlistService;
import 'package:resource_deck_mycard/ygo_deck_mycard.dart' show MycardDeckService;
import 'package:resource_strings_mycard/ygo_strings_mycard.dart';

export 'ygo_settings.dart';

part 'service_providers.g.dart';

/// 应用级 provider override 注册表：宿主 app（uniygopro）在启动时调用
/// [registerAppLevelOverrides] 注入跨包实现（如 duel_settings 的持久化设置
/// 与设置弹窗）。duel_room2 不依赖设置包，只消费 biz 里的 provider 契约。
///
/// 必须在首次访问 [duelRoomServiceContainer] 之前注册（late final 懒初始化），
/// 而容器在首个 DuelRoomPage 构建时才被触碰，故 main() 里注册即可。
List<Override> _appLevelOverrides = const [];

void registerAppLevelOverrides(List<Override> overrides) {
  _appLevelOverrides = [..._appLevelOverrides, ...overrides];
}

/// 服务层容器（应用级单例）。
///
/// DuelRoomPage 每次进房创建的 ProviderScope 都以它为 parent：
/// 房间/对局/聊天状态在房间 scope 内 override，随房间销毁回收；
/// 下列服务 provider 未 override，解析统一上溯到本容器，
/// 因此 dataService 的卡片缓存、ygoSoundService 的 AudioPlayer 池
/// 都是应用级单例（替代 duel_room1 的 ServiceSingleton），
/// 不随进出房间反复重建。
// late 必须保留：容器须在 registerAppLevelOverrides 之后才首次初始化
// （懒初始化捕获到最新 overrides），因此不能用 eager final。
// ignore: unnecessary_late
late final duelRoomServiceContainer = ProviderContainer(
  overrides: _appLevelOverrides,
);

// 全部 keepAlive: true：保持手写 Provider 的常驻语义，由
// duelRoomServiceContainer 承担应用级单例生命周期。

@Riverpod(keepAlive: true)
MyCardCardService cardService(Ref ref) =>
    ServiceFactory.create<MyCardCardService>();

/// AI 对局服务：需要注入卡片查询函数才能解析服务器下发的卡码。
@Riverpod(keepAlive: true)
AiDuelService aiDuelService(Ref ref) {
  final ai = ServiceFactory.create<AiDuelService>();
  ai.setCardConverter(ref.watch(cardServiceProvider).getCard);
  return ai;
}

/// 按 URI scheme 路由到 ws/tcp/ai/puzzle 底层实现的对局服务门面。
@Riverpod(keepAlive: true)
IDuelService duelService(Ref ref) => DuelService(
  wsDuelService: ServiceFactory.create<WebSocketDuelService>(),
  socketDuelService: ServiceFactory.create<SocketDuelService>(),
  aiDuelService: ref.watch(aiDuelServiceProvider),
  puzzleDuelService: ServiceFactory.create<PuzzleDuelService>(),
);

@Riverpod(keepAlive: true)
YgoDataService dataService(Ref ref) => YgoDataService(
  cardService: ref.watch(cardServiceProvider),
  banlistService: ServiceFactory.create<IBanlistService>(),
  deckService: ServiceFactory.create<MycardDeckService>(),
);

@Riverpod(keepAlive: true)
YgoSoundService ygoSoundService(Ref ref) => YgoSoundService();

/// 引擎字符串表（strings.conf）：MSG_HINT 提示文案。应用级单例，
/// 首次读取时后台抓取，未加载完成前 systemString 返回 null（降级为不显示文案）。
@Riverpod(keepAlive: true)
StringsService stringsService(Ref ref) {
  final service = StringsService();
  unawaited(service.load());
  return service;
}
