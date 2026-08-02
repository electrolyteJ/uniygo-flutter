import 'package:flutter/foundation.dart';
import 'package:duelink/duelink.dart';
import '../config/servers.dart';

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
  String password = '';

  /// 是否为房主（创建房间模式）
  bool isHost = false;

  /// 创建房间时的房间名称
  String roomName = '';

  /// 玩家用户名
  String username = 'Guest';

  /// 创建房间时的规则参数
  RoomOptions? roomOptions;

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
    this.password = password;
    notifyListeners();
  }

  /// 更新自由房间环境（不改变其他状态）
  void setEnvironment(DuelEnvironment env) {
    environment = env;
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
    password = '';
    isHost = false;
    roomName = '';
    username = 'Guest';
    roomOptions = null;
    notifyListeners();
  }
}
