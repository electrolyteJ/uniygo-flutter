import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/duel_state.dart';

Widget darkPreviewWrapper(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(child: child),
    ),
  );
}

Widget duelStatePreviewWrapper(Widget child) {
  final state = DuelState()..loadDemoState();
  return ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: child,
      ),
    ),
  );
}
