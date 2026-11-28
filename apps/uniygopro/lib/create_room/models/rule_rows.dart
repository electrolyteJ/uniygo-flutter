import 'package:flutter/foundation.dart';

import '../models/room_rule_config.dart';
import 'rule_row_spec.dart';

/// 规则面板共用的选项表（与设计稿一致）。
const List<String> kRuleModes = ['单局', '三局两胜', '双打 2v2'];
const List<String> kRuleCardRules = [
  'OCG',
  'TCG',
  'OT 混',
  '自制卡',
  '专有卡禁止',
  '所有卡片',
];
const List<String> kRuleMasterRules = ['MR 2020', 'MR 2019', '新大师规则'];
const List<String> kRuleLps = ['4000', '8000', '12000'];
const List<String> kRuleHands = ['4', '5', '6'];
const List<String> kRuleDraws = ['1', '2', '3'];
const List<String> kRuleTimes = ['60 秒', '120 秒', '180 秒', '无限制'];

/// 「无限制」→ 0 秒。
int ruleTimeSeconds(String label) =>
    int.tryParse(label.replaceAll(' 秒', '')) ?? 0;

int ruleTimeIndex(int seconds) {
  final i = kRuleTimes.indexWhere((t) => ruleTimeSeconds(t) == seconds);
  return i >= 0 ? i : kRuleTimes.length - 1;
}

int _indexOf(List<String> options, String value) {
  final i = options.indexOf(value);
  return i >= 0 ? i : 0;
}

RuleRowSpec cardRuleRow(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged,
) =>
    RuleRowSpec(
      key: 'rule',
      label: '卡片允许',
      options: kRuleCardRules,
      selected: v.rule.clamp(0, kRuleCardRules.length - 1),
      onSelected: (i) => onChanged(v.copyWith(rule: i)),
    );

RuleRowSpec masterRuleRow(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged,
) =>
    RuleRowSpec(
      key: 'master',
      label: '大师规则',
      options: kRuleMasterRules,
      selected: v.master.clamp(0, kRuleMasterRules.length - 1),
      onSelected: (i) => onChanged(v.copyWith(master: i)),
    );

RuleRowSpec lpRow(RoomRuleConfig v, ValueChanged<RoomRuleConfig> onChanged) =>
    RuleRowSpec(
      key: 'lp',
      label: '初始 LP',
      options: kRuleLps,
      selected: _indexOf(kRuleLps, v.lp.toString()),
      onSelected: (i) => onChanged(v.copyWith(lp: int.tryParse(kRuleLps[i]) ?? 8000)),
    );

RuleRowSpec handRow(RoomRuleConfig v, ValueChanged<RoomRuleConfig> onChanged) =>
    RuleRowSpec(
      key: 'hand',
      label: '初始手牌',
      options: kRuleHands,
      selected: _indexOf(kRuleHands, v.hand.toString()),
      onSelected: (i) => onChanged(v.copyWith(hand: int.tryParse(kRuleHands[i]) ?? 5)),
    );

RuleRowSpec drawRow(RoomRuleConfig v, ValueChanged<RoomRuleConfig> onChanged) =>
    RuleRowSpec(
      key: 'draw',
      label: '每回合抽卡',
      options: kRuleDraws,
      selected: _indexOf(kRuleDraws, v.draw.toString()),
      onSelected: (i) => onChanged(v.copyWith(draw: int.tryParse(kRuleDraws[i]) ?? 1)),
    );

RuleRowSpec timeRow(RoomRuleConfig v, ValueChanged<RoomRuleConfig> onChanged) =>
    RuleRowSpec(
      key: 'time',
      label: '每回合时限',
      options: kRuleTimes,
      selected: ruleTimeIndex(v.time),
      onSelected: (i) => onChanged(v.copyWith(time: ruleTimeSeconds(kRuleTimes[i]))),
    );

RuleRowSpec banlistRow(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged,
  List<String> labels,
) {
  return RuleRowSpec(
    key: 'banlist',
    label: '禁限卡表',
    options: labels,
    selected: labels.isEmpty ? 0 : v.banlist.clamp(0, labels.length - 1),
    onSelected: (i) => onChanged(v.copyWith(banlist: i)),
  );
}


RuleRowSpec modeRow(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged, {
  List<String> options = kRuleModes,
  List<int> values = const [0, 1, 2],
}) {
  final selected = values.indexOf(v.mode);
  return RuleRowSpec(
    key: 'mode',
    label: '赛制',
    options: options,
    selected: selected >= 0 ? selected : 0,
    onSelected: (i) => onChanged(v.copyWith(mode: values[i])),
  );
}

RuleRowSpec envRow(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged,
  List<String> names,
) =>
    RuleRowSpec(
      key: 'env',
      label: '环境',
      options: names,
      selected: names.isEmpty ? 0 : v.env.clamp(0, names.length - 1),
      onSelected: (i) => onChanged(v.copyWith(env: i)),
    );

RuleRowSpec serverRow(List<String> names, int env) => RuleRowSpec(
      key: 'server',
      label: '服务器',
      options: [
        if (names.isNotEmpty) names[env.clamp(0, names.length - 1)] else '—',
      ],
      selected: 0,
    );

/// 大师规则 / LP / 手牌 / 抽卡 / 时限（三个页签通用）。
List<RuleRowSpec> baseRuleRows(
  RoomRuleConfig v,
  ValueChanged<RoomRuleConfig> onChanged, {
  bool includeCardRule = true,
}) =>
    [
      if (includeCardRule) cardRuleRow(v, onChanged),
      masterRuleRow(v, onChanged),
      lpRow(v, onChanged),
      handRow(v, onChanged),
      drawRow(v, onChanged),
      timeRow(v, onChanged),
    ];
