/// 自由房间页签：环境 rail + 规则面板 + 一个圆盘动作（建房）。
library;

import 'package:flutter/material.dart';

import '../../config/servers.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import '../models/mode_models.dart';
import '../widgets/floating_cards.dart';
import '../widgets/match_dial.dart';
import '../widgets/mode_rail.dart';
import '../models/rule_rows.dart';
import '../widgets/room_rule_panel.dart';
import 'free_room_launch.dart';

class FreeTab extends StatefulWidget {
  const FreeTab({super.key});

  @override
  State<FreeTab> createState() => _FreeTabState();
}

class _FreeTabState extends State<FreeTab> {
  late final DuelModeTab _tab = DuelModes.tabs[3];

  int _selected = DuelModes.tabs[3].defaultIndex;
  RoomRuleConfig _config = const RoomRuleConfig(mode: 0);
  bool _busy = false;

  DuelModeEntry get _entry => _tab.entries[_selected];
  DuelEnvironment get _env => _environmentOf(_config.env);

  @override
  void initState() {
    super.initState();
    final current = ModeSelection.instance.current;
    final index = _tab.entries.indexWhere((e) => identical(e, current));
    if (index >= 0) _selected = index;
    _config = RoomRuleConfig(env: _selected, mode: 0);
  }

  /// rail 序号（0=Koishi / 1=mycard / 2=mercury233）→ 决斗环境。
  DuelEnvironment _environmentOf(int index) {
    return switch (index) {
      1 => DuelEnvironment.mycard,
      2 => DuelEnvironment.mercury233,
      _ => DuelEnvironment.koishi,
    };
  }

  void _selectEntry(int index) {
    if (index == _selected) return;
    DuelSounds.tabSwitch();
    setState(() {
      _selected = index;
      _config = _config.copyWith(env: index);
    });
    ModeSelection.instance.select(_entry);
  }

  Future<void> _dialAction() async {
    if (_busy) return;
    _busy = true;
    try {
      await createFreeRoom(context, env: _env, config: _config);
    } finally {
      _busy = false;
    }
  }

  void _applyConfig(RoomRuleConfig v) {
    setState(() {
      _config = v;
      _selected = v.env;
    });
    ModeSelection.instance.select(_entry);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FreeEnvRail(
          entries: _tab.entries,
          selected: _selected,
          onSelect: _selectEntry,
        ),
        ...floatingCards(),
        MatchDial(
          title: '创建房间',
          info: '邀请好友 · 房主设规则',
          hint: '点击创建房间',
          onTap: _dialAction,
        ),
        RoomRulePanel(
          title: '规则设置',
          rows: [
            modeRow(
              _config,
              (v) => _applyConfig(v),
              options: const ['单局', '三局两胜'],
              values: const [0, 1],
            ),
            ...baseRuleRows(
              _config,
              (v) => _applyConfig(v),
              includeCardRule: false,
            ),
          ],
          checks: [
            RuleCheckSpec(
              key: 'noCheck',
              label: '不检查卡组',
              value: _config.noCheck,
              onChanged: (v) => _applyConfig(_config.copyWith(noCheck: v)),
            ),
            RuleCheckSpec(
              key: 'noShuffle',
              label: '不切洗卡组',
              value: _config.noShuffle,
              onChanged: (v) => _applyConfig(_config.copyWith(noShuffle: v)),
            ),
          ],
          collapsed: _config.collapsed,
          onToggleCollapsed: () => _applyConfig(
            _config.copyWith(collapsed: !_config.collapsed),
          ),
          checksTop: 180,
          height: 204,
        ),
      ],
    );
  }
}
