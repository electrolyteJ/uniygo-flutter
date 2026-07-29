import 'package:duelarena/widgets/action_buttons.dart';
import 'package:duelarena/duel_game.dart';
import 'package:duelarena/widgets/hand_area.dart';
import 'package:duelarena/widgets/lp_bar.dart';
import 'package:duelarena/widgets/phase_bar.dart';
import 'package:duelarena/widgets/player_banner.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/duel_state.dart';
import 'duel_world.dart';

class DuelPage extends StatefulWidget {
  const DuelPage({super.key});

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  late final DuelGame _game;

  @override
  void initState() {
    super.initState();
    // Demo data is loaded in the provider's create() callback, so the state
    // is ready here. context.read() is allowed in initState (it doesn't
    // register a dependency); notifyListeners() must NOT be called during
    // the build phase (didChangeDependencies/build).
    final state = context.read<DuelState>();
    final world = DuelWorld(state: state);
    _game = DuelGame(world: world);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Consumer<DuelState>(
              builder: (context, state, _) {
                return Column(
                  children: [
                    _buildTopBar(state),
                    const Spacer(),
                    _buildPlayerHand(state),
                    const SizedBox(height: 4),
                    _buildBottomBar(state),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(DuelState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: LpBar(
              lp: state.opponentLp,
              playerName: state.opponentName,
              isOpponent: true,
              isActive: !state.isPlayerTurn,
            ),
          ),
          const SizedBox(width: 8),
          PlayerBanner(
            name: state.opponentName,
            isOpponent: true,
            deckCount: state.opponentField.deckCount,
            graveCount: state.opponentField.graveCount,
            extraCount: state.opponentField.extraCount,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHand(DuelState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: HandArea(
        cards: state.playerHand,
        selectedIndex: state.selectedZoneIndex,
        onCardTap: (i) {
          state.selectCard(state.playerHand[i], zoneIndex: i);
        },
      ),
    );
  }

  Widget _buildBottomBar(DuelState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhaseBar(
            currentPhase: state.phase,
            isPlayerTurn: state.isPlayerTurn,
            turn: state.turn,
            onPhaseTap: (p) => state.setPhase(p),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: LpBar(
                  lp: state.playerLp,
                  playerName: state.playerName,
                  isActive: state.isPlayerTurn,
                ),
              ),
              const SizedBox(width: 8),
              PlayerBanner(
                name: state.playerName,
                deckCount: state.playerField.deckCount,
                graveCount: state.playerField.graveCount,
                extraCount: state.playerField.extraCount,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ActionButtons(
            onNextPhase: () => state.nextPhase(),
            onSummon: () {
              if (state.selectedCard != null) {
                final emptyIdx = state.playerField.monsterZones.indexWhere(
                  (c) => c == null,
                );
                if (emptyIdx >= 0) {
                  state.placeMonster(emptyIdx, state.selectedCard!);
                  state.removeFromHand(state.selectedZoneIndex ?? -1);
                  state.selectCard(null);
                }
              }
            },
            onAttack: () {},
            onSurrender: () {},
          ),
        ],
      ),
    );
  }
}
