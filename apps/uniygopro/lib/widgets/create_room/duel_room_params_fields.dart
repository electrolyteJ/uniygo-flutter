// ────────────────────────────────────────────────────────────
// 共享房间参数字段（mycard / 233 / AI 房共用）
// ────────────────────────────────────────────────────────────
//
// mycard 建房表单（create_room_form）与 233/AI 建房表单
// （RoomParamsForm）共享同一套参数控件：对战模式 / 大师规则 /
// 初始 LP / 初始手牌 / 每回合抽卡 / 时间限制 / 不检查卡组 /
// 不切洗卡组。这里统一收口它们的下拉选项与字段构建器，避免
// 两处各自维护重复的选项列表与行接线。
//
// 「卡片允许」统一用 int rule（0=OCG,1=TCG,2=OT混,3=自制,
// 4=专有禁止,5=所有），不同服务器提供不同选项集：cardRuleItems
// （mycard/koishi 6 档）与 cardRuleItems233（233 4 档）。
// 「禁限卡表」仅 233 有，由 RoomParamsForm 的 showBanlist 控制。

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'room_dialog.dart';

/// 对战模式下拉选项。
const roomModeItems = <DropdownMenuItem<RoomMode>>[
  DropdownMenuItem(value: RoomMode.single, child: Text('单局')),
  DropdownMenuItem(value: RoomMode.match, child: Text('三局两胜 (Match)')),
  DropdownMenuItem(value: RoomMode.tag, child: Text('双打 (Tag)')),
];

/// 大师规则下拉选项（Master Rule 版本）。
const duelRuleItems = <DropdownMenuItem<DuelRule>>[
  DropdownMenuItem(value: DuelRule.mr3, child: Text('大师规则 3 (2014)')),
  DropdownMenuItem(value: DuelRule.mr4, child: Text('新大师规则 (2017)')),
  DropdownMenuItem(value: DuelRule.mr2020, child: Text('大师规则 2020')),
];

/// 卡片允许下拉选项（mycard / koishi 等，int rule 6 档）。
const cardRuleItems = <DropdownMenuItem<int>>[
  DropdownMenuItem(value: 0, child: Text('OCG')),
  DropdownMenuItem(value: 1, child: Text('TCG')),
  DropdownMenuItem(value: 2, child: Text('OT 混')),
  DropdownMenuItem(value: 3, child: Text('自制卡')),
  DropdownMenuItem(value: 4, child: Text('专有卡禁止')),
  DropdownMenuItem(value: 5, child: Text('所有卡片')),
];

/// 卡片允许下拉选项（233 服 4 档，见 https://ygo233.com/usage）。
const cardRuleItems233 = <DropdownMenuItem<int>>[
  DropdownMenuItem(value: 0, child: Text('OCG')),
  DropdownMenuItem(value: 2, child: Text('TCG + OCG')),
  DropdownMenuItem(value: 1, child: Text('仅 TCG')),
  DropdownMenuItem(value: 4, child: Text('无独有卡')),
];

/// 每回合时间限制下拉选项（秒，0=无限制）。
const timeLimitItems = <DropdownMenuItem<int>>[
  DropdownMenuItem(value: 0, child: Text('无限制')),
  DropdownMenuItem(value: 180, child: Text('3 分钟')),
  DropdownMenuItem(value: 240, child: Text('4 分钟')),
  DropdownMenuItem(value: 300, child: Text('5 分钟')),
  DropdownMenuItem(value: 600, child: Text('10 分钟')),
];

Widget roomModeField(RoomMode value, ValueChanged<RoomMode?> onChanged) =>
    dropdownRow<RoomMode>(
      label: '对战模式',
      value: value,
      items: roomModeItems,
      onChanged: onChanged,
    );

Widget duelRuleField(DuelRule value, ValueChanged<DuelRule?> onChanged) =>
    dropdownRow<DuelRule>(
      label: '大师规则',
      value: value,
      items: duelRuleItems,
      onChanged: onChanged,
    );

Widget cardRuleField(
  int value,
  List<DropdownMenuItem<int>> items,
  ValueChanged<int?> onChanged,
) =>
    dropdownRow<int>(
      label: '卡片允许',
      value: value,
      items: items,
      onChanged: onChanged,
    );

Widget timeLimitField(int value, ValueChanged<int?> onChanged) =>
    dropdownRow<int>(
      label: '时间限制',
      value: value,
      items: timeLimitItems,
      onChanged: onChanged,
    );

Widget startLpField(int value, ValueChanged<int> onChanged) =>
    numberRow('初始 LP', value, onChanged, max: 65535);

Widget startHandField(int value, ValueChanged<int> onChanged) =>
    numberRow('初始手牌', value, onChanged, max: 15);

Widget drawCountField(int value, ValueChanged<int> onChanged) =>
    numberRow('每回合抽卡', value, onChanged, max: 15);

/// 卡组检查开关（不检查卡组 / 不切洗卡组）。
Widget deckCheckFields({
  required bool noCheckDeck,
  required bool noShuffleDeck,
  required ValueChanged<bool?> onNoCheckDeckChanged,
  required ValueChanged<bool?> onNoShuffleDeckChanged,
}) {
  return Row(
    children: [
      checkRow('不检查卡组', noCheckDeck, onNoCheckDeckChanged),
      const SizedBox(width: 16),
      checkRow('不切洗卡组', noShuffleDeck, onNoShuffleDeckChanged),
    ],
  );
}
