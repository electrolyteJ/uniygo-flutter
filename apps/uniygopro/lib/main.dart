import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duelink/duelink.dart';
import 'package:uniygopro/pages/duel_room/duel/duel_field_store.dart';
import 'package:uniygopro/pages/duel_room/duel_room_store.dart';
import 'package:uniygopro/service_loader.registrations.g.dart';
import 'package:uniygopro/pages/duel_room/waiting/duel_chat_store.dart';
import 'package:uniygopro/pages/deck_editor/deck_editor_store.dart';
import 'app.dart';
import 'pages/create_room/match_store.dart';
import 'pages/side/side_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerAllServices();
  final duelStore = DuelFieldStore();
  final chatStore = DuelChatStore();
  final duelRoomStore = DuelRoomStore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider.value(value: duelRoomStore),
        ChangeNotifierProvider.value(value: duelStore),
        ChangeNotifierProvider.value(value: chatStore),
        ChangeNotifierProvider(create: (_) => SideStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}