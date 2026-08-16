import 'package:audioplayers/audioplayers.dart';

class YgoSoundService {
  static const _uiBasePath = 'sounds/ui/';
  static const _duelBasePath = 'sounds/duel/';

  /// 全局静音开关（供集成/单元测试禁用音频）。
  ///
  /// 置 false 后所有 play* 方法直接返回，不再创建 [AudioPlayer]，
  /// 从而避免 audioplayers 的 `FramePositionUpdater` 在测试 teardown
  /// 时留下 transient callbacks（「An animation is still running even
  /// after the widget tree was disposed」）。
  static bool enabled = true;

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
    if (!enabled) return;
    final player = _acquire(assetName);
    await player.stop();
    await player.play(AssetSource('$_uiBasePath$assetName'));
  }

  Future<void> _playDuel(String assetName) async {
    if (!enabled) return;
    final player = _acquire(assetName);
    await player.stop();
    await player.play(AssetSource('$_duelBasePath$assetName'));
  }

  Future<void> playButtonTap() => _play('button_tap.wav');
  Future<void> playDialogOpen() => _play('dialog_open.wav');
  Future<void> playDialogClose() => _play('dialog_close.wav');
  Future<void> playPageTransition() => _play('page_transition.wav');
  Future<void> playBackNavigation() => _play('back_navigation.wav');
  Future<void> playRoomConnected() => _play('room_connected.wav');
  Future<void> playLobbyEnter() => _play('lobby_enter.wav');
  Future<void> playHandSelection() => _play('hand_selection.wav');
  Future<void> playTurnSelection() => _play('turn_selection.wav');
  Future<void> playReady() => _play('ready.wav');
  Future<void> playUnready() => _play('unready.wav');
  Future<void> playChatMessage() => _play('chat_message.wav');
  Future<void> playCardAdd() => _play('card_add.wav');
  Future<void> playCardRemove() => _play('card_remove.wav');
  Future<void> playDeckSave() => _play('deck_save.wav');
  Future<void> playDeckShuffle() => _play('deck_shuffle.wav');
  Future<void> playDeckClear() => _play('deck_clear.wav');
  Future<void> playError() => _play('error.wav');
  Future<void> playSuccess() => _play('success.wav');
  Future<void> playTabSwitch() => _play('tab_switch.wav');
  Future<void> playToggleOn() => _play('toggle_on.wav');
  Future<void> playToggleOff() => _play('toggle_off.wav');
  Future<void> playZoneOpen() => _play('zone_open.wav');
  Future<void> playZoneClose() => _play('zone_close.wav');
  Future<void> playMenuOpen() => _play('menu_open.wav');
  Future<void> playMenuClose() => _play('menu_close.wav');
  Future<void> playDuelResult() => _play('duel_result.wav');
  Future<void> playMatchFound() => _play('match_found.wav');
  Future<void> playMatchStart() => _play('match_start.wav');
  Future<void> playTurnHint() => _play('turn_hint.wav');

//duel sounds
  Future<void> playDuelStart() => _playDuel('duel_start.wav');
  Future<void> playNewTurn() => _playDuel('new_turn.wav');
  Future<void> playNewPhase() => _playDuel('new_phase.wav');
  Future<void> playCardDraw() => _playDuel('card_draw.wav');
  Future<void> playSummon() => _playDuel('summon.wav');
  Future<void> playSpecialSummon() => _playDuel('special_summon.wav');
  Future<void> playFlipSummon() => _playDuel('flip_summon.wav');
  Future<void> playSetCard() => _playDuel('set_card.wav');
  Future<void> playAttack() => _playDuel('attack.wav');
  Future<void> playBattle() => _playDuel('battle.wav');
  Future<void> playDamage() => _playDuel('damage.wav');
  Future<void> playRecover() => _playDuel('recover.wav');
  Future<void> playChain() => _playDuel('chain.wav');
  Future<void> playChainEnd() => _playDuel('chain_end.wav');
  Future<void> playDuelWin() => _playDuel('duel_win.wav');
  Future<void> playCoinToss() => _playDuel('coin_toss.wav');
  Future<void> playDice() => _playDuel('dice.wav');
  Future<void> playCardDestroy() => _playDuel('card_destroy.wav');
  Future<void> playPosChange() => _playDuel('pos_change.wav');
  Future<void> playDamageStep() => _playDuel('damage_step.wav');
  Future<void> playShuffleDeck() => _playDuel('shuffle_deck.wav');

  void dispose() {
    for (final player in _pool.values) {
      player.dispose();
    }
    _pool.clear();
  }
}
