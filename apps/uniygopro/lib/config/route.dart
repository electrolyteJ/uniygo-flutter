import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room3/duel_room_page.dart';
import 'package:debug/duel_3d_preview_page.dart';
import 'package:debug/duel_1_preview_page.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/create_room/match_page.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:deck_editor3/deck_editor3.dart';
import 'package:ygo_settings/ygo_settings.dart';

abstract final class Routes {
  static const home = '/';
  static const duelRoom = '/duel-room';
  static const duelRoomPreview = '/duel-room-preview';
  static const duelRoom3Preview = '/duel-room3-preview';
  static const deckHub = '/deck-hub';
  static const deckEditor = '/deck-editor';
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
      path: Routes.duelRoom,
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
    GoRoute(
      path: Routes.duelRoomPreview,
      builder: (_, _) => const Duel1PreviewPage(),
    ),
    GoRoute(
      path: Routes.duelRoom3Preview,
      builder: (_, _) => const Duel3DPreviewPage(),
    ),
    GoRoute(
      path: Routes.deckEditor,
      builder: (_, state) => DeckEditorPage(
        args: state.extra is Map<String, Object?>
            ? state.extra as Map<String, Object?>
            : null,
      ),
    ),
    GoRoute(
      path: Routes.deckHub,
      builder: (_, _) => const DeckHubPage(),
    ),
  ],
);
