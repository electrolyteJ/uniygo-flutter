import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ygo_card/card_info.dart';
import '../../models/deck_model.dart';
import '../../stores/deck_editor_store.dart';
import 'deck_zone_widget.dart';

class DeckEditPanel extends StatefulWidget {
  const DeckEditPanel({super.key});

  @override
  State<DeckEditPanel> createState() => _DeckEditPanelState();
}

class _DeckEditPanelState extends State<DeckEditPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── 撤销/重做历史 ──
  final List<_DeckSnapshot> _undoStack = [];
  final List<_DeckSnapshot> _redoStack = [];
  static const int _maxHistory = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _pushSnapshot() {
    final deck = context.read<DeckEditorStore>().editingDeck;
    _undoStack.add(_DeckSnapshot.fromDeck(deck));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeckEditorStore>();
    final deck = store.editingDeck;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A3A4A),
        border: Border(
          left: BorderSide(color: Color(0xFF455A64)),
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(deck),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                DeckZoneWidget(type: DeckZoneType.main),
                DeckZoneWidget(type: DeckZoneType.extra),
                DeckZoneWidget(type: DeckZoneType.side),
              ],
            ),
          ),
          _buildActionBar(store, deck),
        ],
      ),
    );
  }

  Widget _buildTabBar(EditingDeck deck) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF455A64)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: '主卡组 (${deck.mainCount})'),
          Tab(text: '额外 (${deck.extraCount})'),
          Tab(text: '备牌 (${deck.sideCount})'),
        ],
        labelColor: const Color(0xFFFFB300),
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        indicatorColor: const Color(0xFFFFB300),
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  Widget _buildActionBar(DeckEditorStore store, EditingDeck deck) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF455A64)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DeckAction(
            icon: Icons.shuffle,
            label: '洗切',
            onTap: deck.totalCount > 0 ? () => store.shuffleDeck() : null,
          ),
          _DeckAction(
            icon: Icons.sort_by_alpha,
            label: '排序',
            onTap: deck.totalCount > 0 ? () => store.sortDeck() : null,
          ),
          _DeckAction(
            icon: Icons.delete_outline,
            label: '清空',
            onTap: deck.totalCount > 0 ? () => _confirmClear(store) : null,
          ),
        ],
      ),
    );
  }

  void _confirmClear(DeckEditorStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空卡组'),
        content: const Text('确定要清空所有卡牌吗？此操作可以撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _pushSnapshot();
              store.clearDeck();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

// ── 底部操作按钮 ──
class _DeckAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DeckAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap != null
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onTap != null
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckSnapshot {
  final String deckName;
  final List<CardInfo> main;
  final List<CardInfo> extra;
  final List<CardInfo> side;

  _DeckSnapshot({
    required this.deckName,
    required this.main,
    required this.extra,
    required this.side,
  });

  factory _DeckSnapshot.fromDeck(EditingDeck deck) {
    return _DeckSnapshot(
      deckName: deck.deckName,
      main: List.of(deck.main),
      extra: List.of(deck.extra),
      side: List.of(deck.side),
    );
  }
}
