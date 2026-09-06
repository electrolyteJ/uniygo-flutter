import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';

import 'package:uniygopro/config/route.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:duel_room1/l10n/app_localizations.dart';

/// 全局统一等比缩放的基准设计分辨率（逻辑像素）。
///
/// 整棵 widget 树（含 Portal 弹层、Navigator 路由、Flame 场地）都按这个
/// 尺寸布局，再由 [_ScaledApp] 的 FittedBox 等比缩放到实际窗口。这是唯一
/// 的屏幕适配入口（hudScale / compact / ScreenUtilInit 均已移除）。
const Size kAppDesignSize = Size(1280, 800);

class UniygoproApp extends StatelessWidget {
  const UniygoproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaledApp(
      child: Portal(
        child: MaterialApp.router(
          // 在 Navigator 之上（WidgetsApp 的 MediaQuery 之下）覆盖 MediaQuery：
          // 让依赖 MediaQuery.size 的页面读到设计分辨率，而不是实际窗口。
          builder: (context, child) => _DesignMediaQuery(child: child!),
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
      ),
    );
  }
}

/// 全局等比缩放容器：把 [Portal]（含其 PortalTheater 弹层）和 MaterialApp
/// 整棵树按 [kAppDesignSize] 布局，再等比缩放到实际窗口。
class _ScaledApp extends StatelessWidget {
  const _ScaledApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.center,
      child: SizedBox(
        width: kAppDesignSize.width,
        height: kAppDesignSize.height,
        child: child,
      ),
    );
  }
}

/// 把 MediaQuery 覆盖为设计分辨率：只在 MaterialApp.builder 里（Navigator 之上、
/// WidgetsApp 自建的 MediaQuery 之下）生效，路由页面的
/// MediaQuery.size / viewPadding 都按设计尺寸返回。
class _DesignMediaQuery extends StatelessWidget {
  const _DesignMediaQuery({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: kAppDesignSize,
        // 设计分辨率内不含设备安全区（刘海/状态栏），页面自行处理留白。
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: child,
    );
  }
}
