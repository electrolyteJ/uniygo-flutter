import 'package:duel_room1/pages/duel_room/duel_field_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duel_room1/pages/duel_room/duel_room_store.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/service_loader.registrations.g.dart';
import 'package:duel_room1/pages/duel_room/duel_chat_store.dart';
import 'package:uniygopro/pages/deck_editor/deck_editor_store.dart';
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
  final duelStore = DuelFieldStore();
  final chatStore = DuelChatStore();
  final duelRoomStore = DuelRoomStore();

  // 注入统一图片加载器的 URL 解析器
  CardImageLoader.I.urlResolver = (int code) =>
      ServiceSingleton.instance.dataService.getCardImageUrl(code);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider.value(value: duelRoomStore),
        ChangeNotifierProvider.value(value: duelStore),
        ChangeNotifierProvider.value(value: chatStore),
        ChangeNotifierProvider(create: (_) => SideStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}
