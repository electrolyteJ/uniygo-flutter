import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniygopro/pages/create_room/match_page.dart';
import 'pages/home_page.dart';
import 'pages/duel_room_page.dart';
import 'pages/side_page.dart';
import 'pages/deck_editor_page.dart';

class UniygoproApp extends StatelessWidget {
  const UniygoproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'uniygopro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF546E7A),
          secondary: const Color(0xFFFFB300),
          surface: const Color(0xFF2A3A4A),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E2A38),
        cardColor: const Color(0xFF2A3A4A),
        dividerColor: const Color(0xFF455A64),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/match', builder: (_, _) => const MatchPage()),
    GoRoute(path: '/duel-room', builder: (_, _) => const DuelRoomPage()),
    GoRoute(path: '/side', builder: (_, _) => const SidePage()),
    GoRoute(
        path: '/deck-editor', builder: (_, _) => const DeckEditorPage()),
  ],
);
