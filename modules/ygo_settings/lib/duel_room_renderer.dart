import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 决斗房渲染实现偏好（全局设置项，持久化）。
///
/// 放在 ygo_settings 而非宿主 app：设置弹窗与本偏好同属全局设置，
/// 避免 ygo_settings 反向依赖 uniygopro；宿主只负责把枚举映射成路由路径。
enum DuelRoomRenderer {
  /// duel_room1：Flame 2D 渲染，全平台可用。
  room2d,

  /// duel_room3：flame_3d 纯 3D 场景，依赖 Flutter GPU（Web 不支持）。
  room3d,
}

abstract final class DuelRoomRendererPreference {
  static const String _prefsKey = 'duel_room_renderer';

  /// 当前生效的渲染实现（全局可听，默认 2D）。
  static final ValueNotifier<DuelRoomRenderer> current =
      ValueNotifier(DuelRoomRenderer.room2d);

  /// 启动时恢复偏好（宿主 app main 中调用）。
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    current.value = DuelRoomRenderer.values.asNameMap()[saved] ??
        DuelRoomRenderer.room2d;
  }

  static Future<void> set(DuelRoomRenderer value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.name);
  }
}
