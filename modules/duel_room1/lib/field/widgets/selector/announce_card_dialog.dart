import 'dart:async';

import 'package:flutter/material.dart';
import 'package:resource_data/ygo_data.dart' as pkg;

import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

/// 宣言卡名弹窗。
///
/// 两种形态：
/// - **受限宣言**（[declarableCodes] 非 null，如抹杀之指名者）：引擎给定可宣言
///   卡列表，打开即加载并**直接罗列候选卡**供点选，不提供搜索；
/// - **自由宣言**（[declarableCodes] 为 null）：可宣言任意卡名，无有限列表，
///   提供搜索框按关键字检索。
class AnnounceCardDialog extends StatefulWidget {
  final int generation;
  final Future<List<pkg.CardInfo>> Function(String query) onSearch;
  final void Function(int code) onSelect;
  final void Function(int code)? onInspectCard;

  /// 受限宣言时可宣言的卡码集合；null 表示自由宣言。
  final Set<int>? declarableCodes;

  /// 加载 [declarableCodes] 对应的卡片信息；受限宣言时调用。
  final Future<List<pkg.CardInfo>> Function()? onLoadDeclarable;

  const AnnounceCardDialog({
    super.key,
    this.generation = 0,
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
  bool _searchFailed = false;
  bool _loadingDeclarable = false;
  String _activeQuery = '';
  int _searchToken = 0;
  Timer? _debounce;

  /// 受限宣言（有候选列表）则直接罗列，不走搜索。
  bool get _restricted => widget.declarableCodes != null;

  @override
  void initState() {
    super.initState();
    if (_restricted) {
      // 受限宣言：打开即加载可宣言卡列表（build 前直接置位，避免 setState）。
      _loadingDeclarable = true;
      _loadDeclarable();
    }
  }

  @override
  void didUpdateWidget(covariant AnnounceCardDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged = (oldWidget.declarableCodes == null) != _restricted;
    if (oldWidget.generation == widget.generation && !modeChanged) return;
    _debounce?.cancel();
    _debounce = null;
    _searchToken++;
    _controller.clear();
    _results = const <pkg.CardInfo>[];
    _declarableCards = const <pkg.CardInfo>[];
    _isSearching = false;
    _searchFailed = false;
    _activeQuery = '';
    _loadingDeclarable = _restricted;
    if (_restricted) _loadDeclarable();
  }

  Future<void> _loadDeclarable() async {
    final token = ++_searchToken;
    final load = widget.onLoadDeclarable;
    if (load == null) {
      if (mounted && token == _searchToken) {
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
    if (!mounted || token != _searchToken) return;
    setState(() {
      _loadingDeclarable = false;
      _declarableCards = cards;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchToken++;
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
      _searchFailed = false;
      if (query.isEmpty) {
        _results = const <pkg.CardInfo>[];
      }
    });
    if (query.isEmpty) {
      return;
    }
    try {
      final results = await widget.onSearch(query);
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() => _results = results);
    } catch (_) {
      // 搜索失败（如网络异常）：清空结果并展示错误提示，避免弹窗卡在加载态
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _results = const <pkg.CardInfo>[];
        _searchFailed = true;
      });
    } finally {
      // 无论成功失败都要结束转圈；组件已卸载或已有新搜索时跳过
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = DuelRoomLayout.of(context).isCompact;
    return ResponsivePanel(
      maxWidth: 860,
      maxHeight: 680,
      header: const Text(
        '宣言卡名',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text(
              _restricted ? '从下方可宣言的卡片中选择要宣言的卡片。' : '输入卡名关键字，然后从搜索结果中选择要宣言的卡片。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9FB5C7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_restricted) ...[
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
                isDense: compact,
                hintText: '例如：电子龙、青眼、禁发令',
                hintStyle: const TextStyle(color: Color(0x668FA6BA)),
                filled: true,
                fillColor: const Color(0xFF111D2A),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00F0FF)),
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
            SizedBox(height: compact ? 4 : 12),
          ],
          Expanded(
            child: _restricted ? _buildDeclarableBody() : _buildSearchBody(),
          ),
        ],
      ),
    );
  }

  /// 受限宣言：直接罗列可宣言卡列表。
  Widget _buildDeclarableBody() {
    if (_loadingDeclarable) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_declarableCards.isEmpty) {
      return const Center(
        child: Text(
          '没有可宣言的卡片',
          style: TextStyle(
            color: Color(0xFF70859A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return _buildCardList(_declarableCards);
  }

  /// 自由宣言：按关键字搜索。
  Widget _buildSearchBody() {
    if (_activeQuery.isEmpty) {
      return const Center(
        child: Text(
          '请输入卡名开始搜索',
          style: TextStyle(
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
    if (_searchFailed) {
      return const Center(
        child: Text(
          '搜索失败，请稍后重试',
          style: TextStyle(
            color: Color(0xFF70859A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
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
    return Semantics(
      key: ValueKey('announce-card-select-${card.code}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      label: '宣言卡片：${card.name}',
      child: InkWell(
        excludeFromSemantics: true,
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
              Semantics(
                key: ValueKey('announce-card-inspect-${card.code}'),
                container: true,
                button: true,
                enabled: widget.onInspectCard != null,
                label: '查看卡片：${card.name}',
                excludeSemantics: true,
                onTap: widget.onInspectCard == null
                    ? null
                    : () => widget.onInspectCard!(card.code),
                child: InkWell(
                  excludeFromSemantics: true,
                  onTap: widget.onInspectCard == null
                      ? null
                      : () => widget.onInspectCard!(card.code),
                  child: CardImage(
                    code: card.code,
                    width: 74,
                    height: 102,
                    showCodeFallback: false,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ExcludeSemantics(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
