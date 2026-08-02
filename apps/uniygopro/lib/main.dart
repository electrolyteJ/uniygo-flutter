import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/service_loader.registrations.g.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:uniygopro/stores/duel_board_store.dart';
import 'package:uniygopro/stores/duel_chat_store.dart';
import 'package:uniygopro/stores/waiting_room_store.dart';
import 'package:uniygopro/stores/deck_editor_store.dart';
import 'package:uniygopro/stores/duel_selection_store.dart';
import 'package:uniygopro/stores/duel_room_state.dart';
import 'package:uniygopro/stores/duel_ui_store.dart';
import 'app.dart';
import 'stores/match_store.dart';
import 'stores/side_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerAllServices();
  ServiceSingleton.instance.registerService();
  final boardStore = DuelBoardStore();
  final selectionStore = DuelSelectionStore();
  final uiStore = DuelUiStore();
  final chatStore = DuelChatStore();
  final duelRoomState = DuelRoomState();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider.value(value: duelRoomState),
        ChangeNotifierProvider.value(value: WaitingRoomStore()),
        ChangeNotifierProvider.value(value: boardStore),
        ChangeNotifierProvider.value(value: selectionStore),
        ChangeNotifierProvider.value(value: uiStore),
        ChangeNotifierProvider.value(value: chatStore),
        ChangeNotifierProvider(create: (_) => SideStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}
