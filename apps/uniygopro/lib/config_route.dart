import 'package:go_router/go_router.dart';
import 'package:uniygopro/pages/duel_room/duel_room_page.dart';
import 'pages/home_page.dart';
import 'pages/create_room/match_page.dart';
import 'pages/side/side_page.dart';
import 'pages/deck_editor/deck_editor_page.dart';
import 'pages/deck_editor/deck_editor_session.dart';

abstract final class Routes {
  static const home = '/';
}

final router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: '/match', builder: (_, _) => const MatchPage()),
    GoRoute(path: '/duel-room', builder: (_, _) => const DuelRoomPage()),
    GoRoute(path: '/side', builder: (_, _) => const SidePage()),
    GoRoute(
      path: '/deck-editor',
      builder: (_, state) => DeckEditorPage(
        args: state.extra is DeckEditorRouteArgs
            ? state.extra as DeckEditorRouteArgs
            : null,
      ),
    ),
  ],
);
