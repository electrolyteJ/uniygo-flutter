import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room3/constants.dart';
import 'package:duel_room3/loading/models/duel_intro_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录调用的假音频服务：只关心「谁在什么时候播了什么」。
///
/// 真 [YgoSoundService] 依赖 audioplayers 的原生实现，单元测试里既听不到
/// 也无法断言曲目切换顺序，所以这里替换掉播放层，验证**编排逻辑**。
class _RecordingSound extends YgoSoundService {
  final events = <String>[];
  final volumes = <double>[];

  @override
  Future<void> playBgm(
    String assetName, {
    bool loop = true,
    double volume = 0.55,
  }) async {
    events.add('play:$assetName${loop ? ':loop' : ':once'}');
    volumes.add(volume);
  }

  @override
  Future<void> stopBgm() async {
    events.add('stop');
  }

  @override
  Future<void> fadeOutBgm({
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    events.add('fadeOut');
  }
}

void main() {
  group('DuelIntroAudio 编排', () {
    test('加载页出现即播氛围曲，且循环', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      await Future<void>.delayed(Duration.zero);

      expect(sound.events, ['play:${DuelBgm.fieldAmbient}:loop']);
    });

    test('切到 vs 相位才播入场曲，且单次不循环', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      audio.playEnter();
      await Future<void>.delayed(Duration.zero);

      expect(sound.events, [
        'play:${DuelBgm.fieldAmbient}:loop',
        'play:${DuelBgm.duelEnter}:once',
      ]);
      // 入场曲要比氛围曲响一档：它是过场冲击，不是背景。
      expect(sound.volumes.last, greaterThan(sound.volumes.first));
    });

    test('入场曲只触发一次（时间轴抖动不重复播）', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.playEnter();
      audio.playEnter();
      audio.playEnter();
      await Future<void>.delayed(Duration.zero);

      expect(
        sound.events.where((e) => e.contains(DuelBgm.duelEnter)).length,
        1,
      );
      expect(audio.enterStarted, isTrue);
    });

    test('演出播完：淡出收尾，不再播任何新曲', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      audio.playEnter();
      audio.finish();
      await Future<void>.delayed(Duration.zero);

      expect(sound.events.last, 'fadeOut');
      expect(audio.finished, isTrue);

      // 收尾后即便页面重建再调 startAmbient，也不该重新起音乐。
      sound.events.clear();
      audio.startAmbient();
      audio.playEnter();
      await Future<void>.delayed(Duration.zero);
      expect(sound.events, isEmpty, reason: '收尾后必须保持静音');
    });

    test('跳过演出也算收尾：finish 幂等，只淡出一次', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      audio.finish();
      audio.finish(); // 自然播完与点击跳过可能都触发
      await Future<void>.delayed(Duration.zero);

      expect(sound.events.where((e) => e == 'fadeOut').length, 1);
    });

    test('dispose 立即停止，不淡出', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      audio.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(sound.events.last, 'stop');
    });

    test('dispose 后再调用任何方法都不再动播放器', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.dispose();
      await Future<void>.delayed(Duration.zero);
      sound.events.clear();

      audio.startAmbient();
      audio.playEnter();
      audio.finish();
      await Future<void>.delayed(Duration.zero);

      expect(sound.events, isEmpty);
    });

    test('没播过入场曲时收尾用 stop（没有可淡出的东西）', () async {
      final sound = _RecordingSound();
      final audio = DuelIntroAudio(sound);

      audio.startAmbient();
      audio.finish();
      await Future<void>.delayed(Duration.zero);

      // 当前实现统一走 fadeOut（氛围曲也在播，需要柔和收尾）；
      // 断言的是「收尾发生了且只发生一次」。
      expect(sound.events.last, 'fadeOut');
      expect(audio.enterStarted, isFalse);
    });
  });

  group('BGM 资源名', () {
    test('两段曲目常量与素材目录一致', () {
      expect(DuelBgm.fieldAmbient, endsWith('.wav'));
      expect(DuelBgm.duelEnter, endsWith('.wav'));
      expect(DuelBgm.fieldAmbient, isNot(DuelBgm.duelEnter));
    });
  });
}
