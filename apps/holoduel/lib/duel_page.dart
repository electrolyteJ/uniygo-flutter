import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:holoduel/widgets/intro_overlay.dart';
import 'package:provider/provider.dart';
import 'models/duel_state.dart';
import 'theme/duel_theme.dart';
import 'widgets/cosmos_background.dart';
import 'widgets/field/duel_field_3d.dart';
import 'widgets/end_screen.dart';
import 'widgets/fx_layer.dart';
import 'widgets/hand_area.dart';
import 'widgets/lp_plate.dart';
import 'widgets/mode_screen.dart';
import 'widgets/overlays.dart';
import 'widgets/phase_rail.dart';
import 'widgets/turn_banner.dart';

class DuelPage extends StatefulWidget {
  const DuelPage({super.key});

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  bool _intro = false;

  Future<void> _pick(GameMode mode) async {
    final state = context.read<DuelState>();
    await state.startGame(mode);
    setState(() => _intro = true);
    await Future.delayed(const Duration(milliseconds: 1750));
    if (!mounted) return;
    setState(() => _intro = false);
    await state.beginFirstTurn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuelTheme.void_,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            context.read<DuelState>().endTurn();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Consumer<DuelState>(
          builder: (context, state, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const CosmosBackground(),
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.1),
                      radius: 1.1,
                      colors: [Colors.transparent, DuelTheme.void_.withValues(alpha: .8)],
                    ),
                  ),
                ),
                if (state.started) _game(state) else ModeScreen(onPick: _pick),
                if (_intro) const IntroOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _game(DuelState state) {
    final viewer = state.viewer;
    final foeHandCount = state.side(otherSide(viewer)).hand.length;
    final aiTurnRunning = state.mode == GameMode.ai && state.turn == Side.foe;
    final size = MediaQuery.of(context).size;
    final narrow = size.width < 760;
    return AnimatedBuilder(
      animation: state.fx,
      builder: (context, _) => Transform.translate(
        offset: state.fx.shakeOffset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: DuelField3d(state: state)
                    .animate(key: ValueKey(state.started))
                    .fadeIn(duration: 800.ms)
                    .scaleXY(begin: .92, end: 1, duration: 800.ms, curve: Curves.easeOut),
              ),
            ),
            Positioned(top: 14, left: 0, right: 0, child: Center(child: LpPlate(state: state, side: Side.foe))),
            Positioned(bottom: 14, left: 14, child: LpPlate(state: state, side: Side.own)),
            Positioned(
              top: narrow ? 100 : 20,
              right: 24,
              child: SizedBox(
                width: foeHandCount > 0 ? 30 + (foeHandCount - 1) * 18 : 0,
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(foeHandCount, (i) {
                    final off = i - (foeHandCount - 1) / 2;
                    return Positioned(
                      left: i * 18.0,
                      top: 0,
                      child: Transform.rotate(
                        angle: off * 0.12,
                        child: Container(
                          width: 30,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const RadialGradient(colors: [Color(0xFF3A2154), Color(0xFF180C28)]),
                            border: Border.all(color: const Color(0xFF6A4A8A)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 6)],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Positioned(right: 20, top: 0, bottom: 0, child: Center(child: PhaseRail(state: state))),
            Positioned(
              right: 24,
              bottom: narrow ? 118 : 24,
              child: Opacity(
                opacity: aiTurnRunning ? .45 : 1,
                child: GestureDetector(
                  onTap: aiTurnRunning ? null : () => state.endTurn(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [DuelTheme.goldHi, DuelTheme.gold, Color(0xFFB98A2E)]),
                      boxShadow: [
                        BoxShadow(color: DuelTheme.gold.withValues(alpha: .4), blurRadius: 24),
                      ],
                    ),
                    child: Text('结束回合 END TURN',
                        style: DuelTheme.body(14, color: const Color(0xFF0A0D24), w: FontWeight.w700, ls: 3)),
                  ),
                ),
              ),
            ),
            if (!narrow)
              Positioned(
                top: 16,
                left: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _hint('拖拽 / 点击手牌', '召唤 · 发动魔法 · 盖放陷阱'),
                    _hint('战斗阶段', '点我方怪兽,再点目标攻击'),
                    _hint('双击怪兽', '切换攻击 / 守备表示'),
                    _hint('空格键', '结束回合'),
                  ],
                ),
              ),
            Positioned(left: 0, right: 0, bottom: -6, child: Center(child: HandArea(state: state))),
            FxLayer(engine: state.fx),
            PopupsLayer(state: state),
            TurnBanner(data: state.banner),
            PreviewPanel(state: state),
            TrapPromptOverlay(state: state),
            RebirthOverlay(state: state),
            HandoffOverlay(state: state),
            EndScreen(state: state),
          ],
        ),
      ),
    );
  }

  Widget _hint(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k, style: DuelTheme.body(10, color: const Color(0xFF9AA6D8), ls: 1.5)),
            const SizedBox(width: 6),
            Text('— $v', style: DuelTheme.body(10, color: DuelTheme.textFaint, ls: 1.5)),
          ],
        ),
      );
}


