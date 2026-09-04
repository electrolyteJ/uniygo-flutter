import 'package:flutter/material.dart';

import 'widgets/select_turn.dart';
import 'widgets/stage_selection_panel_host.dart';

/// 选先后攻面板：猜拳胜者选择先攻/后攻，直接由 DuelRoomPage 挂载在
/// 场地上（不经过等待室弹窗）。
///
/// 对齐 godot RoomOverlay 的选先攻面板：仅猜拳胜者进入该阶段
/// （STOC_SELECT_TP 只发给胜者），故标题固定为「猜拳获胜」。
/// 选择后锁定按钮并提示等待决斗开始；对局开始的先后攻结果由场地页
/// TurnOrderHint 展示。
class TurnSelectPanel extends StatefulWidget {
  /// 按钮是否可用（自动选择开启时为 false）。
  final bool enabled;

  /// 发送选择：true=先攻，false=后攻。
  final void Function(bool goFirst) onSendTp;

  const TurnSelectPanel({
    super.key,
    required this.enabled,
    required this.onSendTp,
  });

  @override
  State<TurnSelectPanel> createState() => _TurnSelectPanelState();
}

class _TurnSelectPanelState extends State<TurnSelectPanel> {
  /// 本地已提交的先后攻选择（null=尚未选择）。
  bool? _goFirst;

  void _send(bool goFirst) {
    widget.onSendTp(goFirst);
    setState(() => _goFirst = goFirst);
  }

  @override
  Widget build(BuildContext context) {
    final goFirst = _goFirst;
    return StageSelectionPanelHost(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '猜拳获胜！选择先后攻',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF66FFB2),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TpSelect(
              enabled: widget.enabled && goFirst == null,
              onSendTp: _send,
            ),
            const SizedBox(height: 10),
            Text(
              goFirst != null
                  ? goFirst
                        ? '已选择先攻，等待决斗开始…'
                        : '已选择后攻，等待决斗开始…'
                  : widget.enabled
                  ? '请选择行动顺序'
                  : '自动选择先后攻中…',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8CA6C4), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
