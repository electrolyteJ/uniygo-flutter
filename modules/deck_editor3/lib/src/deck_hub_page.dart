import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deck_square/deck_square_page.dart';
import 'my_decks/my_decks_controller.dart';
import 'my_decks/my_decks_page.dart';

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

class _DeckHubView extends ConsumerStatefulWidget {
  const _DeckHubView();

  @override
  ConsumerState<_DeckHubView> createState() => _DeckHubViewState();
}

class _DeckHubViewState extends ConsumerState<_DeckHubView> {
  int _tab = 0;

  void _selectTab(int i) {
    setState(() => _tab = i);
    // 切到「我的卡组」时刷新列表，确保刚使用/新建/导入的卡组立即显示。
    if (i == 1) {
      ref.read(myDecksControllerProvider.notifier).refresh();
    }
  }

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
        onDestinationSelected: _selectTab,
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
