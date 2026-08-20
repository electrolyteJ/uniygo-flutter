import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'overlay_panel.dart';
import 'select_hand.dart';

/// 猜拳阶段面板：直接由 DuelRoomPage 挂载在场地上（不经过等待室弹窗）。
///
/// 对齐 godot RoomOverlay 的猜拳面板：
/// - 出拳阶段（[isResult] = false）：剪刀/石头/布按钮，出拳后锁定并提示等待；
/// - 结果阶段（[isResult] = true）：展示「我方 X vs 对方 Y」与胜负结果；
///   输家额外提示「等待对方选择先后攻」（赢家随后进入选先攻阶段）。
class HandSelectPanel extends StatefulWidget {
  /// 是否处于结果展示阶段（RoomHandResult）；false 为出拳阶段
  /// （RoomSelectingHand）。
  final bool isResult;

  /// 我方猜拳结果（1=剪刀 2=石头 3=布），仅结果阶段有意义。
  final int? myHand;

  /// 对方猜拳结果，仅结果阶段有意义。
  final int? opponentHand;

  /// 出拳按钮是否可用（自动猜拳开启时为 false）。
  final bool enabled;

  final void Function(HandType) onSendHand;

  const HandSelectPanel({
    super.key,
    required this.isResult,
    this.myHand,
    this.opponentHand,
    required this.enabled,
    required this.onSendHand,
  });

  @override
  State<HandSelectPanel> createState() => _HandSelectPanelState();
}

class _HandSelectPanelState extends State<HandSelectPanel> {
  /// 本阶段已出的拳（本地标记；服务器结果经 widget.myHand 到达）。
  HandType? _sent;

  @override
  void didUpdateWidget(covariant HandSelectPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 平局/重开一轮：结果阶段回到出拳阶段时清空本地已出拳标记。
    if (oldWidget.isResult && !widget.isResult) {
      _sent = null;
    }
  }

  void _send(HandType hand) {
    widget.onSendHand(hand);
    setState(() => _sent = hand);
  }

  static String _handEmoji(int? value) => switch (HandType.of(value ?? 0)) {
    HandType.scissors => '✌️',
    HandType.rock => '✊',
    HandType.paper => '🖐️',
    HandType.unknown => '❓',
  };

  static String _handName(int? value) => switch (HandType.of(value ?? 0)) {
    HandType.scissors => '剪刀',
    HandType.rock => '石头',
    HandType.paper => '布',
    HandType.unknown => '未知',
  };

  /// a 是否赢 b（1=剪刀 2=石头 3=布）。
  static bool _beats(int a, int b) =>
      (a == 2 && b == 1) || (a == 1 && b == 3) || (a == 3 && b == 2);

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '猜拳定先攻',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.isResult) _buildResult() else _buildSelecting(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelecting() {
    final sent = _sent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HandSelect(enabled: widget.enabled && sent == null, onSendHand: _send),
        const SizedBox(height: 10),
        Text(
          sent != null
              ? '已出拳：${_handName(sent.value)}，等待对方出拳…'
              : widget.enabled
              ? '请出拳！'
              : '自动猜拳中…',
          style: const TextStyle(color: Color(0xFF8CA6C4), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final my = widget.myHand ?? 0;
    final op = widget.opponentHand ?? 0;
    final String outcome;
    final Color outcomeColor;
    final bool iLose;
    if (my == op) {
      outcome = '平局，重新猜拳…';
      outcomeColor = Colors.amber;
      iLose = false;
    } else if (_beats(my, op)) {
      outcome = '你赢了！';
      outcomeColor = Colors.greenAccent;
      iLose = false;
    } else {
      outcome = '你输了…';
      outcomeColor = const Color(0xFF9AA7B8);
      iLose = true;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          // 包容内容：面板居中展示，不撑满屏幕宽度。
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _handSide('我方', my),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'VS',
                style: TextStyle(
                  color: Color(0xFF8CA6C4),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _handSide('对方', op),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          outcome,
          style: TextStyle(
            color: outcomeColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (iLose) ...[
          const SizedBox(height: 6),
          const Text(
            '等待对方选择先后攻…',
            style: TextStyle(color: Color(0xFF8CA6C4), fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _handSide(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_handEmoji(value), style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 4),
        Text(
          '$label · ${_handName(value)}',
          style: const TextStyle(color: Color(0xFFD8E2EE), fontSize: 13),
        ),
      ],
    );
  }
}
