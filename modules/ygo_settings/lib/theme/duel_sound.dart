/// 三屏共用的 UI 音效入口。
///
/// 音效属于装饰性反馈：当 [ServiceSingleton] 尚未注册（widget 测试、
/// 设计预览等）时静默跳过，不让交互因音频服务缺失而失败。
library;

import 'package:biz/service_singleton.dart';
import 'package:biz/ygo_sound_service.dart';

abstract final class DuelSounds {
  static void tap() => _play((s) => s.playButtonTap());
  static void dialogOpen() => _play((s) => s.playDialogOpen());
  static void dialogClose() => _play((s) => s.playDialogClose());
  static void tabSwitch() => _play((s) => s.playTabSwitch());
  static void pageTransition() => _play((s) => s.playPageTransition());
  static void homeEnter() => _play((s) => s.playLobbyEnter());
  static void success() => _play((s) => s.playSuccess());
  static void matchStart() => _play((s) => s.playMatchStart());
  static void matchFound() => _play((s) => s.playMatchFound());
  static void error() => _play((s) => s.playError());

  static void _play(void Function(YgoSoundService service) action) {
    try {
      action(ServiceSingleton.instance.ygoSoundService);
    } catch (_) {
      // 音效服务未装配时忽略。
    }
  }
}
