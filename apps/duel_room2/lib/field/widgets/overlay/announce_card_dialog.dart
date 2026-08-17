import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:ygo_data/ygo_data.dart' as pkg;

import 'package:biz/widgets/card_image.dart';


@Preview(name: 'AnnounceCardDialog', size: Size(600, 500), brightness: Brightness.dark)
Widget previewAnnounceCardDialog() => AnnounceCardDialog(
      onSearch: (_) async => const [],
      onSelect: (_) {},
    );

class AnnounceCardDialog extends StatefulWidget {
  final Future<List<pkg.CardInfo>> Function(String query) onSearch;
  final void Function(int code) onSelect;
  final void Function(int code)? onInspectCard;

  /// 受限宣言（如抹杀之指名者）时可宣言的卡码集合；null 表示自由宣言。
  final Set<int>? declarableCodes;

  /// 加载 [declarableCodes] 对应的卡片信息；受限宣言时调用。
  final Future<List<pkg.CardInfo>> Function()? onLoadDeclarable;

  const AnnounceCardDialog({
    super.key,
    required this.onSearch,
    required this.onSelect,
    this.onInspectCard,
    this.declarableCodes,
    this.onLoadDeclarable,
  });

  @override
  State<AnnounceCardDialog> createState() => _AnnounceCardDialogState();
}

class _AnnounceCardDialogState extends State<AnnounceCardDialog> {
  final TextEditingController _controller = TextEditingController();
  List<pkg.CardInfo> _results = const <pkg.CardInfo>[];
  List<pkg.CardInfo> _declarableCards = const <pkg.CardInfo>[];
  bool _isSearching = false;
  bool _loadingDeclarable = false;
  String _activeQuery = '';
  int _searchToken = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final codes = widget.declarableCodes;
    if (codes != null && codes.isNotEmpty) {
      // 受限宣言：打开即加载可宣言卡列表（build 前直接置位，避免 setState）。
      _loadingDeclarable = true;
      _loadDeclarable();
    }
  }

  Future<void> _loadDeclarable() async {
    final load = widget.onLoadDeclarable;
    if (load == null) {
      if (mounted) {
        setState(() => _loadingDeclarable = false);
      }
      return;
    }
    List<pkg.CardInfo> cards;
    try {
      cards = await load();
    } catch (_) {
      cards = const <pkg.CardInfo>[];
    }
    if (!mounted) return;
    setState(() {
      _loadingDeclarable = false;
      _declarableCards = cards;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    final token = ++_searchToken;
    setState(() {
      _activeQuery = query;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _results = const <pkg.CardInfo>[];
      }
    });
    if (query.isEmpty) {
      return;
    }
    final results = await widget.onSearch(query);
    if (!mounted || token != _searchToken) {
      return;
    }
    setState(() {
      _isSearching = false;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF09111A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x5500F0FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '宣言卡名',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.declarableCodes == null
                    ? '输入卡名关键字，然后从搜索结果中选择要宣言的卡片。'
                    : '从下方可宣言的卡片中选择，或输入关键字筛选。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9FB5C7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: widget.declarableCodes == null
                      ? '例如：电子龙、青眼、禁发令'
                      : '输入关键字筛选可宣言卡片',
                  hintStyle: const TextStyle(color: Color(0x668FA6BA)),
                  filled: true,
                  fillColor: const Color(0xFF111D2A),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF00F0FF),
                  ),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_controller.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  // 先取消挂起的搜索防抖，避免清空后
                                  // 旧查询的延迟搜索又被触发。
                                  _debounce?.cancel();
                                  _debounce = null;
                                  _controller.clear();
                                  _performSearch('');
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF8FA6BA),
                                ),
                              )),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_activeQuery.isEmpty) {
      // 受限宣言（如抹杀之指名者）：直接展示可宣言卡列表，无需搜索。
      if (_loadingDeclarable) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_declarableCards.isNotEmpty) {
        return _buildCardList(_declarableCards);
      }
      return Center(
        child: Text(
          widget.declarableCodes == null ? '请输入卡名开始搜索' : '没有可宣言的卡片',
          style: const TextStyle(
            color: Color(0xFF70859A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '没有可宣言的匹配卡片',
          style: TextStyle(
            color: Color(0xFF70859A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return _buildCardList(_results);
  }

  Widget _buildCardList(List<pkg.CardInfo> cards) {
    return ListView.separated(
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCardTile(cards[index]),
    );
  }

  Widget _buildCardTile(pkg.CardInfo card) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => widget.onSelect(card.code),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1822),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x2AFFFFFF)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => widget.onInspectCard?.call(card.code),
              child: CardImage(
                code: card.code,
                width: 74,
                height: 102,
                showCodeFallback: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.typeText,
                    style: const TextStyle(
                      color: Color(0xFF8FA6BA),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '宣言这张卡',
                    style: TextStyle(
                      color: const Color(
                        0xFF00F0FF,
                      ).withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
