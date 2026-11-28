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

  /// 暂停消费：消息照常入队，但不出队、不派发。
  ///
  /// 用途是**入场演出期间压住决斗消息**——演出还没完，玩家已经在加载页
  /// 听到对方召唤怪兽/发动卡片，视觉与听觉对不上。暂停而不是 `clear()`：
  /// clear 会丢掉这些消息，场地页落地时状态就是错的（少召唤了怪兽）；
  /// 暂停只是把它们攒在队列里，恢复后按节奏放出来。
  ///
  /// 恢复方式是**两步**：先 `paused = false`，再调 [resume] 抢一拍立刻开播。
  /// 只做第一步也能恢复（排空链在暂停期间自续，见 [_drainOne]），只是最多
  /// 晚一个节奏档位；两步都做则无延迟。
  bool get paused => _paused;
  bool _paused = false;

  /// 暂停消费；重复调用无副作用。
  ///
  /// **不取消在飞的定时器**：排空链（`_timer → _drainOne → _timer`）由
  /// [_drainOne] 自己续，暂停只让每一拍变成空转。若在这里 cancel，链就断在
  /// 了暂停那一刻，必须完全依赖外部正确调用 [resume] 才能复活——这正是
  /// 「进入场地页对面完全不动」的成因。让它自续排，是让暂停成为**可逆的
  /// 状态**而不是一次不可恢复的中断。
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    // 从空闲态进入暂停：没有链可续，主动起一拍，让暂停期间入队的消息
    // 也有排空机会（恢复后不必等外部 resume 才动）。
    if (value && _timer == null && !_disposed) {
      _timer = Timer(paceTiers.first.interval, _drainOne);
    }
  }

  /// 恢复消费：改回 [paused] = false 后调用。
  ///
  /// 幂等：重复调用、或队列已空时都是无操作。
  ///
  /// 暂停期间排空链仍在自续（见 [paused]），所以这里**抢一拍**：把暂停
  /// 期空转排下的定时器换成立即触发，让积压消息马上开始放，而不是再等
  /// 一个 120ms 的上限。
  void resume() {
    if (_disposed || _paused) return;
    if (_queue.isEmpty) return;
    if (_timer != null) {
      // 在飞的只是暂停期的空转拍，换成零延时立刻消费。
      _timer!.cancel();
      _timer = null;
    }
    _timer = Timer(Duration.zero, _drainOne);
  }

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
    if (paused) return;
    if (jumpToCurrent && _queue.length > kJumpBacklogThreshold) {
      // 跳到当前局面：取消节奏，同步静音清空积压；随后排一个冷却窗口，
      // 避免爆发中后续消息穿透直通（每条都带音效就乱了）。
      flushSilent();
      if (_disposed) return;
      // flushSilent 把定时器也取消了，这里重新挂一拍：既维持后续消息的
      // 节奏窗口，也保证排空链在任何情况下都不会停在 flush 之后。
      _timer = Timer(intervalForBacklog(1), _drainOne);
      return;
    }
    if (_timer == null) _drainOne();
  }

  /// 同步静音排空全部积压：取消节奏定时器，队列逐条 silent 消费完。
  ///
  /// 两个用途：观战「跳到当前局面」的追平清场；断连结算收尾——
  /// 服务器在关连接前的最后一个 TCP 段里发了 MSG_WIN 时，不等节奏
  /// 泵慢慢排空，直接落位到终局状态（duelResult 立即可读）。
  ///
  /// 暂停期间调用无效（入场演出还在放，不能抢跑）；调用方应在 resume
  /// 之后再决定是否清场。
  void flushSilent() {
    if (paused) return;
    _timer?.cancel();
    _timer = null;
    while (_queue.isNotEmpty && !_disposed) {
      _consumeOne(_queue.removeFirst(), silent: true);
    }
    if (_disposed) _queue.clear();
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
    if (_disposed) return;
    // 暂停期间到点的定时器：不消费，**但要续排自己**，不能让排空链断掉。
    //
    // 这里曾经直接 `return`，把 `_timer` 留在 null —— 等于「暂停期间定时器
    // 空烧后排在链尾的那一条被吃掉」。恢复时 `resume()` 虽然会补排一次，
    // 但只要任何一处忘了 resume（或 resume 早于最后一条消息入队），队列就
    // 再没有东西推进，表现为「进入场地页对面完全不动」。
    //
    // 改成自续排：暂停只是把节奏变成 120ms 一轮的「空转」，链一直在手上，
    // 恢复后下一秒自动消费。开销可忽略（一轮一次空比较）。
    if (paused) {
      _timer = Timer(paceTiers.first.interval, _drainOne);
      return;
    }
    if (_queue.isEmpty) return;
    _consumeOne(_queue.removeFirst(), silent: false);
    if (_disposed) {
      _queue.clear();
      return;
    }
    // 每次消费后都排冷却窗口（队列空按最小积压档）：窗口内到达的
    // 消息入队等待，窗口到期后队列为空则泵回到空闲（下一条直通）。
    // 若只在队列非空时排定时器，爆发循环里每条消息都会看到空闲泵而被
    // 同步直通，节奏彻底失效——所以队列空时也要挂这一拍。
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
