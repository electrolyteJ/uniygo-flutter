/// 固定规则面板：环境规则被服务端锁定时（如 408 环境）替代 [RoomRulePanel]。
///
/// 与 [RoomRulePanel] 共用同一套外框、标题行与行距，只是每行只读、无下拉箭头。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_theme.dart';

import 'room_rule_panel.dart';

/// 一行只读规则：左侧标签 + 右侧取值。
typedef RoomFixedRule = ({String label, String value});

class RoomFixedRulePanel extends StatelessWidget {
  const RoomFixedRulePanel({
    super.key,
    required this.title,
    required this.rules,
    this.note,
    this.left = 644,
    this.top = 52,
    this.width = 184,
  });

  final String title;
  final List<RoomFixedRule> rules;

  /// 底部说明（如「规则由环境锁定」），为空时不占行。
  final String? note;

  final double left;
  final double top;
  final double width;

  static const double _headerHeight = 36;
  static const double _rowHeight = 24;

  @override
  Widget build(BuildContext context) {
    final height =
        _headerHeight + rules.length * _rowHeight + (note == null ? 8 : 24);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080F19),
          border: Border.all(color: DuelColors.borderPanel),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 10,
              child: Text(title, style: DuelType.sans(11, height: 1.2)),
            ),
            Positioned(
              left: 12,
              top: 28,
              width: width - 24,
              child: Container(height: 1, color: DuelColors.divider),
            ),
            for (var i = 0; i < rules.length; i++) ...[
              Positioned(
                left: 12,
                top: _rowTop(i) + 6,
                child: Text(
                  rules[i].label,
                  style: DuelType.sans(8, color: DuelColors.textFaint),
                ),
              ),
              Positioned(
                left: 72,
                top: _rowTop(i),
                width: width - 84,
                height: 22,
                child: _valueBox(rules[i].value),
              ),
            ],
            if (note != null)
              Positioned(
                left: 12,
                top: _rowTop(rules.length),
                child: Text(
                  note!,
                  style: DuelType.sans(7.5, color: DuelColors.textGhost),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _rowTop(int index) => _headerHeight + index * _rowHeight;

  /// 只读取值框：与 [RoomRulePanel] 的下拉框同款，只是没有箭头、不可点。
  Widget _valueBox(String text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A121C),
        border: Border.all(color: DuelColors.border),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DuelType.sans(8.5, color: DuelColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
