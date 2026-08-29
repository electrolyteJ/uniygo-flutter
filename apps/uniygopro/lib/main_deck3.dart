// 卡组中心（deck_editor3）调试入口：
//   flutter run -t lib/main_deck3.dart
import 'package:account_mycard/account_mycard.dart';
import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:deck_editor3/deck_editor3.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:ygo_settings/ygo_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAllServices();
  registerAppLevelOverrides(ygoSettingsOverrides);
  CardImageLoader.I.urlResolver = (int code) =>
      ServiceSingleton.instance.dataService.getCardImageUrl(code);
  final prefs = await SharedPreferences.getInstance();
  final accountApi = MyCardAccountApi(
    persistedJson: prefs.getString('mycard_account'),
  );
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: accountApi)],
      child: const _Deck3App(),
    ),
  );
}

class _Deck3App extends StatelessWidget {
  const _Deck3App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DeckHubPage(),
    );
  }
}
