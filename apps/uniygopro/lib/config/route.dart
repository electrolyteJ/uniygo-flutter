import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room3/duel_room_page.dart';
import 'package:debug/duel_3d_preview_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/create_room/match_page.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:deck_editor3/deck_editor3.dart';
import 'package:flutter/foundation.dart';
import 'package:ygo_settings/ygo_settings.dart';

abstract final class Routes {
  static const home = '/';
  static const duelRoom = '/duel-room';
}


/// 启动时恢复偏好（main.dart 初始化期调用）。
Future<void> restore() => DuelRoomRendererPreference.restore();

bool get _is3D => DuelRoomRendererPreference.current.value == DuelRoomRenderer.room3d;
final router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: '/match', builder: (_, _) => const MatchPage()),
    GoRoute(
      path: '/duel-room',
      redirect: (_, state) =>
      state.extra is Map<String, Object?> ? null : Routes.home,
      builder: (_, state) {
        if (_is3D) {
          return DuelRoomPage3D(args: state.extra! as Map<String, Object?>);
        } else {
          return DuelRoomPage(args: state.extra! as Map<String, Object?>);
        }
      },
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
    // 卡组中心：卡组市场（MDPro3 卡组广场）+ 我的卡组 + 组卡编辑器。
    GoRoute(
      path: '/deck-square',
      builder: (_, _) => const DeckHubPage(),
    ),
  ],
);
