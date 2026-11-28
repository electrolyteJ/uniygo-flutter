import 'dart:async';

import 'package:flutter/material.dart';

/// 换备倒计时的默认时长。
///
/// **这是本地设定，不是服务端时限**：YGOPro 协议不下发换备时限，但房间
/// 在换备阶段停留太久会被服务端断开 socket（房间随之关闭）。6 分钟是
/// 先按经验取的保守值，等确认服务端真实超时后再调这一处即可。
const Duration kSideDeckingLimit = Duration(minutes: 6);

/// 换备页顶条右侧的倒计时读数。
///
/// 只负责「把起始时刻算成 `mm:ss`」，不画外框与提示文案（那些在
/// [SideTopBar] 里，因为等待形态下同一位置要显示别的提示）。
///
/// 剩余时间 ≤ 60 秒时按 [critical]，由调用方转品红并改提示文案。
///
/// 到点触发 [onExpired] **一次**（每段换备只触发一次，重置起始时刻会
/// 重新计时）。这个回调是「超时自动提交」的入口——只画不做的计时器
/// 会误导玩家以为到点有保护，实际被服务端直接断连。
class SideCountdown extends StatefulWidget {
  const SideCountdown({
    super.key,
    required this.startedAt,
    required this.builder,
    this.limit = kSideDeckingLimit,
    this.onExpired,
  });

  /// 换备阶段起始时刻（[DuelRoomState.sidingStartedAt]）。
  final DateTime? startedAt;

  /// 总时长。
  final Duration limit;

  /// 归零时回调一次。为 null 则只显示，不触发任何动作。
  final VoidCallback? onExpired;

  /// 每秒重建一次，把剩余时长交给外部渲染。
  final Widget Function(BuildContext context, Duration remaining, bool critical)
  builder;

  @override
  State<SideCountdown> createState() => _SideCountdownState();
}

class _SideCountdownState extends State<SideCountdown> {
  Timer? _timer;

  /// 本轮计时是否已经触发过 [SideCountdown.onExpired]。
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(SideCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _expiredFired = false;
    if (widget.startedAt == null) return;
    // 每秒刷新：剩余秒数是整数，1s 粒度足够，不必更高频。
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeFireExpired();
    });
    // 进入页面时就已超时（例如页面重建、热重载）：下一帧补触发，
    // 不必等满一个 tick。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeFireExpired();
    });
  }

  void _maybeFireExpired() {
    if (_expiredFired) return;
    final startedAt = widget.startedAt;
    if (startedAt == null) return;
    if (DateTime.now().difference(startedAt) < widget.limit) return;
    _expiredFired = true;
    widget.onExpired?.call();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      // 没有起始时刻（不是换备阶段 / 尚未初始化）：交回 0 剩余。
      return widget.builder(context, Duration.zero, false);
    }
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = widget.limit - elapsed;
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    return widget.builder(
      context,
      clamped,
      clamped.inSeconds <= 60,
    );
  }
}

/// `mm:ss`（≥100 分钟时按 `h:mm:ss`，换备不会走到，但避免显示错乱）。
String formatCountdown(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  if (m >= 100) {
    final h = m ~/ 60;
    return '$h:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
