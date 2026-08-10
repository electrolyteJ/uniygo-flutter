import 'package:audioplayers/audioplayers.dart';

class DuelSoundService {
  static const _basePath = 'sounds/duel/';

  final _pool = <String, AudioPlayer>{};

  AudioPlayer _acquire(String key) {
    final existing = _pool[key];
    if (existing != null && existing.state == PlayerState.stopped) {
      return existing;
    }
    final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _pool[key] = player;
    return player;
  }

  Future<void> _play(String assetName) async {
    final player = _acquire(assetName);
    await player.stop();
    await player.play(AssetSource('$_basePath$assetName'));
  }

  Future<void> playDuelStart() => _play('duel_start.wav');
  Future<void> playNewTurn() => _play('new_turn.wav');
  Future<void> playNewPhase() => _play('new_phase.wav');
  Future<void> playCardDraw() => _play('card_draw.wav');
  Future<void> playSummon() => _play('summon.wav');
  Future<void> playSpecialSummon() => _play('special_summon.wav');
  Future<void> playFlipSummon() => _play('flip_summon.wav');
  Future<void> playSetCard() => _play('set_card.wav');
  Future<void> playAttack() => _play('attack.wav');
  Future<void> playBattle() => _play('battle.wav');
  Future<void> playDamage() => _play('damage.wav');
  Future<void> playRecover() => _play('recover.wav');
  Future<void> playChain() => _play('chain.wav');
  Future<void> playChainEnd() => _play('chain_end.wav');
  Future<void> playDuelWin() => _play('duel_win.wav');
  Future<void> playCoinToss() => _play('coin_toss.wav');
  Future<void> playDice() => _play('dice.wav');
  Future<void> playCardDestroy() => _play('card_destroy.wav');
  Future<void> playPosChange() => _play('pos_change.wav');
  Future<void> playDamageStep() => _play('damage_step.wav');
  Future<void> playShuffleDeck() => _play('shuffle_deck.wav');

  void dispose() {
    for (final player in _pool.values) {
      player.dispose();
    }
    _pool.clear();
  }
}
