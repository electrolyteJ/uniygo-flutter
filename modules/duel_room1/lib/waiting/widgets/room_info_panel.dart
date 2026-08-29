import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:resource_data/ygo_data.dart' show CardInfo, LfTable;

/// 房间「卡片允许规则」取值（RoomOptions.rule 的协议值；
/// duelink 暂无对应枚举，先就地命名，避免裸整数 switch）。
const _ruleOcg = 0; // OCG
const _ruleTcg = 1; // TCG
const _ruleOcgTcgMixed = 2; // OT 混
const _ruleCustomCards = 3; // 自制卡
const _ruleNoExclusive = 4; // 专有卡禁止
const _ruleAllCards = 5; // 所有卡片

class RoomInfoPanel extends StatelessWidget {
  final RoomOptions opts;
  final LfTable? lfTable;

  /// 禁限表是否仍在加载中（与 [lfTableFailed] 互斥）。
  final bool lfTableLoading;

  /// 禁限表加载是否失败（如禁限表服务未就绪）。
  final bool lfTableFailed;
  final Future<CardInfo?> Function(int code) cardLoader;

  const RoomInfoPanel({
    super.key,
    required this.opts,
    this.lfTable,
    this.lfTableLoading = false,
    this.lfTableFailed = false,
    required this.cardLoader,
  });

  @override
  Widget build(BuildContext context) {
    final modeStr = switch (opts.mode) {
      RoomMode.single => '单局模式',
      RoomMode.match => '三局两胜',
      RoomMode.tag => '双打模式',
    };
    final ruleStr = switch (opts.rule) {
      _ruleOcg => 'OCG',
      _ruleTcg => 'TCG',
      _ruleOcgTcgMixed => 'OT 混',
      _ruleCustomCards => '自制卡',
      _ruleNoExclusive => '专有卡禁止',
      _ruleAllCards => '所有卡片',
      _ => '未知',
    };
    final duelRuleStr = switch (opts.duelRule) {
      DuelRule.mr3 => '大师规则 3',
      DuelRule.mr4 => '新大师规则',
      DuelRule.mr2020 => '大师规则 2020',
    };

    // 不设底色：等待室已改为半透明弹窗，面板背景由弹窗容器提供。
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.blueGrey.shade700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '房间信息',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.gamepad, '$modeStr · $ruleStr'),
          _infoRow(Icons.gavel, duelRuleStr),
          _infoRow(
            Icons.favorite,
            'LP: ${opts.startLp}  手牌: ${opts.startHand}  抽卡: ${opts.drawCount}',
          ),
          _infoRow(
            Icons.timer,
            opts.timeLimit > 0 ? '限时: ${opts.timeLimit}秒' : '无时间限制',
          ),
          if (opts.autoDeath) _infoRow(Icons.alarm, '40分钟自动超时'),

          _InkInfoRow(
            icon: Icons.list_alt,
            // 三态文案：加载中 / 加载失败 / 有数据
            // （数据为 null 即未设禁限表，才是「不限制」）。
            text: '禁限卡表: ${_banlistText()}',
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

  /// 禁限表行文案：加载中/失败不再伪装成「不限制」。
  String _banlistText() {
    if (lfTable != null) return lfTable!.name;
    if (lfTableFailed) return '未知（加载失败）';
    if (lfTableLoading) return '加载中…';
    return '不限制';
  }
}

Widget _infoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey.shade400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13),
          ),
        ),
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
            Icon(
              icon,
              size: 14,
              color: enabled
                  ? Colors.blueGrey.shade400
                  : Colors.blueGrey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: enabled
                      ? Colors.blueGrey.shade200
                      : Colors.blueGrey.shade500,
                  fontSize: 13,
                  decoration: enabled ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.blueGrey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
