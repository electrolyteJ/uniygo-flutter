/// YgoSoundService suppress（观战静默追赶）测试。
library;

import 'package:biz/ygo_sound_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 屏蔽 audioplayers 平台通道：global init 与逐播放器方法全部 no-op，
    // 使播放器创建/播放不依赖真实平台实现。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  test('suppress 期间不创建播放器；恢复后正常创建', () async {
    final sound = YgoSoundService();
    expect(sound.activePlayerCount, 0);

    sound.suppress = true;
    // suppress 期间直接返回：不创建播放器。
    await sound.playDuelStart();
    expect(sound.activePlayerCount, 0, reason: 'suppress 期间应直接返回');

    sound.suppress = false;
    await sound.playDuelStart();
    expect(sound.activePlayerCount, 1, reason: '恢复后正常创建播放器');
  });
}
