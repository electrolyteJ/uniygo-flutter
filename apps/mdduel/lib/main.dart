import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'duel_page.dart';
import 'models/duel_state.dart';
import 'theme/md_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  Animate.restartOnHotReload = true;
  runApp(const MdDuelApp());
}

class MdDuelApp extends StatelessWidget {
  const MdDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DuelState(),
      child: MaterialApp(
        title: 'Master Duel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: MdTheme.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: MdTheme.gold, brightness: Brightness.dark),
        ),
        home: const DuelPage(),
      ),
    );
  }
}
