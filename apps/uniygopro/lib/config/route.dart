import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room3/duel_room_page.dart';
import 'package:debug/duel_3d_preview_page.dart';
import 'package:debug/duel_1_preview_page.dart';
import 'package:go_router/go_router.dart';

import 'package:ygo_settings/system_ui.dart';
import '../home/home_page.dart';
import '../create_room/create_room_page.dart';
import '../login/login_page.dart';
import '../splash/splash_page.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:deck_editor3/deck_editor3.dart';
import 'package:ygo_settings/ygo_settings.dart';

abstract final class Routes {
  /// 开屏（启动入口）。
  static const splash = '/splash';

  /// 登录（MyCard 账号密码 / 游客分流）。
  static const login = '/login';

  /// 主页（登录后的主入口）。
  static const home = '/home';

  /// 建房（匹配 / 好友对战 / 练习 / 自由房间）。
  static const createRoom = '/create-room';
  static const duelRoom = '/duel-room';
  static const duelRoomPreview = '/duel-room-preview';
  static const duelRoom3Preview = '/duel-room3-preview';
  static const cardLive = '/card-live';
  static const deckHub = '/deck-hub';
  static const deckEditor = '/deck-editor';
}

/// 启动时恢复偏好（main.dart 初始化期调用）。
Future<void> restore() => DuelRoomRendererPreference.restore();

bool get _is3D =>
    DuelRoomRendererPreference.current.value == DuelRoomRenderer.room3d;
final router = GoRouter(
  initialLocation: Routes.splash,
  // 路由切换后重新压一遍沉浸式（Android 弹窗后会还回导航栏）。
  observers: [systemUiRouteObserver],
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
    // 根路径统一进入主页（主页自身用 /home，便于直接分享/深链）。
    GoRoute(path: '/', redirect: (_, _) => Routes.home),
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(
      path: Routes.createRoom,
      builder: (_, state) => CreateRoomPage(autoStart: state.extra == 'start'),
    ),
    GoRoute(
      path: Routes.duelRoom,
      redirect: (_, state) =>
          state.extra is Map<String, Object?> ? null : Routes.home,
      builder: (_, state) {
        if (_is3D) {
          return DuelRoomPage3D(args: state.extra! as Map<String, Object?>);
        } else {
          return DuelRoomPage(args: state.extra! as Map<String, Object?>);
        }
      },
    ),
    GoRoute(path: Routes.cardLive, builder: (_, _) => const CardLivePage()),
    GoRoute(
      path: Routes.duelRoomPreview,
      builder: (_, _) => const Duel1PreviewPage(),
    ),
    GoRoute(
      path: Routes.duelRoom3Preview,
      builder: (_, _) => const Duel3DPreviewPage(),
    ),
    GoRoute(
      path: Routes.deckEditor,
      builder: (_, state) => DeckEditorPage(
        args: state.extra is Map<String, Object?>
            ? state.extra as Map<String, Object?>
            : null,
      ),
    ),
    GoRoute(path: Routes.deckHub, builder: (_, _) => const DeckHubPage()),
  ],
);
