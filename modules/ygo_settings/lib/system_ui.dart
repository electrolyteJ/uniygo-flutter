/// 系统 UI 模式：启动和从后台回来时保持沉浸式（隐藏状态栏 / 导航栏）。
///
/// 设置页的「全屏」开关持久化在 [kFullscreenSettingKey]；启动时按它应用，
/// 默认开启，保证进游戏即沉浸式。
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全屏（沉浸式）设置的持久化键。
const String kFullscreenSettingKey = 'home_settings.fullscreen';

/// 进入沉浸式：隐藏状态栏与导航栏，边缘滑动可临时唤出（sticky）。
Future<void> enterImmersiveMode() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

/// 恢复系统栏（非全屏时使用）。
Future<void> exitImmersiveMode() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// 按开关应用系统 UI。
Future<void> applyFullscreenSetting(bool fullscreen) =>
    fullscreen ? enterImmersiveMode() : exitImmersiveMode();

/// 读取持久化开关并应用（缺省 = 全屏）。
///
/// 启动时调用一次；从后台回到前台再调用一次，避免系统把系统栏还回来
/// （弹输入法、切后台、权限弹窗之后常见）。
Future<void> reapplyPersistedSystemUi() async {
  final prefs = await SharedPreferences.getInstance();
  await applyFullscreenSetting(prefs.getBool(kFullscreenSettingKey) ?? true);
}

/// 启动时应用（语义别名，便于调用点自解释）。
Future<void> applyStartupSystemUi() => reapplyPersistedSystemUi();

/// 路由变化后重新应用系统 UI。
///
/// GoRouter 的观察者：弹窗/页面切换后 Android 会把导航栏还回来，
/// immersiveSticky 不会自动重放，这里补一刀。
final NavigatorObserver systemUiRouteObserver = _SystemUiRouteObserver();

class _SystemUiRouteObserver extends NavigatorObserver {
  void _reapply() => unawaited(reapplyPersistedSystemUi());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _reapply();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _reapply();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _reapply();
}
