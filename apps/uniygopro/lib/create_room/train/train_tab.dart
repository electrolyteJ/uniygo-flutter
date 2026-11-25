/// 练习页签：人机对决 / 残局挑战 / 新手引导 + 规则面板 + 残局选择层。
library;

import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_sound.dart';
import '../../util/start_util.dart';
import '../models/mode_models.dart';
import '../widgets/floating_cards.dart';
import '../widgets/mode_rail.dart';
import '../widgets/match_dial.dart';
import '../widgets/room_rule_panel.dart';
import 'puzzle_panel.dart';
import 'ai_duel_launch.dart';
import 'puzzle_launch.dart';

class TrainTab extends StatefulWidget {
  const TrainTab({super.key});

  @override
  State<TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends State<TrainTab> {
  late final DuelModeTab _tab = DuelModes.tabs[2];

  int _selected = DuelModes.tabs[2].defaultIndex;
  RoomRuleConfig _config = const RoomRuleConfig();

  bool _puzzleOpen = false;
  Future<List<PuzzleInfo>>? _puzzleFuture;
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

  void _openPuzzlePicker() {
    DuelSounds.dialogOpen();
    setState(() {
      _puzzleOpen = true;
      _puzzleFuture ??= loadPuzzles();
    });
  }

  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    try {
      switch (_entry.id) {
        case 'practice-ai':
          DuelSounds.pageTransition();
          await startAiDuel(context, _config);
        case 'practice-puzzle':
          _openPuzzlePicker();
        default:
          await startDuelRoom(context, _entry);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModeRail(entries: _tab.entries, selected: _selected, onSelect: _selectEntry),
        ...floatingCards(),
        MatchDial(
          title: switch (_entry.id) {
            'practice-ai' => '开始人机对战',
            'practice-puzzle' => '开始残局',
            _ => '敬请期待',
          },
          info: switch (_entry.id) {
            'practice-ai' => '本地人机 · 无需联网',
            'practice-puzzle' => '固定局面 · 一回合',
            _ => '教学关卡 · 开发中',
          },
          hint: switch (_entry.id) {
            'practice-ai' => '点击开始对战',
            'practice-puzzle' => '点击开始残局',
            _ => '暂未开放',
          },
          onTap: _run,
        ),
        RoomRulePanel(
          title: '规则设置',
          value: _config,
          onChanged: (v) => setState(() => _config = v),
          showModeRow: true,
          checksTop: 236,
        ),
        if (_puzzleOpen)
          PuzzlePanel(
            future: _puzzleFuture,
            onSelect: (p) {
              setState(() => _puzzleOpen = false);
              startPuzzle(context, p);
            },
            onClose: () => setState(() => _puzzleOpen = false),
          ),
      ],
    );
  }
}
