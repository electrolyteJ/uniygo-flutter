import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:account_mycard/account_mycard.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorStore;
import 'package:biz/card_image_loader.dart';
import 'package:biz/crash_log.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:biz/util/orientation_lock.dart';
import 'package:ygo_settings/ygo_settings.dart';
import 'app.dart';
import 'config/route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [临时诊断] 全局崩溃捕获落盘（logs/flutter_crash.log），
  // 定位进决斗房间时导航器断言吞掉的原始异常，修复后移除。
  installCrashLogHook();

  // 全应用横屏（仅 Android/iOS 生效；决斗房间同样横屏，无需单独锁）。
  lockAppLandscape();

  registerAllServices();
  // 注入跨包设置实现（持久化 + 设置弹窗）到 biz 的 provider 契约；
  // 必须在首个 DuelRoomPage 构建（duelRoomServiceContainer 懒初始化）前注册。
  registerAppLevelOverrides(ygoSettingsOverrides);

  // 注入统一图片加载器的 URL 解析器
  CardImageLoader.I.urlResolver = (int code) =>
      ServiceSingleton.instance.dataService.getCardImageUrl(code);

  // MyCard 账号体系（统一接口）：启动时读持久化，登录态变化时回写。
  final prefs = await SharedPreferences.getInstance();
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountApi),
        ChangeNotifierProvider(create: (_) => MatchStore()),
        ChangeNotifierProvider(create: (_) => DeckEditorStore()),
      ],
      child: const UniygoproApp(),
    ),
  );
}
