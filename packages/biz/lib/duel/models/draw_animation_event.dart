import 'dart:collection';

/// 一次抽卡动画事件（MSG_DRAW 到达时由 duel_field_state 发出，
/// 经状态快照推到页面，由 [DrawAnimationQueue] 排队播放）。
class DrawAnimationEvent {
  final int id;
  final int player;
  final List<int> codes;
  final int turnCount;
  final bool revealCard;

  const DrawAnimationEvent({
    required this.id,
    required this.player,
    required this.codes,
    required this.turnCount,
    this.revealCard = false,
  });

  DrawAnimationEvent copyWith({
    int? id,
    int? player,
    List<int>? codes,
    int? turnCount,
    bool? revealCard,
  }) {
    return DrawAnimationEvent(
      id: id ?? this.id,
      player: player ?? this.player,
      codes: codes ?? this.codes,
      turnCount: turnCount ?? this.turnCount,
      revealCard: revealCard ?? this.revealCard,
    );
  }
}

/// [DrawAnimationQueue.submit] 的处理结果。
enum DrawQueueSubmitResult {
  /// 此前无播放中的动画：事件成为 active 并应立即开始播放。
  started,

  /// 与播放中事件同 id：就地替换 active（如 MSG_CONFIRM_CARDS 后的
  /// reveal 更新），不得重启动画。
  patchedActive,

  /// 与排队中事件同 id：就地替换该排队条目，顺序不变。
  patchedQueued,

  /// 新事件：追加到队尾，等待当前动画完成后按 FIFO 播放。
  enqueued,
}

/// 抽卡动画的页面级 FIFO 队列（纯逻辑，不含任何 widget/controller 依赖）。
///
/// 语义：
/// - 空闲时 submit 的事件立即成为 active（返回 [DrawQueueSubmitResult.started]）；
/// - 播放中到达的事件入队，不再像旧单槽实现那样打断当前动画
///   （连续抽卡——例如「天使的施舍」——会依次完整播放）；
/// - 同 id 更新不入队：命中 active 就地替换（动画不重启），
///   命中排队条目就地替换该条目；
/// - [drain] 在当前动画播完时调用：清掉 active 并取出队首成为新 active。
class DrawAnimationQueue {
  DrawAnimationEvent? _active;
  final Queue<DrawAnimationEvent> _pending = Queue<DrawAnimationEvent>();

  /// 正在播放的事件；无播放中动画时为 null。
  DrawAnimationEvent? get active => _active;

  /// 是否有正在播放的动画。
  bool get isPlaying => _active != null;

  /// 排队等待播放的事件（FIFO 顺序，只读快照，供测试/调试）。
  List<DrawAnimationEvent> get pending => List.unmodifiable(_pending);

  /// 提交一个事件。返回值表明页面应作出的反应，见 [DrawQueueSubmitResult]。
  DrawQueueSubmitResult submit(DrawAnimationEvent event) {
    final current = _active;
    if (current == null) {
      _active = event;
      return DrawQueueSubmitResult.started;
    }
    if (current.id == event.id) {
      // 同 id 更新命中 active：只换数据，不重启动画。
      _active = event;
      return DrawQueueSubmitResult.patchedActive;
    }
    // 同 id 更新命中排队条目：原地替换，保持队列顺序。
    // （Queue 无 indexWhere，借道 List 查找后再整体回填。）
    final asList = _pending.toList(growable: false);
    final queuedIndex = asList.indexWhere((e) => e.id == event.id);
    if (queuedIndex >= 0) {
      asList[queuedIndex] = event;
      _pending
        ..clear()
        ..addAll(asList);
      return DrawQueueSubmitResult.patchedQueued;
    }
    _pending.add(event);
    return DrawQueueSubmitResult.enqueued;
  }

  /// 当前动画播放完成：清掉 active，弹出队首成为新 active 并返回；
  /// 队列为空时返回 null（页面应移除动画层）。
  DrawAnimationEvent? drain() {
    _active = null;
    if (_pending.isEmpty) return null;
    _active = _pending.removeFirst();
    return _active;
  }

  /// 清空全部状态：页面 dispose / 新对局（MSG_START）重置时调用。
  void clear() {
    _active = null;
    _pending.clear();
  }

  /// active 或队列非空。
  bool get isNotEmpty => _active != null || _pending.isNotEmpty;
}
