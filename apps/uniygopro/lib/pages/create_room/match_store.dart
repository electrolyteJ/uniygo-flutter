import 'package:uniygopro/config/servers.dart';
import 'package:flutter/foundation.dart';
import 'package:duelink/duelink.dart';

/// 匹配与建房上下文仓库。
///
/// 负责保存当前选择的服务器、环境、房间名、连接地址、
/// 匹配结果以及玩家身份等会在页面间流转的信息。
class MatchStore extends ChangeNotifier {
  bool isSearching = false;
  String? arena;
  String? serverAddress;
  int? serverPort;
  String? serverPassword;

  GameServer? selectedServer;
  DuelEnvironment environment = DuelEnvironment.koishi;

  /// 是否为房主（创建房间模式）
  bool isHost = false;

  /// 创建房间时的房间名称
  String roomName = '';

  /// 玩家用户名
  String username = 'Guest';

  /// 创建房间时的规则参数
  RoomOptions? roomOptions;

  /// 残局模式选中的残局脚本名（`puzzle/<category>/<file>.lua`），
  /// 仅 [DuelEnvironment.puzzle] 环境使用。
  String? puzzleScript;
  Uri? get uri{
    // 残局环境：URI 路径携带残局脚本（puzzle://local/<category>/<file>.lua），
    // 路径段逐个编码以兼容空格/方括号等特殊字符。
    final Uri? uri;
    if (environment.isPuzzle) {
      final script = puzzleScript;
      if (script == null || script.isEmpty) {
        return null;
      }
      final rel = script.startsWith('puzzle/') ? script.substring(7) : script;
      final encoded = rel.split('/').map(Uri.encodeComponent).join('/');
      uri = Uri.tryParse('${environment.schema}://$serverAddress/$encoded');
    } else if (environment.isAi) {
      // AI 环境：房间参数经 URI 查询参数传递给本地引擎连接。
      final base = Uri.tryParse('${environment.schema}://$serverAddress:$serverPort');
      uri = base?.replace(queryParameters: roomOptions?.toAiQuery());
    } else {
      uri = Uri.tryParse('${environment.schema}://$serverAddress:$serverPort');
    }
    return uri;
  }
  /// 生成进入决斗房间页所需的路由参数快照（经路由 extra 传递）。
  Map<String, Object?> toDuelRoomParams() {
    return {
      'uri': uri,
      'serverPassword': serverPassword,
      'username': username,
      'roomName': roomName,
    };
  }

  /// 配置创建房间流程中需要跨页面传递的房间信息。
  void configureCreatedRoom({
    required RoomOptions roomOptions,
    required String roomName,
  }) {
    this.roomOptions = roomOptions;
    this.roomName = roomName;
    isHost = true;
    notifyListeners();
  }

  /// 更新匹配或手动进房时使用的玩家名。
  void setUsername(String username) {
    this.username = username;
    notifyListeners();
  }

  void startSearching(String arena) {
    this.arena = arena;
    isSearching = true;
    notifyListeners();
  }

  void stopSearching() {
    isSearching = false;
    notifyListeners();
  }

  void setMatchResult(String address, int port, String password) {
    serverAddress = address;
    serverPort = port;
    serverPassword = password;
    isSearching = false;
    notifyListeners();
  }

  /// 选择服务器 + 环境，设置连接信息
  void selectServer(GameServer server, DuelEnvironment env, String password) {
    selectedServer = server;
    environment = env;
    serverAddress = env.host;
    serverPort = env.port;
    serverPassword = password;
    notifyListeners();
  }

  /// 更新自由房间环境（不改变其他状态）
  void setEnvironment(DuelEnvironment env) {
    environment = env;
    notifyListeners();
  }

  /// 选择残局（残局房流程）：记录残局脚本并切换到 puzzle 环境。
  void selectPuzzle(GameServer server, String scriptName) {
    selectedServer = server;
    environment = DuelEnvironment.puzzle;
    puzzleScript = scriptName;
    serverAddress = DuelEnvironment.puzzle.host;
    serverPort = DuelEnvironment.puzzle.port;
    serverPassword = '';
    notifyListeners();
  }

  void reset() {
    isSearching = false;
    arena = null;
    serverAddress = null;
    serverPort = null;
    serverPassword = null;
    selectedServer = null;
    environment = DuelEnvironment.koishi;
    isHost = false;
    roomName = '';
    username = 'Guest';
    roomOptions = null;
    puzzleScript = null;
    notifyListeners();
  }
}
