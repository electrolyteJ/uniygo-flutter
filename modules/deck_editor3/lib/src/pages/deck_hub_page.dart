import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deck_square_page.dart';
import 'my_decks_page.dart';

/// 卡组中心壳页：市场 / 我的卡组 两个分区。
///
/// 自带独立 [ProviderScope]，模块状态与宿主隔离（同 duel_room3 房间模式）。
class DeckHubPage extends StatelessWidget {
  const DeckHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _DeckHubView());
  }
}

class _DeckHubView extends StatefulWidget {
  const _DeckHubView();

  @override
  State<_DeckHubView> createState() => _DeckHubViewState();
}

class _DeckHubViewState extends State<_DeckHubView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        title: const Text('卡组中心'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          DeckSquarePage(),
          MyDecksPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0E1626),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '卡组市场',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_special_outlined),
            selectedIcon: Icon(Icons.folder_special),
            label: '我的卡组',
          ),
        ],
      ),
    );
  }
}
