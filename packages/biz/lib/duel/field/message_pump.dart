import 'dart:async';
import 'dart:collection';

import 'package:applog/console.dart' as console;

/// 对局消息节奏泵：把瞬时爆发的消息流摊平成自适应节奏的逐条消费。
///
/// 背景：竞技观战中途加入时，服务器会把开局以来的整段对局消息一次性推
/// 过来（数百条），收到即分发会让 UI 在一瞬间刷新几百次，画面过快过乱。
/// 泵把消息先入队，按积压量自适应降档消费：积压越深节奏越快，追平后
/// 恢复 0ms 直通（玩家正常操作零感知延迟）。
///
/// 观战可切换两种模式（由 router 按设置与观战身份驱动）：
/// - 带节奏回放（默认）：上述自适应节奏；
/// - 跳到当前局面（[jumpToCurrent]）：积压超 [kJumpBacklogThreshold] 时
///   抛弃节奏，同步静音清空整条队列，直接落位到最新局面。
///
/// 与协议/状态层无关的纯泛型工具：音效、战报、画面随消费节奏自然错开。
class MessagePump<T> {
  MessagePump(
      {required void Function(T message, {required bool silent}) consume})
      : _consume = consume;

  final void Function(T, {required bool silent}) _consume;
  final Queue<T> _queue = Queue<T>();
  Timer? _timer;
  bool _disposed = false;

  /// 观战「跳到当前局面」模式：积压超阈值时同步静音清场。
  /// 仅观战局由 router 开启；运行时可改。
  bool jumpToCurrent = false;

  /// 回放速度倍率：消费间隔 = 档位间隔 ÷ speedFactor（2.0 = 快一倍）。
  double speedFactor = 1.0;

  /// 触发「跳到当前局面」静默清场的积压阈值。
  static const int kJumpBacklogThreshold = 20;

  /// 节奏档位（按消费后的剩余积压量选择下一条间隔），从松到紧排列。
  static const List<({int maxBacklog, Duration interval})> paceTiers = [
    (maxBacklog: 20, interval: Duration(milliseconds: 120)),
    (maxBacklog: 100, interval: Duration(milliseconds: 40)),
    (maxBacklog: 1 << 30, interval: Duration(milliseconds: 12)),
  ];

  /// 待消费消息数（测试与调试观测用）。
  int get pendingCount => _queue.length;

  /// 积压量 → 消费间隔（已按 [speedFactor] 缩放）。
  Duration intervalForBacklog(int backlog) {
    for (final tier in paceTiers) {
      if (backlog <= tier.maxBacklog) {
        return tier.interval * (1.0 / speedFactor);
      }
    }
    return paceTiers.last.interval * (1.0 / speedFactor);
  }

  /// 入队。泵空闲（无待触发定时器）时首条同步直通消费，实现 0ms 直通。
  void enqueue(T message) {
    if (_disposed) return;
    _queue.add(message);
    if (jumpToCurrent && _queue.length > kJumpBacklogThreshold) {
      // 跳到当前局面：取消节奏，同步静音清空积压；随后排一个冷却窗口，
      // 避免爆发中后续消息穿透直通（每条都带音效就乱了）。
      _timer?.cancel();
      while (_queue.isNotEmpty && !_disposed) {
        _consumeOne(_queue.removeFirst(), silent: true);
      }
      if (_disposed) {
        _queue.clear();
        return;
      }
      _timer = Timer(intervalForBacklog(1), _drainOne);
      return;
    }
    if (_timer == null) _drainOne();
  }

  /// 丢弃全部待消费消息并停止调度（MSG_START 局间切换清上局残留）。
  /// 不影响后续入队。
  void clear() {
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  /// 停止泵：取消定时器、清空队列，后续入队被忽略。
  void dispose() {
    _disposed = true;
    clear();
  }

  void _drainOne() {
    _timer = null;
    if (_queue.isEmpty) return;
    _consumeOne(_queue.removeFirst(), silent: false);
    if (_disposed) {
      _queue.clear();
      return;
    }
    // 每次消费后都排冷却窗口（队列空按最小积压档）：窗口内到达的
    // 消息入队等待，窗口到期后队列为空则泵回到空闲（下一条直通）。
    // 若只在队列非空时排定时器，爆发循环里每条消息都会看到空闲泵而被
    // 同步直通，节奏彻底失效。
    final backlog = _queue.isEmpty ? 1 : _queue.length;
    _timer = Timer(intervalForBacklog(backlog), _drainOne);
  }

  void _consumeOne(T message, {required bool silent}) {
    try {
      _consume(message, silent: silent);
    } catch (e, s) {
      // 单条消息的消费异常不应让整条泵停摆（否则对局静默卡死）。
      console.log('MessagePump consume error: $e\n$s');
    }
  }
}
