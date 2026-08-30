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
/// 与协议/状态层无关的纯泛型工具：音效、战报、画面随消费节奏自然错开。
class MessagePump<T> {
  MessagePump({required void Function(T message) consume})
      : _consume = consume;

  final void Function(T) _consume;
  final Queue<T> _queue = Queue<T>();
  Timer? _timer;
  bool _disposed = false;

  /// 节奏档位（按消费后的剩余积压量选择下一条间隔），从松到紧排列。
  static const List<({int maxBacklog, Duration interval})> paceTiers = [
    (maxBacklog: 20, interval: Duration(milliseconds: 120)),
    (maxBacklog: 100, interval: Duration(milliseconds: 40)),
    (maxBacklog: 1 << 30, interval: Duration(milliseconds: 12)),
  ];

  /// 待消费消息数（测试与调试观测用）。
  int get pendingCount => _queue.length;

  /// 积压量 → 消费间隔。暴露为 static 便于单测直接断言档位边界。
  static Duration intervalForBacklog(int backlog) {
    for (final tier in paceTiers) {
      if (backlog <= tier.maxBacklog) return tier.interval;
    }
    return paceTiers.last.interval;
  }

  /// 入队。泵空闲（无待触发定时器）时首条同步直通消费，实现 0ms 直通。
  void enqueue(T message) {
    if (_disposed) return;
    _queue.add(message);
    if (_timer == null) _drainOne();
  }

  /// 停止泵：取消定时器、清空队列，后续入队被忽略。
  void dispose() {
    _disposed = true;
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _drainOne() {
    _timer = null;
    if (_queue.isEmpty) return;
    final message = _queue.removeFirst();
    try {
      _consume(message);
    } catch (e, s) {
      // 单条消息的消费异常不应让整条泵停摆（否则对局静默卡死）。
      console.log('MessagePump consume error: $e\n$s');
    }
    if (_disposed) {
      _queue.clear();
      return;
    }
    // 每次消费后都排冷却窗口（队列空按最小积压档 120ms）：窗口内到达的
    // 消息入队等待，窗口到期后队列为空则泵回到空闲（下一条直通）。
    // 若只在队列非空时排定时器，爆发循环里每条消息都会看到空闲泵而被
    // 同步直通，节奏彻底失效。
    final backlog = _queue.isEmpty ? 1 : _queue.length;
    _timer = Timer(intervalForBacklog(backlog), _drainOne);
  }
}
