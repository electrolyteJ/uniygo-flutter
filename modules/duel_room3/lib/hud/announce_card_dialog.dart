import 'dart:async';

import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/ygo_data.dart' as pkg;

import 'hud_theme.dart';

/// 宣言卡名弹窗（MSG_ANNOUNCE_CARD）。
///
/// 移植自 modules/duel_room2/.../announce_card_dialog.dart（对齐功能，
/// 样式换 HudTheme）。两种形态：
/// - 受限宣言（[declarableCodes] 非 null，如抹杀之指名者）：打开即经
///   [onLoadDeclarable] 加载并直接罗列可宣言卡；
/// - 自由宣言（[declarableCodes] 为 null）：可宣言任意卡名，无有限列表，
///   经 [onSearch] 按关键字检索（biz SelectWindowNotifier.
///   searchAnnounceCards）。
class AnnounceCardDialog extends StatefulWidget {
  const AnnounceCardDialog({
    super.key,
    required this.onSearch,
    required this.onSelect,
    this.declarableCodes,
    this.onLoadDeclarable,
    this.hint,
  });

  final String? hint;
  final Future<List<pkg.CardInfo>> Function(String query) onSearch;
  final void Function(int code) onSelect;

  /// 受限宣言时可宣言的卡码集合；null 表示自由宣言。
  final Set<int>? declarableCodes;

  /// 加载 [declarableCodes] 对应的卡片信息；受限宣言时调用。
  final Future<List<pkg.CardInfo>> Function()? onLoadDeclarable;

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

  Future<void> _loadDeclarable() async {
    final load = widget.onLoadDeclarable;
    if (load == null) {
      if (mounted) setState(() => _loadingDeclarable = false);
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
      _searchFailed = false;
      if (query.isEmpty) {
        _results = const <pkg.CardInfo>[];
      }
    });
    if (query.isEmpty) return;
    try {
      final results = await widget.onSearch(query);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (_) {
      // 搜索失败（如网络异常）：清空结果并展示错误提示，避免弹窗卡在加载态
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = const <pkg.CardInfo>[];
        _searchFailed = true;
      });
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.all(16),
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.hint ?? '宣言一个卡名',
              textAlign: TextAlign.center,
              style: HudTheme.title,
            ),
            const SizedBox(height: 6),
            Text(
              _restricted ? '从下方可宣言的卡片中选择。' : '输入卡名关键字检索后选择。',
              textAlign: TextAlign.center,
              style: HudTheme.caption,
            ),
            const SizedBox(height: 12),
            if (!_restricted) ...[
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: HudTheme.body,
                decoration: InputDecoration(
                  hintText: '输入卡名检索…',
                  hintStyle: HudTheme.caption,
                  isDense: true,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: HudTheme.textSecondary,
                    size: 18,
                  ),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Flexible(
              child: _restricted ? _buildDeclarableBody() : _buildSearchBody(),
            ),
          ],
        ),
      ),
    );
  }

  /// 受限宣言：直接罗列可宣言卡列表。
  Widget _buildDeclarableBody() {
    if (_loadingDeclarable) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_declarableCards.isEmpty) {
      return const Center(child: Text('没有可宣言的卡片', style: HudTheme.caption));
    }
    return _buildCardList(_declarableCards);
  }

  /// 自由宣言：按关键字搜索。
  Widget _buildSearchBody() {
    if (_activeQuery.isEmpty) {
      return const Center(child: Text('请输入卡名开始搜索', style: HudTheme.caption));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchFailed) {
      return const Center(child: Text('搜索失败，请稍后重试', style: HudTheme.caption));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('没有可宣言的匹配卡片', style: HudTheme.caption));
    }
    return _buildCardList(_results);
  }

  Widget _buildCardList(List<pkg.CardInfo> cards) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildCardTile(cards[index]),
    );
  }

  Widget _buildCardTile(pkg.CardInfo card) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.onSelect(card.code),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration: HudTheme.panel(radius: 10),
        child: Row(
          children: [
            CardImage(code: card.code, width: 48, height: 68),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HudTheme.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(card.typeText, style: HudTheme.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '宣言',
              style: HudTheme.caption.copyWith(
                color: HudTheme.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
