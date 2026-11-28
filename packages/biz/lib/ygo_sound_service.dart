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

  // ──────────────────────────────────────────
  // BGM（背景音乐）
  // ──────────────────────────────────────────
  //
  // BGM 与一次性音效是**两套资源**：音效走 [_pool] 复用池、句柄短命；
  // BGM 独占一个播放器、循环播放、跨页面存活，必须能单独停止或替换。
  // 混在一起会让「停 BGM」把音效池一起动掉（反之亦然）。

  /// BGM 目录：`assets/sounds/bgm/`。
  static const _bgmBasePath = 'sounds/bgm/';

  AudioPlayer? _bgmPlayer;

  /// 当前正在播放（或正在切）的 BGM 资源名，用于幂等判断。
  String? _currentBgm;

  /// 淡出起点音量（与最近一次 [playBgm] 的 volume 对齐）。
  double _bgmVolume = 0.55;

  /// 当前 BGM 资源名（测试与调试观测用）。
  String? get currentBgm => _currentBgm;

  /// 播放 BGM（默认循环）。
  ///
  /// 幂等：已经在播同一首时直接返回，重复调用不会重启曲目——页面重建
  /// （`initState` 重新走一遍）是常态，若每次都重启，玩家会听到音乐
  /// 反复从头开始。
  ///
  /// [loop] 为 false 时播完即止，适合短促的入场曲：入场音乐是「一段过场」，
  /// 播完就该静下来，不是持久的环境音。
  Future<void> playBgm(
    String assetName, {
    bool loop = true,
    double volume = 0.55,
  }) async {
    if (!enabled) return;
    // 同一首已在播：不重启（见上方幂等说明）。
    if (_currentBgm == assetName && _bgmPlayer?.state == PlayerState.playing) {
      return;
    }
    final player = _bgmPlayer ??= AudioPlayer();
    try {
      await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(AssetSource('$_bgmBasePath$assetName'), volume: volume);
      _currentBgm = assetName;
      _bgmVolume = volume;
    } catch (e) {
      console.log('Bgm play failed: $assetName: $e');
    }
  }

  /// 切换 BGM；与 [playBgm] 的区别是**允许从同一首重启**。
  ///
  /// 用于「同一首曲子换个段落」的场景：目标曲已经在播时也强制从头播。
  Future<void> switchBgm(
    String assetName, {
    bool loop = true,
    double volume = 0.55,
  }) async {
    _currentBgm = null;
    await playBgm(assetName, loop: loop, volume: volume);
  }

  /// 停止并清空当前 BGM。
  ///
  /// 离开对局/房间销毁时调用：BGM 播放器是长命的，不主动停会一直响到
  /// 进程结束（页面销毁不会带走 Service 实例）。
  Future<void> stopBgm() async {
    _currentBgm = null;
    final player = _bgmPlayer;
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      console.log('Bgm stop failed: $e');
    }
  }

  /// 淡出后停止（退出房间时的收尾，避免音乐戛然而止）。
  Future<void> fadeOutBgm({
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    final player = _bgmPlayer;
    if (player == null || _currentBgm == null) return;
    _currentBgm = null;
    const steps = 12;
    final stepMs = duration.inMilliseconds ~/ steps;
    for (var i = steps; i >= 0; i--) {
      try {
        await player.setVolume(_bgmVolume * i / steps);
      } catch (_) {
        break;
      }
      if (i > 0) await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
    try {
      await player.stop();
    } catch (e) {
      console.log('Bgm fade-out stop failed: $e');
    }
  }
}
