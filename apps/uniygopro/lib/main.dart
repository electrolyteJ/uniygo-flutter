import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:uniygopro/stores/deck_editor_store.dart';
import 'package:uniygopro/stores/duel_room_state.dart';
import 'app.dart';
import 'stores/match_store.dart';
import 'stores/side_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ServiceSingleton.instance.registerService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider(create: (_) => DuelRoomState()),
        ChangeNotifierProvider(create: (_) => SideStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}
