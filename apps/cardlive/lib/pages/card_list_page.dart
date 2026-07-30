import 'package:flutter/material.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card/card_info.dart';
import 'package:ygo_card/lflist_info.dart';
import 'package:ygo_card/ygo_card.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import '../service/script_service.dart';
import '../summon/summon_inline.dart';
import '../widgets/card_animation.dart';
import '../widgets/card_detail.dart';

class CardListPage extends StatefulWidget {
  const CardListPage({super.key});

  @override
  State<CardListPage> createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  final TextEditingController _searchController = TextEditingController();

  final ICardService _cardService = createCardService(ServiceType.card_mycard);
  final ScriptService _scriptService = ScriptService();

  List<CardInfo> _cards = [];
  final Map<int, List<EffectType>> _cardEffects = {};
  CardInfo? _selectedCard;
  bool _isLoading = true;
  String _errorMessage = '';
  LflistInfo? _lflist;
  CardInfo? _summoningCard;
  bool _showInlineSummon = false;
  @override
  void initState() {
    super.initState();
    _initData();
  }



  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      _lflist = await _cardService.fetchLflist();
      await _scriptService.init();
      _cards = await _cardService.searchCards('');
      await _preloadEffects();
    } catch (e) {
      setState(() {
        _errorMessage = '加载卡片数据失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchCards(String keyword) async {
    setState(() {
      _isLoading = true;
    });

    try {
      _cards = await _cardService.searchCards(keyword);
      await _preloadEffects();
    } catch (e) {
      setState(() {
        _errorMessage = '搜索失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadEffects() async {
    _cardEffects.clear();
    for (final card in _cards) {
      try {
        final effects = await _scriptService.getEffects(card.code);
        if (effects.isNotEmpty) {
          _cardEffects[card.code] = effects;
        }
      } catch (_) {}
    }
    setState(() {});
  }

  void _switchEnvironment(EnvType type) {
    _cardService.envType = type;
    _cardEffects.clear();
    _initData();
  }

  void _showCardDetail(CardInfo card) {
    setState(() {
      _selectedCard = card;
    });
  }

  void _triggerInlineSummon(CardInfo card) {
    setState(() {
      _summoningCard = card;
      _showInlineSummon = true;
    });
  }

  void _onInlineComplete() {
    setState(() {
      _showInlineSummon = false;
      _summoningCard = null;
    });
  }

  void _closeCardDetail() {
    setState(() {
      _selectedCard = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏王卡片动效展示'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          _buildMainContent(),
          if (_selectedCard != null) _buildCardDetailOverlay(),
          if (_showInlineSummon && _summoningCard != null)
            Positioned.fill(
              child: SummonInline(
                card: _summoningCard!,
                imageUrl: _cardService.getCardImageUrl(_summoningCard!.code),
                onComplete: _onInlineComplete,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildEnvironmentSelector(),
        Expanded(
          child: _isLoading
              ? _buildLoading()
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _buildCardGrid(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索卡片名称或效果...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[800],
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
          _searchCards(value);
        },
      ),
    );
  }

  Widget _buildEnvironmentSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('环境:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 12),
          _buildEnvChip(EnvType.production, '正式'),
          const SizedBox(width: 8),
          _buildEnvChip(EnvType.staging, '预发'),
          const SizedBox(width: 8),
          _buildEnvChip(EnvType.env408, '408'),
        ],
      ),
    );
  }

  Widget _buildEnvChip(EnvType type, String label) {
    final isSelected = _cardService.envType == type;
    return ActionChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
      backgroundColor: isSelected ? Colors.deepPurple : Colors.grey[300],
      onPressed: () {
        _switchEnvironment(type);
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.deepPurple),
          SizedBox(height: 16),
          Text('加载卡片数据中...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initData,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final cardWidth = 160.0;
        final spacing = 8.0;
        final crossAxisCount = maxWidth > 800 
            ? maxWidth > 1200 
                ? 6 
                : 4 
            : maxWidth > 600 
                ? 3 
                : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.72,
          ),
          itemCount: _cards.length,
          itemBuilder: (context, index) {
            final card = _cards[index];
            final imageUrl = _cardService.getCardImageUrl(card.code);
            final effects = _cardEffects[card.code];
            return CardAnimation(
              card: card,
              imageUrl: imageUrl,
              width: cardWidth,
              height: cardWidth / 0.72,
              effects: effects,
              onTap: () => _triggerInlineSummon(card),
            );
          },
        );
      },
    );
  }

  Widget _buildCardDetailOverlay() {
    if (_selectedCard == null) return const SizedBox.shrink();
    return CardDetail(
      card: _selectedCard!,
      imageUrl: _cardService.getCardImageUrl(_selectedCard!.code),

      limitText: _lflist?.getLimitText(_selectedCard!.code) ?? '无限制',
      effects: _cardEffects[_selectedCard!.code],
      onClose: _closeCardDetail,
    );
  }
}