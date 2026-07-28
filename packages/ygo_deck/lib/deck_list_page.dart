import 'deck_info.dart';

/// 分页卡组列表响应
class DeckListPage {
  /// 卡组摘要列表
  final List<DeckSummary> decks;

  /// 当前页码
  final int page;

  /// 每页大小
  final int size;

  /// 总数量
  final int total;

  const DeckListPage({
    this.decks = const [],
    this.page = 1,
    this.size = 20,
    this.total = 0,
  });

  bool get hasMore => page * size < total;

  Map<String, dynamic> toJson() => {
        'decks': decks.map((d) => d.toJson()).toList(),
        'page': page,
        'size': size,
        'total': total,
      };

  factory DeckListPage.fromJson(Map<String, dynamic> json) {
    final deckList = json['decks'] ?? json['data'] ?? json['list'] ?? [];
    return DeckListPage(
      decks: (deckList as List<dynamic>)
          .map((e) => DeckSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] ?? 1) as int,
      size: (json['size'] ?? 20) as int,
      total: (json['total'] ?? 0) as int,
    );
  }

  @override
  String toString() => 'DeckListPage(page=$page, size=$size, total=$total)';
}
