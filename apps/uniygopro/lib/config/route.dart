import 'package:cardlive/cardlive.dart' show CardLivePage;
import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room3/duel_room_page.dart';
import 'package:debug/duel_3d_preview_page.dart';
import 'package:debug/duel_1_preview_page.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/splash_page.dart';
import '../pages/create_room/match_page.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:deck_editor3/deck_editor3.dart';
import 'package:ygo_settings/ygo_settings.dart';
import '../layout/app_layout.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const duelRoom = '/duel-room';
  static const duelRoomPreview = '/duel-room-preview';
  static const duelRoom3Preview = '/duel-room3-preview';
  static const deckHub = '/deck-hub';
  static const deckEditor = '/deck-editor';
}


/// 启动时恢复偏好（main.dart 初始化期调用）。
Future<void> restore() => DuelRoomRendererPreference.restore();

bool get _is3D => DuelRoomRendererPreference.current.value == DuelRoomRenderer.room3d;
final router = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(
      path: Routes.login,
      builder: (_, state) {
        final extra = state.extra;
        final map = extra is Map<String, Object?> ? extra : const {};
        return LoginPage(
          from: map['from'] as String?,
          reason: map['reason'] as String?,
        );
      },
    ),
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: '/match', builder: (_, _) => const MatchPage()),
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
    GoRoute(path: '/card-live', builder: (_, _) => const CardLivePage()),
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
      // 栏数按应用级档位注入，与大厅「卡组 → 组卡器」保持同一套约定
      // （compact 1 / regular 2 / wide 3）。此前传 null 让 deck_editor1 按
      // 可用宽度自行推导（>=600 即三栏），640×360 横屏会被判成三栏桌面
      // 布局，DeckEditPanel 直接溢出 463px。
      builder: (context, state) => DeckEditorPage(
        columns: AppLayout.of(context).contentColumns,
        args: state.extra is Map<String, Object?>
            ? state.extra as Map<String, Object?>
            : null,
      ),
    ),
    GoRoute(
      path: Routes.deckHub,
      // 与大厅「卡组」Tab 共用 deck_editor3.DeckHubPage 这一份实现：
      // 此处为非内嵌形态（自带 Scaffold + AppBar），仅注入档位与组卡器。
      builder: (context, _) {
        final spec = AppLayout.of(context);
        return DeckHubPage(
          pagePadding: spec.pagePadding,
          editorBuilder: (_) =>
              DeckEditorPage(embedded: true, columns: spec.contentColumns),
        );
      },
    ),
  ],
);
