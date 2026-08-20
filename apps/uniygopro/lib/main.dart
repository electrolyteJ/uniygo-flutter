import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/service_loader.registrations.g.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorStore;
import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:duel_settings/duel_settings.dart';
import 'app.dart';
import 'pages/side/side_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerAllServices();
  // 注入跨包设置实现（持久化 + 设置弹窗）到 biz 的 provider 契约；
  // 必须在首个 DuelRoomPage 构建（duelRoomServiceContainer 懒初始化）前注册。
  registerAppLevelOverrides(duelSettingsOverrides);

  // 注入统一图片加载器的 URL 解析器
  CardImageLoader.I.urlResolver = (int code) =>
      ServiceSingleton.instance.dataService.getCardImageUrl(code);

  runApp(
    MultiProvider(
      // duel_room1 的房间/对局/聊天状态已迁移到 biz/duel 的 Riverpod
      // Provider：DuelRoomPage 每次进房自建 ProviderScope（parent 为
      // duelRoomServiceContainer），宿主无需装配任何房间级 Provider。
      providers: [
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider(create: (_) => SideStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}
