import 'package:biz/service_singleton.dart';
import 'package:biz/widgets/card_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';
import 'package:resource_deck_mdpro3/services/deck_api_client.dart';

import '../my_decks/my_decks_controller.dart';
import '../widgets/deck_zone_grid.dart';

/// 市场卡组详情页：构成展示 + 统计 + 点赞 + 复制到我的卡组 + YDK 导出。
class DeckDetailPage extends ConsumerStatefulWidget {
  const DeckDetailPage({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> {
  final _api = DeckApiClient();
  MdPro3DeckInfo? _deck;
  String? _error;
  bool _liked = false;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deck = await _api.fetchDeckDetail(widget.deckId);
      // 预热卡信息（名称/统计）
      final codes = [
        ...deck.mainDeck.map((c) => c.code),
        ...deck.extraDeck.map((c) => c.code),
        ...deck.sideDeck.map((c) => c.code),
      ];
      final data = ServiceSingleton.instance.dataService;
      for (final code in codes.toSet()) {
        // 后台加载，不阻塞
        // ignore: unawaited_futures
        data.getCard(code);
      }
      if (mounted) setState(() => _deck = deck);
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        title: Text(deck?.name ?? '卡组详情'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: Colors.white,
        actions: [
          if (deck != null) ...[
            IconButton(
              tooltip: '点赞',
              icon: Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFFF5A5A),
              ),
              onPressed: _like,
            ),
            IconButton(
              tooltip: '导出 YDK',
              icon: const Icon(Icons.ios_share),
              onPressed: _exportYdk,
            ),
          ],
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
          : deck == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(deck),
      floatingActionButton: deck == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1B7FA8),
              onPressed: _copying ? null : _useDeck,
              icon: _copying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_copying ? '使用中…' : '使用该卡组'),
            ),
    );
  }

  Widget _buildBody(MdPro3DeckInfo deck) {
    final stats = _computeStats(deck);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 头部信息
        Row(
          children: [
            const Icon(Icons.person, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(deck.contributor,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.favorite, size: 14, color: Color(0xFFFF5A5A)),
            const SizedBox(width: 4),
            Text('${deck.likeCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (deck.rank > 0) ...[
              const SizedBox(width: 12),
              const Icon(Icons.emoji_events,
                  size: 14, color: Color(0xFFFFD75A)),
              const SizedBox(width: 4),
              Text('天梯 #${deck.rank}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // 统计条
        _StatsBar(stats: stats),
        const Divider(color: Color(0xFF1E3A55), height: 24),
        DeckZoneGrid(
          title: '主卡组',
          cards: deck.mainDeck,
          accent: const Color(0xFF37E2FF),
          onCardTap: _showCardInfo,
          cardWidth: 100,
          cardHeight: 146,
        ),
        DeckZoneGrid(
          title: '额外卡组',
          cards: deck.extraDeck,
          accent: const Color(0xFFB45AFF),
          onCardTap: _showCardInfo,
          cardWidth: 100,
          cardHeight: 146,
        ),
        DeckZoneGrid(
          title: '副卡组',
          cards: deck.sideDeck,
          accent: const Color(0xFFFFD75A),
          onCardTap: _showCardInfo,
          cardWidth: 100,
          cardHeight: 146,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  ({int monster, int spell, int trap}) _computeStats(MdPro3DeckInfo deck) {
    var monster = 0, spell = 0, trap = 0;
    final data = ServiceSingleton.instance.dataService;
    for (final c in deck.mainDeck) {
      final CardInfo? info = data.getCardCached(c.code);
      if (info == null) continue;
      if (info.isSpell) {
        spell += c.count;
      } else if (info.isTrap) {
        trap += c.count;
      } else {
        monster += c.count;
      }
    }
    return (monster: monster, spell: spell, trap: trap);
  }

  void _showCardInfo(int code) {
    final data = ServiceSingleton.instance.dataService;
    final info = data.getCardCached(code);
    if (info == null) return;
    CardDetailDialog.show(
      context,
      card: info,
      showAddButton: false,
      imageUrl: data.getCardImageUrl(code),
    );
  }

  Future<void> _like() async {
    final deck = _deck;
    if (deck == null || _liked) return;
    try {
      await _api.likeDeck(deck.deckId);
      setState(() => _liked = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已点赞')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败：$e')),
        );
      }
    }
  }

  /// 使用该卡组：复制到本地，成为「我的卡组」里的自建卡组。
  Future<void> _useDeck() async {
    final deck = _deck;
    if (deck == null) return;
    setState(() => _copying = true);
    try {
      final local = DeckInfo(
        deckName: deck.name,
        mainDeck: deck.mainDeck,
        extraDeck: deck.extraDeck,
        sideDeck: deck.sideDeck,
      );
      final ok = await ref
          .read(myDecksControllerProvider.notifier)
          .copyToLocal(local, rename: deck.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已加入我的卡组' : '加入失败')),
      );
      if (ok) {
        Navigator.of(context).pop();
      } else {
        setState(() => _copying = false);
      }
    } catch (_) {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _exportYdk() async {
    final deck = _deck;
    if (deck == null) return;
    final ydk = ServiceSingleton.instance.dataService.exportToYdk(DeckInfo(
      deckName: deck.name,
      mainDeck: deck.mainDeck,
      extraDeck: deck.extraDeck,
      sideDeck: deck.sideDeck,
    ));
    await Clipboard.setData(ClipboardData(text: ydk));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YDK 已复制到剪贴板')),
      );
    }
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final ({int monster, int spell, int trap}) stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.monster + stats.spell + stats.trap;
    if (total == 0) return const SizedBox.shrink();
    return Row(
      children: [
        _chip('怪兽 ${stats.monster}', const Color(0xFF37E2FF)),
        const SizedBox(width: 8),
        _chip('魔法 ${stats.spell}', const Color(0xFF7CFF6B)),
        const SizedBox(width: 8),
        _chip('陷阱 ${stats.trap}', const Color(0xFFFF8C42)),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
