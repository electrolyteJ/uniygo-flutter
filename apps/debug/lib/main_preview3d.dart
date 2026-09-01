// duel_room3 3D 场景预览独立入口：
//   flutter run -d macos --enable-flutter-gpu -t lib/main_preview3d.dart
import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:duel_room3/field/duel_3d_preview_page.dart';
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
      home: Duel3DPreviewPage(),
    );
  }
}
