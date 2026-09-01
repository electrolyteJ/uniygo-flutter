// debug 包默认入口：调试入口 Hub，列出各模块独立预览页。
//
// 也可直接指定入口运行（跳过 Hub）：
//   flutter run -t lib/main_duel1.dart        (duel_room1 2D 场地)
//   flutter run -t lib/main_preview3d.dart    (duel_room3 3D 场景)
//   flutter run -t lib/main_deck3.dart        (deck_editor3 卡组中心)
import 'package:account_mycard/account_mycard.dart';
import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/service_singleton.dart';
import 'package:debug/duel_1_preview_page.dart';
import 'package:debug/duel_3d_preview_page.dart';
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
      child: const _DebugApp(),
    ),
  );
}

class _DebugApp extends StatelessWidget {
  const _DebugApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DebugHubPage(),
    );
  }
}

/// 调试入口 Hub：列出各模块独立预览页。
class DebugHubPage extends StatelessWidget {
  const DebugHubPage({super.key});

  static final List<_HubEntry> _entries = [
    _HubEntry('duel_room1 · 2D 场地预览', () => const Duel1PreviewPage()),
    _HubEntry('duel_room3 · 3D 场景预览', () => const Duel3DPreviewPage()),
    _HubEntry('deck_editor3 · 卡组中心', () => const DeckHubPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        title: const Text('YGO Debug Hub'),
        backgroundColor: const Color(0xFF0C1220),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ListTile(
            tileColor: const Color(0xFF14203A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              entry.label,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => entry.builder()),
            ),
          );
        },
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry(this.label, this.builder);

  final String label;
  final Widget Function() builder;
}
