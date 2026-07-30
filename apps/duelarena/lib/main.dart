import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'duel_page.dart';
import 'models/duel_state.dart';

void main() {
  Animate.restartOnHotReload = true;
  runApp(const DuelArenaApp());
}

class DuelArenaApp extends StatelessWidget {
  const DuelArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DuelState()..loadDemoState(),
      child: MaterialApp(
        title: 'Duel Arena',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const DuelPage(),
      ),
    );
  }
}
