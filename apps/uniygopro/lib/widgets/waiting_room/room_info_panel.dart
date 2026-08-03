import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'package:ygo_card/lf_table.dart';

class RoomInfoPanel extends StatelessWidget {
  final RoomOptions opts;
  final LfTable? lfTable;

  const RoomInfoPanel({super.key, required this.opts, this.lfTable});

  @override
  Widget build(BuildContext context) {
    final modeStr = switch (opts.mode) {
      RoomMode.single => '单局模式',
      RoomMode.match => '三局两胜',
      RoomMode.tag => '双打模式',
    };
    final ruleStr = switch (opts.rule) {
      0 => 'OCG',
      1 => 'TCG',
      2 => 'OT 混',
      3 => '自制卡',
      4 => '专有卡禁止',
      5 => '所有卡片',
      _ => '未知',
    };
    final duelRuleStr = switch (opts.duelRule) {
      DuelRule.mr3 => '大师规则 3',
      DuelRule.mr4 => '新大师规则',
      DuelRule.mr2020 => '大师规则 2020',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('房间信息', style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
          const SizedBox(height: 6),
          _infoRow(Icons.gamepad, '$modeStr · $ruleStr'),
          _infoRow(Icons.gavel, duelRuleStr),
          _infoRow(Icons.favorite, 'LP: ${opts.startLp}  手牌: ${opts.startHand}  抽卡: ${opts.drawCount}'),
          _infoRow(Icons.timer, opts.timeLimit > 0 ? '限时: ${opts.timeLimit}秒' : '无时间限制'),
          if (opts.autoDeath)
            _infoRow(Icons.alarm, '40分钟自动超时'),

          _infoRow(Icons.list_alt, '禁限卡表: ${lfTable?.name ?? "未知"}'),
          _infoRow(Icons.check_circle, '检查卡组: ${opts.noCheckDeck ? "否" : "是"}'),
          _infoRow(Icons.shuffle, '切洗卡组: ${opts.noShuffleDeck ? "否" : "是"}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade400),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13))),
        ],
      ),
    );
  }
}
