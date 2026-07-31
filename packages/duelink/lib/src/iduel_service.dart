import 'dart:typed_data';

import 'package:service_loader/service_loader.dart';

import 'messages/ygo_stoc_msg.dart';
import 'model/room_state.dart';
import 'messages/ctos/ctos_game_msg_response.dart';
import 'types.dart';

/// 决斗服务接口。
///
/// 方法按玩家动作语义分组，与 ygopro 底层协议解耦。
///
/// ## 连接生命周期
/// - [connect] → [disconnect]
///
/// ## 房间生命周期
/// ```
/// connect → setPlayerName → enterRoom → submitDeck → ready → startDuel
///                                    ↑___________________↓
///                                    (ready / unready 切换)
/// ```
///
/// ## 猜拳 / 先后攻
/// ```
/// [RoomSelectingHand] → chooseHand → [RoomSelectingTurn] → chooseTurnOrder
/// ```
///
/// ## 对局中
/// - [playGameResponse] 回复服务端交互
/// - [surrender] 投降
/// - [confirmTime] 确认时间限制
///
/// ## 事件流
/// - [onServerMessage] 服务端消息
/// - [onRoomStateChange] 房间状态变化
abstract class IDuelService implements IService {
  // ─── 连接 ──────────────────────────────────────────

  Future<void> connect(String address, int port);

  Future<void> disconnect();

  ConnectionState get connectionState;

  // ─── 房间生命周期 ─────────────────────────────────

  /// 设置玩家名称（必须在 [enterRoom] 之前调用）。
  void setPlayerName(String name);

  /// 进入房间。
  ///
  /// [password] 由 [RoomPassword.encodeJoin] 或 [RoomPassword.encodeCreate] 生成。
  void enterRoom(String password);

  /// 提交卡组。
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck);

  /// 准备就绪。
  void ready();

  /// 取消准备。
  void unready();

  /// 开始对局（房主可用）。
  void startDuel();

  /// 踢出指定座位的玩家（房主可用）。
  void kickPlayer(int pos);

  /// 切换到观战者身份。
  void becomeObserver();

  /// 切换到决斗者身份。
  void becomeDuelist();

  // ─── 猜拳 / 先后攻 ─────────────────────────────────

  /// 选择猜拳（剪刀/石头/布）。
  void chooseHand(HandType hand);

  /// 选择先后攻。
  ///
  /// [goFirst] — `true` 为先攻，`false` 为后攻。
  void chooseTurnOrder(bool goFirst);

  // ─── 对局中 ───────────────────────────────────────

  /// 回复服务端的游戏内交互请求。
  void playGameResponse(CtosGameMsgResponse response);

  /// 投降。
  void surrender();

  /// 确认时间限制。
  void confirmTime();

  // ─── 社交 ─────────────────────────────────────────

  /// 发送聊天消息。
  void sendChat(String message);

  // ─── 事件流 ───────────────────────────────────────

  /// 服务端消息流（包含所有 [ygo_stoc_msg.YgoStocMsg]）。
  Stream<YgoStocMsg> get onServerMessage;

  /// 房间状态变化流（经过状态机解析后的高层语义）。
  Stream<RoomState> get onRoomStateChange;
}

/// 创建决斗服务实例。
///
/// [type] 为 [ServiceType] 中注册的类型标识。
IService createDuelService(int type) {
  return ServiceFactory.create(type);
}

/// 网络连接状态。
enum ConnectionState { disconnected, connecting, connected, error }

/// 传输层抽象 — 网络数据包的发送与接收。
///
/// 每种连接场景提供一个实现：
/// - [OnlineConnection]（WebSocket）
/// - [AiConnection]（本地模拟）
/// - [LanConnection]（TCP 直连）
abstract class DuelConnection {
  Future<void> connect(String address, int port);

  void send(Uint8List data);

  Stream<Uint8List> get messages;

  Future<void> disconnect();

  Stream<ConnectionState> get state;
}
