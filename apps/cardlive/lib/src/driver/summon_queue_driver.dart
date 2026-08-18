import 'dart:collection';

import 'package:flame/components.dart';

import '../registry.dart';
import '../spec.dart';

/// 通用召唤动画 FIFO 队列驱动器。
///
/// 不感知事件来源（决斗协议、debug 按钮、鉴赏页）：调用方 [enqueue]，
/// 驱动器按序逐条播放、互不打断（语义同抽卡动画队列）；一条播完
/// 自动开始下一条。动画组件由 [SummonAnimationRegistry] 按类别创建。
class SummonQueueDriver extends Component {
  SummonQueueDriver({SummonAnimationRegistry? registry, super.priority})
    : registry = registry ?? defaultSummonAnimationRegistry();

  final SummonAnimationRegistry registry;

  final Queue<SummonAnimationSpec> _queue = Queue();
  PositionComponent? _active;

  /// 是否正在播放。
  bool get isPlaying => _active != null;

  /// 排队中的条数。
  int get pendingCount => _queue.length;

  /// 入队（FIFO）。
  void enqueue(SummonAnimationSpec spec) => _queue.add(spec);

  @override
  void update(double dt) {
    super.update(dt);
    if (_active == null && _queue.isNotEmpty) {
      _startNext(_queue.removeFirst());
    }
  }

  void _startNext(SummonAnimationSpec spec) {
    // 包装完成回调：先清 active 推进队列，再通知调用方。
    final wrapped = spec.withOnFinished(() {
      _active = null;
      spec.onFinished?.call();
    });
    final component = registry.create(wrapped);
    _active = component;
    add(component);
  }
}
