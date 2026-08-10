import 'package:audioplayers/audioplayers.dart';

class UISoundService {
  static const _basePath = 'sounds/ui/';

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

  void dispose() {
    for (final player in _pool.values) {
      player.dispose();
    }
    _pool.clear();
  }
}
