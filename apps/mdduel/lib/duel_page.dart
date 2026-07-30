import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'duel_game.dart';
import 'models/duel_state.dart';
import 'theme/md_theme.dart';
import 'widgets/hand_area.dart';
import 'widgets/lp_bar.dart';
import 'widgets/phase_bar.dart';
import 'widgets/turn_banner.dart';

class DuelPage extends StatefulWidget {
  const DuelPage({super.key});

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  late final DuelGame _game;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _game = DuelGame(state: context.read<DuelState>());
  }

  Future<void> _start(GameMode mode) async {
    final state = context.read<DuelState>();
    await state.startGame(mode);
    setState(() => _started = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    await state.beginFirstTurn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MdTheme.bg,
      body: Consumer<DuelState>(
        builder: (context, state, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              if (!_started) _modeScreen(),
              if (_started) ...[
                SafeArea(
                  child: Column(
                    children: [
                      _topBar(state),
                      const Spacer(),
                      HandArea(state: state),
                      const SizedBox(height: 4),
                      _bottomBar(state),
                    ],
                  ),
                ),
                TurnBanner(data: state.banner),
                if (state.lastAction != null) _actionToast(state),
                if (state.over) _endScreen(state),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _modeScreen() {
    return Container(
      color: MdTheme.bg.withValues(alpha: .92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('☥', style: TextStyle(fontSize: 48, color: MdTheme.gold.withValues(alpha: .8))),
            const SizedBox(height: 16),
            Text('MASTER DUEL', style: MdTheme.title(32, color: MdTheme.goldHi, ls: 8)),
            const SizedBox(height: 6),
            Text('决斗场景', style: MdTheme.body(14, color: MdTheme.textDim, ls: 4)),
            const SizedBox(height: 48),
            _modeButton('AI 对战', '单人模式 · 对抗AI', () => _start(GameMode.ai)),
            const SizedBox(height: 16),
            _modeButton('本地对战', '双人模式 · 同屏对决', () => _start(GameMode.local)),
          ],
        ).animate().fadeIn(duration: 600.ms).scaleXY(begin: .95, end: 1, duration: 600.ms),
      ),
    );
  }

  Widget _modeButton(String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: MdTheme.panel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MdTheme.gold.withValues(alpha: .4)),
        ),
        child: Column(
          children: [
            Text(title, style: MdTheme.title(16, color: MdTheme.goldHi, ls: 3)),
            const SizedBox(height: 4),
            Text(sub, style: MdTheme.body(11, color: MdTheme.textDim)),
          ],
        ),
      ),
    );
  }

  Widget _topBar(DuelState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LpBar(state: state, side: Side.foe),
          PhaseBar(state: state),
        ],
      ),
    );
  }

  Widget _bottomBar(DuelState state) {
    final aiTurnRunning = state.mode == GameMode.ai && state.turn == Side.foe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LpBar(state: state, side: Side.own),
          Opacity(
            opacity: aiTurnRunning ? .4 : 1,
            child: GestureDetector(
              onTap: aiTurnRunning ? null : () => state.endTurn(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [MdTheme.goldHi, MdTheme.gold, Color(0xFFB98A2E)]),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: MdTheme.gold.withValues(alpha: .3), blurRadius: 16)],
                ),
                child: Text('结束回合', style: MdTheme.body(13, color: const Color(0xFF0A0D24), w: FontWeight.w700, ls: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionToast(DuelState state) {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          key: ValueKey(state.lastAction),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: MdTheme.panel.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MdTheme.border),
          ),
          child: Text(state.lastAction!, style: MdTheme.body(12, color: MdTheme.text)),
        ).animate(key: ValueKey(state.lastAction)).fadeIn(duration: 200.ms).then(delay: 2000.ms).fadeOut(duration: 400.ms),
      ),
    );
  }

  Widget _endScreen(DuelState state) {
    final won = state.winner == Side.own;
    return Container(
      color: MdTheme.bg.withValues(alpha: .88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '胜利' : '败北', style: MdTheme.title(42, color: won ? MdTheme.goldHi : MdTheme.crimson, ls: 8)),
            const SizedBox(height: 8),
            Text(won ? 'DUEL WIN' : 'DUEL LOSS', style: MdTheme.body(13, color: MdTheme.textDim, ls: 4)),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                state.reset();
                setState(() => _started = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: MdTheme.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MdTheme.gold.withValues(alpha: .5)),
                ),
                child: Text('返回', style: MdTheme.title(14, color: MdTheme.goldHi, ls: 3)),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).scaleXY(begin: .9, end: 1, duration: 500.ms),
      ),
    );
  }
}
