export 'cyber_palette.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「赛博演出增强层」开关（持久化，默认开启）。
///
/// 皮肤底板（HUD 色板、灯光、城市天际线、地面网格）常驻；本开关控制
/// 其上的动态演出强度：HUD 后处理（扫描线 / 雨丝 / 噪点 / 故障条）、
/// 地砖霓虹脉冲、召唤与攻击的多层特效、粒子密度。
///
/// 放在 duel_room3 内部而非 ygo_settings：避免给模块引入新的跨包依赖，
/// 且切换只影响 3D 房。所有 3D 组件都在 update / 播放时读取 [isOn]，
/// 因此切换即时生效，不需要重建 Duel3DGame（灯光颜色在 onLoad 时定，
/// 属常驻底板，不随开关变化）。
abstract final class CyberSkin {
  static const String _prefsKey = 'duel_room3_cyber_skin';

  /// 当前生效状态（全局可听）。
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static bool get isOn => enabled.value;

  /// 启动时恢复偏好（决斗场地页 initState 调用）。
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  static Future<void> toggle() => set(!enabled.value);
}
