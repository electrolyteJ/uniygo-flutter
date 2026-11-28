import 'dart:math' as math;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'cyber_progress_bar.dart';

/// 阶段状态栏（05b-05e 底栏）：连接态 + 进度 + 下一步提示。
class WaitingPhaseStatusBar extends StatefulWidget {
  const WaitingPhaseStatusBar({
    super.key,
    required this.room,
    required this.stage,
  });

  final DuelRoomState room;
  final RoomStage stage;

  @override
  State<WaitingPhaseStatusBar> createState() => _WaitingPhaseStatusBarState();
}

class _WaitingPhaseStatusBarState extends State<WaitingPhaseStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationOf(widget.stage),
  )..forward();

  static Duration _durationOf(RoomStage stage) => switch (stage) {
    RoomSelectingHand() => const Duration(seconds: 5),
    RoomHandResult() => const Duration(seconds: 2),
    RoomSelectingTurn() => const Duration(seconds: 10),
    _ => const Duration(seconds: 5),
  };

  @override
  void didUpdateWidget(covariant WaitingPhaseStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.runtimeType != widget.stage.runtimeType) {
      _controller.duration = _durationOf(widget.stage);
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = (math.min(
      MediaQuery.sizeOf(context).width / 844,
      MediaQuery.sizeOf(context).height / 390,
    )).clamp(0.85, 2.4);
    return Center(
      child: SizedBox(
        width: 320 * k,
        child: AnimatedBuilder(
          animation: _controller,
          // 与 07 载入页共用同一条细进度条（槽色 / 青光 / 辉光一致），
          // 只在这里补上设计稿的 2px 圆角。
          builder: (context, _) =>
              CyberProgressBar(progress: _controller.value, radius: 2),
        ),
      ),
    );
  }
}
