import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room3/duel_room_page.dart';
import 'package:duel_room3/field/duel_3d_preview_page.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/create_room/match_page.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:flutter/foundation.dart';
import 'package:ygo_settings/ygo_settings.dart';

abstract final class Routes {
  static const home = '/';
}

/// 决斗房间路由偏好：把 ygo_settings 的 [DuelRoomRendererPreference]
///（全局设置项，设置弹窗内切换并持久化）映射为路由路径。
///
/// - `/duel-room`：duel_room1（Flame 2D，默认，全平台）
/// - `/duel-room3`：duel_room3（flame_3d 3D 场景，需 Flutter GPU，Web 不支持）
abstract final class DuelRoomRoute {
  static const String defaultPath = '/duel-room';
  static const String path3D = '/duel-room3';

  /// 当前生效的决斗房路由路径。
  static String get current =>
      switch (DuelRoomRendererPreference.current.value) {
        DuelRoomRenderer.room2d => defaultPath,
        DuelRoomRenderer.room3d => path3D,
      };

  /// 可监听的路径流（UI 跟随设置变化）。
  static ValueListenable<DuelRoomRenderer> get rendererListenable =>
      DuelRoomRendererPreference.current;

  /// 启动时恢复偏好（main.dart 初始化期调用）。
  static Future<void> restore() => DuelRoomRendererPreference.restore();

  static bool get is3D =>
      DuelRoomRendererPreference.current.value == DuelRoomRenderer.room3d;
}

final router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: '/match', builder: (_, _) => const MatchPage()),
    GoRoute(
      path: '/duel-room',
      redirect: (_, state) =>
          state.extra is Map<String, Object?> ? null : Routes.home,
      builder: (_, state) =>
          DuelRoomPage(args: state.extra! as Map<String, Object?>),
    ),
    // duel_room3：flame_3d 纯 3D 决斗场（需 Flutter GPU，Web 会降级提示）。
    GoRoute(
      path: '/duel-room3',
      redirect: (_, state) =>
          state.extra is Map<String, Object?> ? null : Routes.home,
      builder: (_, state) =>
          DuelRoomPage3D(args: state.extra! as Map<String, Object?>),
    ),
    GoRoute(path: '/card-live', builder: (_, _) => const CardLivePage()),
    // duel_room3 场景预览（免服务器验收 3D 渲染与效果）。
    GoRoute(
      path: '/duel-room3-preview',
      builder: (_, _) => const Duel3DPreviewPage(),
    ),
    GoRoute(
      path: '/deck-editor',
      builder: (_, state) => DeckEditorPage(
        args: state.extra is Map<String, Object?>
            ? state.extra as Map<String, Object?>
            : null,
      ),
    ),
  ],
);
