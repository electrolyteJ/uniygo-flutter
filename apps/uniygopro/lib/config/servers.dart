/// 对战服务器列表配置。
///
/// 地址来源与验证（2026-08-21 实测）：
/// - neos-ts `neos.config.json` 公共服逐一对照：koishi 7211 /
///   tiramisu 8912(竞技)·7912(娱乐·自定义) / koishi 889(先行卡) /
///   koishi 1408(408 环境) —— WSS 握手全部 101 ✓
/// - 233 服（s1.ygo233.com 233/23333）—— ygopro TCP 协议握手有响应 ✓
/// - MDPro3 超先行卡（mygo.superpre.pro:888 / mygo2.superpre.pro:888）
///   —— ygopro TCP 协议握手有响应 ✓（注意：**裸 TCP，不支持 WSS**）
/// - 观战端口（tiramisu.moecube.com:8923 竞技 / :7923 娱乐）
///   —— WSS 101 ✓，供将来观战功能接入
///
/// 已排除（端口开放但协议握手无响应，疑似停止服务或协议不兼容）：
/// - server.evolutionygo.com:7711/7911（Evolution Server，
///   见 diangogav/EDOpro-server-ts；MDPro3 手册记载）
/// - duels.link:2333（MDPro3 手册记载）
/// - koishi.momobako.com:7210/1311（MDPro3 手册称 OCG/TCG 口，
///   实测 TLS/裸TCP/裸WS 均无响应）
/// - MDPro3 的 zgai.tech:38443 是 HTTP API（非 ygopro 房间协议），
///   不在此列表。
///
/// MyCard 系服务（竞技/娱乐匹配、mycard 自由房间环境）需要 MyCard
/// 账号登录（account_mycard；匹配用 u16Secret 时间轮换密钥）。
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

  /// 竞技观战 — 观看天梯排名中的实时对局
  spectateAthletic,

  /// 娱乐观战 — 观看休闲娱乐中的实时对局
  spectateEntertain,
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

  /// 观战进场用的实际决斗服务器地址（观战列表在 [host]:[port]，
  /// 但点击「观看」要连到对应匹配服）。仅观战类服务器使用。
  final String? duelHost;
  final int? duelPort;

  const GameServer({
    required this.id,
    required this.displayName,
    required this.description,
    required this.host,
    required this.port,
    required this.type,
    this.requiresMatchApi = false,
    this.duelHost,
    this.duelPort,
  });

  String get wsUrl => 'wss://$host:$port';
}

/// 自由房间可选环境
enum DuelEnvironment {
  /// 默认 Koishi 通用环境（neos「koishi」公共服）
  koishi("wss", 'Koishi', 'koishi.momobako.com', 7211),

  /// 默认 mycard 自定义房间（neos「mycard-custom」；需 MyCard 登录）
  mycard("wss", 'mycard', 'tiramisu.moenext.com', 7912),

  /// 233 服（mercury233 协议，房间字符串 DSL）
  mercury233("tcp", 'mercury233', 's1.ygo233.com', 233),

  /// 先行卡测试环境（neos「pre-release」）
  koishi_preRelease("wss", 'koishi先行卡测试', 'koishi.momobako.com', 889),

  /// mycard 先行卡测试（mygo.superpre.pro，裸 TCP 协议验证通过；
  /// 实测不支持 WSS，schema 必须为 tcp）
  mycard_preRelease("tcp", 'mycard先行卡测试', 'mygo.superpre.pro', 888),

  /// mycard 先行卡测试 2 服（mygo2.superpre.pro，裸 TCP 协议验证通过）
  mycard_preRelease2("tcp", 'mycard先行卡测试 2 服', 'mygo2.superpre.pro', 888),

  /// 233 服先行卡测试
  mercury233_preRelease("tcp", 'mercury233先行卡测试', 's1.ygo233.com', 23333),

  /// 408 特殊规则环境（neos「408」）
  env408("wss", '408 环境', 'koishi.momobako.com', 1408),

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
  bool get canCreate => this == mycard || this == mercury233;

  /// 是否为 AI 本地人机对战环境
  bool get isAi => this == ai;

  /// 是否为残局挑战环境
  bool get isPuzzle => this == puzzle;

  /// 是否使用编码密码（RoomPassword），MyCard 服务器需要解码参数
  bool get useEncodedPassword => this == mycard;

  bool get usesRoomStringDsl =>
      this == mercury233 || this == mercury233_preRelease;
}

/// 所有可用对战服务器列表。
const List<GameServer> gameServers = [
  // neos「mycard-athletic」（需 MyCard 登录 + u16Secret）
  GameServer(
    id: 'match-athletic',
    displayName: '竞技匹配',
    description: '自动撮合，天梯排名对战',
    host: 'tiramisu.moenext.com',
    port: 8912,
    type: ServerType.matchAthletic,
    requiresMatchApi: true,
  ),
  // neos「mycard-custom」同端口兼作娱乐匹配入口（需 MyCard 登录）
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
    id: 'spectate-athletic',
    displayName: '竞技观战',
    description: '观看天梯排名中的实时对局',
    host: 'tiramisu.moecube.com',
    port: 8923,
    duelHost: 'tiramisu.moenext.com',
    duelPort: 8912,
    type: ServerType.spectateAthletic,
  ),
  GameServer(
    id: 'spectate-entertain',
    displayName: '娱乐观战',
    description: '观看休闲娱乐中的实时对局',
    host: 'tiramisu.moecube.com',
    port: 7923,
    duelHost: 'tiramisu.moenext.com',
    duelPort: 7912,
    type: ServerType.spectateEntertain,
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
