import 'package:biz/duel/models/lp_change_event.dart';

/// LP toast 当前条目：合并后的累计 delta 与类型。
class LpToastEntry {
  final int delta;
  final LpChangeKind kind;

  const LpToastEntry({required this.delta, required this.kind});
}

/// 单侧 LP 变动 toast 的合并器（纯 Dart，可单测；组件只读它渲染）。
///
/// 规则：
/// - 同 kind 且距上条事件 ≤ [mergeWindow] → delta 累加、计时重置；
/// - 异 kind（罕见，如支付后紧跟伤害）→ 最新事件直接替换；
/// - 超过 [mergeWindow] → 作为新条目替换（同侧同时最多一条）。
/// 条目存活 [lifetime] 后清空。
class LpToastFeed {
  LpToastFeed({
    this.mergeWindow = const Duration(milliseconds: 800),
    this.lifetime = const Duration(milliseconds: 1400),
  });

  /// 同 kind 合并窗口。
  final Duration mergeWindow;

  /// 单条 toast 的总存活时长。
  final Duration lifetime;

  LpToastEntry? _current;
  Duration _elapsed = Duration.zero;
  Duration _sinceLastEvent = Duration.zero;

  /// 当前可见条目（null = 无）。
  LpToastEntry? get current => _current;

  /// 当前条目已播放时长（组件据此换算缩放/透明度/位移）。
  Duration get elapsed => _elapsed;

  /// 摄入一条 LP 变动事件。
  void add(LpChangeEvent event) {
    final mergeable =
        _current != null &&
        _current!.kind == event.kind &&
        _sinceLastEvent <= mergeWindow;
    _current = mergeable
        ? LpToastEntry(
            delta: _current!.delta + event.delta,
            kind: event.kind,
          )
        : LpToastEntry(delta: event.delta, kind: event.kind);
    _elapsed = Duration.zero;
    _sinceLastEvent = Duration.zero;
  }

  /// 时钟推进（由组件 update(dt) 驱动）。
  void tick(Duration dt) {
    if (_current == null) return;
    _elapsed += dt;
    _sinceLastEvent += dt;
    if (_elapsed >= lifetime) {
      _current = null;
    }
  }

  /// 清空（新一局开始 / 快照 tick 回退时调用）。
  void reset() {
    _current = null;
    _elapsed = Duration.zero;
    _sinceLastEvent = Duration.zero;
  }
}
