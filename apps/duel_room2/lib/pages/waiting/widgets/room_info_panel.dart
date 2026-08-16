import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:ygo_data/ygo_data.dart' show CardInfo, LfTable;

class RoomInfoPanel extends StatelessWidget {
  final RoomOptions opts;
  final LfTable? lfTable;

  /// 禁限表仍在加载（future 未完成）。
  final bool banlistLoading;

  /// 禁限表加载失败（如未 preload 时 getLfTable 抛异常）。
  /// 与「无禁限表（不限制）」区分开，避免把错误误显示成「不限制」。
  final bool banlistError;

  final Future<CardInfo?> Function(int code) cardLoader;

  const RoomInfoPanel({
    super.key,
    required this.opts,
    this.lfTable,
    this.banlistLoading = false,
    this.banlistError = false,
    required this.cardLoader,
  });

  /// 禁限卡表展示文案：加载中/加载失败/表名/不限制。
  String get _banlistText {
    if (banlistLoading) return '加载中…';
    if (banlistError) return '加载失败';
    return lfTable?.name ?? '不限制';
  }

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

          _InkInfoRow(
            icon: banlistError ? Icons.warning_amber : Icons.list_alt,
            text: '禁限卡表: $_banlistText',
            // 加载中/加载失败时不可点击查看明细。
            enabled: lfTable != null,
            onTap: lfTable != null
                ? () => BanlistDetailDialog.show(
                    context,
                    lfTable: lfTable!,
                    cardLoader: cardLoader,
                  )
                : null,
          ),
          _infoRow(Icons.check_circle, '检查卡组: ${opts.noCheckDeck ? "否" : "是"}'),
          _infoRow(Icons.shuffle, '切洗卡组: ${opts.noShuffleDeck ? "否" : "是"}'),
        ],
      ),
    );
  }

}

@Preview(name: 'RoomInfoPanel', size: Size(320, 260), brightness: Brightness.dark)
Widget previewRoomInfoPanel() => RoomInfoPanel(
      opts: const RoomOptions(mode: RoomMode.match, autoDeath: true),
      cardLoader: (_) async => null,
    );

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
/// 带点击效果的信息行
///
/// [enabled] 为 true 时显示可点击的外观（箭头 icon + 下划线），
/// 为 false 时外观与普通 [_infoRow] 一致。
class _InkInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool enabled;
  final VoidCallback? onTap;

  const _InkInfoRow({
    required this.icon,
    required this.text,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.blueGrey.shade600,
      highlightColor: Colors.blueGrey.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: enabled ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: enabled ? Colors.blueGrey.shade200 : Colors.blueGrey.shade500,
                  fontSize: 13,
                  decoration: enabled ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: Colors.blueGrey.shade400),
            ],
          ],
        ),
      ),
    );
  }
}

