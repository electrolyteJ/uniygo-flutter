import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/duel_state.dart';
import 'theme/duel_theme.dart';
import 'duel_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HoloDuelApp());
}

class HoloDuelApp extends StatelessWidget {
  const HoloDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DuelState(),
      child: MaterialApp(
        title: '决斗领域 · DUEL ARENA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: DuelTheme.void_,
          colorScheme: ColorScheme.fromSeed(
            seedColor: DuelTheme.gold,
            brightness: Brightness.dark,
          ),
        ),
        home: const DuelPage(),
      ),
    );
  }
}
