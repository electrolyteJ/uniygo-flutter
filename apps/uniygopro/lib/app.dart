import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';

import 'package:uniygopro/config/route.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:duel_room1/l10n/app_localizations.dart';
import 'package:uniygopro/layout/app_layout.dart';

class UniygoproApp extends StatelessWidget {
  const UniygoproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: MaterialApp.router(
        // 在 Navigator 之上（WidgetsApp 的 MediaQuery 之下）注入应用级布局规格。
        // 不修改 MediaQuery：页面内的断点判断必须基于真实视口，
        // 多端自适应（移动横屏 / 桌面宽屏）都由此派生。
        builder: (context, child) => AppLayoutScope(child: child!),
        title: 'uniygopro',
        localizationsDelegates: [
          AppLocalizations.delegate, // Add this line
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'), // English
          Locale('es'), // Spanish
        ],
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
        routerConfig: router,
      ),
    );
  }
}
