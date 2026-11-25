/// 好友对战页签：4 个模式 rail + 规则面板（408 环境规则固定，只读面板）。
library;

import 'package:flutter/material.dart';
import '../../config/servers.dart';

import 'package:ygo_settings/theme/duel_sound.dart';
import '../free/free_room_launch.dart';
import '../models/mode_models.dart';
import '../widgets/floating_cards.dart';
import '../widgets/mode_rail.dart';
import '../widgets/match_dial.dart';
import 'room_fixed_rule_panel.dart';
import '../widgets/room_rule_panel.dart';

/// 408 环境规则由服务端锁定：面板只展示、不提供修改。
const List<RoomFixedRule> _rules408 = [
  (label: '大师规则', value: 'MR 2020'),
  (label: '额外怪兽区', value: '不适用'),
  (label: '初始 LP', value: '8000'),
  (label: '初始手牌', value: '5 张'),
  (label: '卡池', value: '前四期'),
  (label: '禁限卡表', value: '2006.3'),
  (label: '效果文本', value: '改订前'),
];

class FriendTab extends StatefulWidget {
  const FriendTab({super.key});

  @override
  State<FriendTab> createState() => _FriendTabState();
}

class _FriendTabState extends State<FriendTab> {
  late final DuelModeTab _tab = DuelModes.tabs[1];

  int _selected = DuelModes.tabs[1].defaultIndex;
  RoomRuleConfig _config = const RoomRuleConfig();
  bool _busy = false;

  DuelModeEntry get _entry => _tab.entries[_selected];

  @override
  void initState() {
    super.initState();
    final current = ModeSelection.instance.current;
    final index = _tab.entries.indexWhere((e) => identical(e, current));
    if (index >= 0) _selected = index;
  }

  void _selectEntry(int index) {
    if (index == _selected) return;
    DuelSounds.tabSwitch();
    setState(() {
      _selected = index;
      _config = const RoomRuleConfig();
    });
    ModeSelection.instance.select(_entry);
  }

  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    try {
      // 好友对战：单局 / 三局两胜 / 2v2 都走 233 服；408 走 408 服。
      final env =
          _entry.environment ??
          (_entry.id == 'friend-408'
              ? DuelEnvironment.env408
              : DuelEnvironment.mercury233);
      final mode = switch (_entry.id) {
        'friend-tag' => 0, // 双打 2v2
        'friend-match' => 1, // 三局两胜
        _ => 2, // 单局
      };
      final name = switch (_entry.id) {
        'friend-tag' => '好友对战 · 2v2',
        'friend-match' => '好友对战 · 三局两胜',
        'friend-408' => '好友对战 · 408',
        _ => '好友对战 · 单局',
      };
      await createFreeRoom(
        context,
        env: env,
        config: _config.copyWith(mode: mode),
        roomName: name,
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final is408 = _entry.id == 'friend-408';
    return Stack(
      children: [
        ModeRail(
          entries: _tab.entries,
          selected: _selected,
          onSelect: _selectEntry,
        ),
        ...floatingCards(),
        MatchDial(
          title: '创建房间',
          info: is408 ? '408 特殊规则 · 创建房间' : '邀请好友 · 房主设规则',
          hint: '点击创建房间',
          onTap: _run,
        ),
        if (is408)
          const RoomFixedRulePanel(
            title: '408 固定规则',
            rules: _rules408,
            note: '规则由环境锁定 · 不可修改',
          )
        else
          RoomRulePanel(
            title: '规则设置',
            value: _config,
            onChanged: (v) => setState(() => _config = v),
            showAutoDeath: true,
            checksTop: 232,
          ),
      ],
    );
  }
}
