import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 应用全局屏幕方向锁定（仅 Android/iOS 生效）。
///
/// 用 [kIsWeb] + [defaultTargetPlatform] 判定而非 dart:io，
/// 保证 Web/桌面平台编译与行为都不受影响。
bool get _isMobile {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// 全局横屏锁定（landscapeLeft/landscapeRight 双向）。
///
/// 整个应用（含决斗房间）固定横屏；在 main() 的
/// WidgetsFlutterBinding.ensureInitialized() 之后、runApp 之前调用一次即可。
///
/// 配套平台配置：
///  - iOS：Info.plist 的 UISupportedInterfaceOrientations 仅保留横屏两项；
///  - Android：MainActivity 声明 android:screenOrientation="sensorLandscape"，
///    避免启动瞬间竖屏闪烁。
void lockAppLandscape() {
  if (!_isMobile) return;
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );
}
