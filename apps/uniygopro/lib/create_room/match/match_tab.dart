/// 匹配页签：竞技 / 娱乐 rail + 匹配盘。
///
/// 页签自带 [MatchController]，只依赖舞台共享组件，不再靠外层页面传状态。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_sound.dart';
import '../models/mode_models.dart';
import '../widgets/floating_cards.dart';
import '../widgets/mode_rail.dart';
import '../widgets/match_dial.dart';
import 'match_controller.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key, this.autoStart = false});

  /// 从主页「开始匹配」进入时自动开始。
  final bool autoStart;

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> {
  late final MatchController _match;
  late final DuelModeTab _tab = DuelModes.tabs[0];

  int _selected = DuelModes.tabs[0].defaultIndex;

  DuelModeEntry get _entry => _tab.entries[_selected];

  @override
  void initState() {
    super.initState();
    _match = MatchController()..addListener(_onChanged);
    final current = ModeSelection.instance.current;
    final index = _tab.entries.indexWhere((e) => identical(e, current));
    if (index >= 0) _selected = index;
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startOrCancel();
      });
    }
  }

  @override
  void dispose() {
    _match.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _selectEntry(int index) {
    if (index == _selected) return;
    DuelSounds.tabSwitch();
    setState(() => _selected = index);
    ModeSelection.instance.select(_entry);
  }

  void _startOrCancel() {
    if (_match.matching) {
      _match.cancel();
      return;
    }
    _match.start(
      context,
      arena: _entry.id == 'athletic' ? 'athletic' : 'entertain',
      title: _entry.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final matching = _match.matching;
    final athletic = _entry.id == 'athletic';
    return Stack(
      children: [
        ModeRail(entries: _tab.entries, selected: _selected, onSelect: _selectEntry),
        ...floatingCards(),
        MatchDial(
          title: matching ? '匹配中' : '开始匹配',
          info: matching
              ? '已等待 ${_match.elapsed}s · 均 12s'
              : (athletic ? '均 12s · 3,214 人在线' : '单局 · 1,102 人在线'),
          hint: matching ? '点击取消匹配' : '点击进入匹配',
          onTap: _startOrCancel,
        ),
      ],
    );
  }
}
