/// 对战服务器列表配置。
library;

/// 服务器类型
enum ServerType {
  /// 竞技匹配 — 自动撮合，天梯排名
  matchAthletic,

  /// 娱乐匹配 — 自动撮合，无排名
  matchEntertain,

  /// 自由房间 — 手动创建/加入房间（含多环境）
  freeRoom,

  /// AI 对决 — 本地人机对战（无需联网）
  aiRoom,

  /// 残局房 — 本地预设残局挑战（无需联网/卡组）
  puzzleRoom,

  /// 怪兽动画 — cardlive 召唤动画鉴赏（无需联网）
  monsterLive,
}

/// 单个对战服务器的配置。
class GameServer {
  final String id;
  final String displayName;
  final String description;
  final String host;
  final int port;
  final ServerType type;
  final bool requiresMatchApi;

  const GameServer({
    required this.id,
    required this.displayName,
    required this.description,
    required this.host,
    required this.port,
    required this.type,
    this.requiresMatchApi = false,
  });

  String get wsUrl => 'wss://$host:$port';
}

/// 自由房间可选环境
enum DuelEnvironment {
  /// 默认 Koishi 通用环境
  koishi("wss", 'Koishi', 'koishi.momobako.com', 7211),

  /// 默认 mycard 自定义房间
  mycard("wss", 'mycard', 'tiramisu.moenext.com', 7912),
  mercury233("tcp", 'mercury233', 's1.ygo233.com', 233),

  /// 233 服无禁限端口：无禁限卡表 + 部分卡片使用原版效果。
  mercury233_2012("tcp", 'mercury233无禁限', 's1.ygo233.com', 2012),

  /// 先行卡测试环境
  koishi_preRelease("wss", 'koishi先行卡测试', 'koishi.momobako.com', 889),
  mycard_preRelease("wss", 'mycard先行卡测试', 'mygo.superpre.pro', 888),
  mercury233_preRelease("tcp", 'mercury233先行卡测试', 's1.ygo233.com', 23333),

  /// 408 特殊规则环境
  env408("wss", '408 环境', 'koishi.momobako.com', 1408),

  /// YGOPro PC LAN 服务器
  ygopro("wss", 'YGOPro LAN', '', 7911),

  /// AI 本地人机对战（本地 ocgcore 引擎模拟服务端，无需联网）
  ai("ai", 'AI 人机对战', 'localhost', 0),

  /// 残局挑战（本地 ocgcore 引擎加载残局脚本，无需联网/卡组）
  puzzle("puzzle", '残局挑战', 'local', 0);

  final String displayName;
  final String schema;
  final String host;
  final int port;

  const DuelEnvironment(this.schema, this.displayName, this.host, this.port);

  /// 是否允许创建房间（Koishi/先行卡/408 只允许加入）
  bool get canCreate =>
      this == mycard ||
      this == ygopro ||
      this == mercury233 ||
      this == mercury233_2012;

  /// 是否为 AI 本地人机对战环境
  bool get isAi => this == ai;

  /// 是否为残局挑战环境
  bool get isPuzzle => this == puzzle;

  /// 是否使用编码密码（RoomPassword），MyCard 服务器需要解码参数
  bool get useEncodedPassword => this == mycard;

  bool get usesRoomStringDsl =>
      this == mercury233 ||
      this == mercury233_preRelease ||
      this == mercury233_2012;
}

/// 所有可用对战服务器列表。
const List<GameServer> gameServers = [
  GameServer(
    id: 'match-athletic',
    displayName: '竞技匹配',
    description: '自动撮合，天梯排名对战',
    host: 'tiramisu.moenext.com',
    port: 8912,
    type: ServerType.matchAthletic,
    requiresMatchApi: true,
  ),
  GameServer(
    id: 'match-entertain',
    displayName: '娱乐匹配',
    description: '自动撮合，休闲娱乐对战',
    host: 'tiramisu.moenext.com',
    port: 7912,
    type: ServerType.matchEntertain,
    requiresMatchApi: true,
  ),
  GameServer(
    id: 'free-room',
    displayName: '自由房间',
    description: '创建/加入房间，支持多种环境',
    host: 'koishi.momobako.com',
    port: 7211,
    type: ServerType.freeRoom,
  ),
  GameServer(
    id: 'ai-room',
    displayName: 'AI 对决',
    description: '与本地 AI 进行单局对战，无需联网',
    host: 'localhost',
    port: 0,
    type: ServerType.aiRoom,
  ),
  GameServer(
    id: 'puzzle-room',
    displayName: '残局房',
    description: '挑战预设残局，在固定局面中一回合取胜',
    host: 'local',
    port: 0,
    type: ServerType.puzzleRoom,
  ),
  GameServer(
    id: 'card-live',
    displayName: '怪兽动画',
    description: '怪兽召唤动画鉴赏，3D 演出循环播放',
    host: 'local',
    port: 0,
    type: ServerType.monsterLive,
  ),
];
