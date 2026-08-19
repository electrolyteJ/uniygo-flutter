import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/duel_room_page.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/create_room/match_page.dart';
import 'pages/side/side_page.dart';
import 'pages/deck_editor/deck_editor_page.dart';

abstract final class Routes {
  static const home = '/';
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
    GoRoute(
      path: '/duel-result',
      builder: (_, state) =>
          DuelResultPage(result: state.extra! as Map<String, Object?>),
    ),
    GoRoute(path: '/side', builder: (_, _) => const SidePage()),
    GoRoute(path: '/card-live', builder: (_, _) => const CardLivePage()),
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
