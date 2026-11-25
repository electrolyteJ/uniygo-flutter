import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/card_image_loader.dart';
import 'package:biz/crash_log.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:biz/util/orientation_lock.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorStore;
import 'package:duel_room1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/config/route.dart';
import 'package:ygo_settings/system_ui.dart';
import 'package:ygo_settings/ygo_settings.dart';

/// 全局统一等比缩放的基准设计分辨率（逻辑像素）。
///
/// 整棵 widget 树（含 Portal 弹层、Navigator 路由、Flame 场地）都按这个
/// 尺寸布局，再由 [_ScaledApp] 的 FittedBox 等比缩放到实际窗口。这是唯一
/// 的屏幕适配入口（hudScale / compact / ScreenUtilInit 均已移除）。
const Size kAppDesignSize = Size(1280, 800);

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  MyCardAccountApi? _accountApi;
  Object? _bootError;
  bool _ready = false;
  bool _servicesRegistered = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _accountApi?.dispose();
    super.dispose();
  }

  /// 启动期异步初始化（原 main.dart 内容）。
  ///
  /// 在首帧前完成服务注册/账号恢复等，界面期间显示深色启动占位，
  /// 避免在依赖（SharedPreferences / ServiceSingleton）就绪前构建路由。
  Future<void> _bootstrap() async {
    try {
      await restore();
      if (!_servicesRegistered) {
        // [临时诊断] 全局崩溃捕获落盘（logs/flutter_crash.log），
        // 定位进决斗房间时导航器断言吞掉的原始异常，修复后移除。
        installCrashLogHook();

        // 全应用横屏（仅 Android/iOS 生效；决斗房间同样横屏，无需单独锁）。
        lockAppLandscape();

        // 进游戏即沉浸式：隐藏状态栏 / 导航栏（设置页可关闭，见 system_ui）。
        await applyStartupSystemUi();

        registerAllServices();
        // 注入跨包设置实现（持久化 + 设置弹窗）到 biz 的 provider 契约；
        // 必须在首个 DuelRoomPage 构建（duelRoomServiceContainer 懒初始化）前注册。
        registerAppLevelOverrides(ygoSettingsOverrides);
        _servicesRegistered = true;
      }

      // 注入统一图片加载器的 URL 解析器
      CardImageLoader.I.urlResolver = (int code) =>
          ServiceSingleton.instance.dataService.getCardImageUrl(code);

      // 音效总开关：启动时应用持久化偏好（设置弹窗写入同一键）。
      final prefs = await SharedPreferences.getInstance();
      YgoSoundService.enabled =
          prefs.getBool('home_settings.sound_enabled') ??
          YgoSoundService.enabled;
      const accountKey = 'mycard_account';
      final accountApi = MyCardAccountApi(
        persistedJson: prefs.getString(accountKey),
      );
      accountApi.addListener(() {
        final json = accountApi.toPersistedJson();
        if (json == null) {
          prefs.remove(accountKey);
        } else {
          prefs.setString(accountKey, json);
        }
      });

      if (!mounted) {
        accountApi.dispose();
        return;
      }
      setState(() {
        _accountApi = accountApi;
        _ready = true;
      });
    } catch (error, stack) {
      debugPrint('App bootstrap failed: $error\n$stack');
      if (mounted) {
        setState(() => _bootError = error);
      }
    }
  }

  void _retry() {
    setState(() => _bootError = null);
    unawaited(_bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    if (_bootError != null) {
      return _BootErrorScreen(error: _bootError!, onRetry: _retry);
    }
    final accountApi = _accountApi;
    if (!_ready || accountApi == null) {
      return const _BootScreen();
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountApi),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: _SystemUiKeeper(
        child: _ScaledApp(
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
        ),
      ),
    );
  }
}

/// 启动占位：深色底 + 细进度圈，避免 init 期间白屏。
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF05070F),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF37E2FF),
          ),
        ),
      ),
    );
  }
}

/// 初始化失败：给出错误信息并可重试（例如本地存储异常）。
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF05070F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '启动失败',
                style: TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8A93A8), fontSize: 12),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回到前台时重新进入沉浸式（系统会在输入法/切后台后把系统栏还回来）。
class _SystemUiKeeper extends StatefulWidget {
  const _SystemUiKeeper({required this.child});

  final Widget child;

  @override
  State<_SystemUiKeeper> createState() => _SystemUiKeeperState();
}

class _SystemUiKeeperState extends State<_SystemUiKeeper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(reapplyPersistedSystemUi());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(reapplyPersistedSystemUi());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
