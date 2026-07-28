import 'dart:ui';

/// 动画阶段枚举
enum StageType { flash, beam, particles, materialize, aura }

/// 单个阶段的状态
class StageState {
  final StageType type;
  final double startTime; // 秒
  final double endTime;   // 秒
  double _elapsed = 0;

  StageState({
    required this.type,
    required this.startTime,
    required this.endTime,
  });

  double get duration => endTime - startTime;
  double get progress => (_elapsed / duration).clamp(0.0, 1.0);
  bool get isActive => _elapsed > 0 && _elapsed <= duration;
  bool get isDone => _elapsed > duration;
  bool get shouldStart => _elapsed == 0;

  void update(double dt) {
    _elapsed += dt;
  }

  void reset() {
    _elapsed = 0;
  }
}

/// 阶段编排引擎 —— 管理 5 阶段的时序
class StageSequence {
  final List<StageState> stages = [
    StageState(type: StageType.flash, startTime: 0.0, endTime: 0.2),
    StageState(type: StageType.beam, startTime: 0.1, endTime: 0.6),
    StageState(type: StageType.particles, startTime: 0.3, endTime: 0.5),
    StageState(type: StageType.materialize, startTime: 0.5, endTime: 0.8),
    StageState(type: StageType.aura, startTime: 0.7, endTime: 1.0),
  ];

  double _totalElapsed = 0;
  bool _started = false;
  VoidCallback? _onComplete;

  StageSequence({VoidCallback? onComplete}) : _onComplete = onComplete;

  bool get isRunning => _started && _totalElapsed < 1.2;
  bool get isDone => _totalElapsed >= 1.2;

  void start() {
    _started = true;
    _totalElapsed = 0;
    for (final s in stages) {
      s.reset();
    }
  }

  void reset() {
    _started = false;
    _totalElapsed = 0;
    for (final s in stages) {
      s.reset();
    }
  }

  /// 每帧调用，dt 单位秒
  void update(double dt) {
    if (!_started || isDone) return;
    _totalElapsed += dt;

    for (final stage in stages) {
      if (stage.isDone) continue;
      if (_totalElapsed >= stage.startTime) {
        final stageDt = _totalElapsed - stage.startTime - (stage._elapsed);
        stage.update(stageDt.clamp(0.0, dt));
      }
    }

    if (_totalElapsed >= 1.2 && _onComplete != null) {
      _onComplete!();
      _onComplete = null; // 只触发一次
    }
  }

  /// 获取当前活跃的阶段列表
  List<StageState> get activeStages =>
      stages.where((s) => s.isActive).toList();

  /// 获取特定阶段
  StageState? stage(StageType type) {
    try {
      return stages.firstWhere((s) => s.type == type);
    } catch (_) {
      return null;
    }
  }

  double get totalProgress => (_totalElapsed / 1.2).clamp(0.0, 1.0);
  double get totalElapsed => _totalElapsed;
}
