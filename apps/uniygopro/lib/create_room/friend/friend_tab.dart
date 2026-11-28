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
import '../util/banlist_util.dart';
import '../models/rule_rows.dart';
import '../widgets/room_rule_panel.dart';

/// 408 环境规则由服务端锁定：面板只展示、不提供修改。
const List<(String, String)> _rules408 = [
  ('大师规则', 'MR 2020'),
  ('额外怪兽区', '不适用'),
  ('初始 LP', '8000'),
  ('初始手牌', '5 张'),
  ('卡池', '前四期'),
  ('禁限卡表', '2006.3'),
  ('效果文本', '改订前'),
];

class FriendTab extends StatefulWidget {
  const FriendTab({super.key});

  @override
  State<FriendTab> createState() => _FriendTabState();
}

class _FriendTabState extends State<FriendTab> {
  List<String> get _banlistNames =>
      BanlistUtil.getOptionNames();

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
        'friend-tag' => 2, // 双打 2v2
        'friend-match' => 1, // 三局两胜
        _ => 0, // 单局
      };
      await createFreeRoom(
        context,
        env: env,
        config: _config.copyWith(mode: mode),
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
          // 408 规则由服务端锁定：只读行（options 只有一个值、无回调）。
          RoomRulePanel(
            title: '408 固定规则',
            rows: [
              for (final rule in _rules408)
                RuleRowSpec(
                  key: rule.$1,
                  label: rule.$1,
                  options: [rule.$2],
                  selected: 0,
                ),
            ],
            note: '规则由环境锁定 · 不可修改',
            height: 36 + _rules408.length * 24 + 24,
          )
        else
          RoomRulePanel(
            title: '规则设置',
            rows: [
              cardRuleRow(_config, (v) => setState(() => _config = v)),
              ...baseRuleRows(
                _config,
                (v) => setState(() => _config = v),
                includeCardRule: false,
              ),
              banlistRow(
                _config,
                (v) => setState(() => _config = v),
                is408 ? _banlistNames : BanlistUtil.getMercury233Labels(),
              ),
            ],
            checks: [
              RuleCheckSpec(
                key: 'noCheck',
                label: '不检查卡组',
                value: _config.noCheck,
                onChanged: (v) =>
                    setState(() => _config = _config.copyWith(noCheck: v)),
              ),
              RuleCheckSpec(
                key: 'noShuffle',
                label: '不切洗卡组',
                value: _config.noShuffle,
                onChanged: (v) =>
                    setState(() => _config = _config.copyWith(noShuffle: v)),
              ),
              RuleCheckSpec(
                key: 'autoDeath',
                label: '40 分钟自动超时',
                value: _config.autoDeath,
                onChanged: (v) =>
                    setState(() => _config = _config.copyWith(autoDeath: v)),
              ),
            ],
            collapsed: _config.collapsed,
            onToggleCollapsed: () => setState(
              () => _config = _config.copyWith(collapsed: !_config.collapsed),
            ),
            checksTop: 232,
          ),
      ],
    );
  }
}
