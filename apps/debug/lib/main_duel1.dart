// duel_room1 2D 场地预览独立入口：
//   flutter run -t lib/main_duel1.dart
import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:debug/duel_1_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:ygo_settings/ygo_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerAllServices();
  registerAppLevelOverrides(ygoSettingsOverrides);
  CardImageLoader.I.urlResolver = (int code) =>
      ServiceSingleton.instance.dataService.getCardImageUrl(code);
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Duel1PreviewPage(),
    );
  }
}
