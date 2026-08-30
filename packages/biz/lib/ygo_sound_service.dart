import 'package:applog/console.dart' as console;

import 'package:audioplayers/audioplayers.dart';

class YgoSoundService {
  static const _uiBasePath = 'sounds/ui/';
  static const _duelBasePath = 'sounds/duel/';

  /// 全局静音开关（供集成/单元测试禁用音频）。
  ///
  /// 置 false 后所有 play* 方法直接返回，不再创建 [AudioPlayer]，
  /// 从而避免 audioplayers 的 FramePositionUpdater 在测试 teardown
  /// 时留下 transient callbacks（「An animation is still running even
  /// after the widget tree was disposed」）。
  static bool enabled = true;

  /// 实例级静音开关：观战「跳到当前局面」的静默清场期间由
  /// DuelMessageRouter 短暂置位（同步代码段，无 await 交错），
  /// 压掉清场过程中密集的过场音效。
  bool suppress = false;

  final _pool = <String, AudioPlayer>{};

  /// 已创建的播放器数（测试观测用）。
  int get activePlayerCount => _pool.length;

  /// 每个音效固定复用同一个 [AudioPlayer]。
  ///
  /// 旧实现只在播放器处于 stopped 时复用，播放中触发同名音效就新建并
  /// 覆盖池条目——被顶掉的旧播放器永不 dispose，原生 MediaPlayer
  /// 实例持续泄漏；一局对局几十次音效后原生实例耗尽，新播放器创建
  /// 失败/无声，表现为「音效时有时无」。
  AudioPlayer _acquire(String key) {
    return _pool.putIfAbsent(
      key,
      () => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
    );
  }

  Future<void> _play(String assetName) => _playAt(_uiBasePath, assetName);

  Future<void> _playDuel(String assetName) => _playAt(_duelBasePath, assetName);

  Future<void> _playAt(String basePath, String assetName) async {
    if (!enabled || suppress) return;
    final player = _acquire(assetName);
    try {
      // 同一音效连续触发：停掉旧播放重新播放（重启语义，不叠加声道）。
      await player.stop();
      await player.play(AssetSource('$basePath$assetName'));
    } catch (e) {
      // 资源缺失/平台解码失败/音频焦点丢失：记录日志而不是静默无声
      // （调用方全部 unawaited，异常会顶成未处理异步错误）。
      console.log('Sound play failed: $assetName: $e');
    }
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
