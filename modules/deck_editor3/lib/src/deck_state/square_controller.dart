import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/deck_info.dart' show DeckSummary;
import 'package:ygo_deck_mdpro3/services/deck_api_client.dart';

/// 卡组市场排序方式。
enum SquareSort { latest, like, rank }

/// 卡组市场列表状态。
class SquareState {
  const SquareState({
    this.decks = const [],
    this.page = 0,
    this.total = 0,
    this.keyword = '',
    this.sort = SquareSort.latest,
    this.loading = false,
    this.error,
  });

  final List<DeckSummary> decks;
  final int page;
  final int total;
  final String keyword;
  final SquareSort sort;
  final bool loading;
  final String? error;

  static const pageSize = 20;

  bool get hasMore => page * pageSize < total;

  SquareState copyWith({
    List<DeckSummary>? decks,
    int? page,
    int? total,
    String? keyword,
    SquareSort? sort,
    bool? loading,
    String? error,
  }) {
    return SquareState(
      decks: decks ?? this.decks,
      page: page ?? this.page,
      total: total ?? this.total,
      keyword: keyword ?? this.keyword,
      sort: sort ?? this.sort,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// 卡组市场控制器：MDPro3 卡组广场（分页/搜索/排序）。
class SquareController extends Notifier<SquareState> {
  final DeckApiClient _api = DeckApiClient();

  @override
  SquareState build() {
    Future.microtask(refresh);
    return const SquareState();
  }

  /// 重新加载第一页（换关键词/排序时调用）。
  Future<void> refresh({String? keyword, SquareSort? sort}) async {
    state = SquareState(
      keyword: keyword ?? state.keyword,
      sort: sort ?? state.sort,
      loading: true,
    );
    await _loadPage(1, append: false);
  }

  /// 加载下一页。
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(state.page + 1, append: true);
  }

  Future<void> _loadPage(int page, {required bool append}) async {
    try {
      final result = await _api.fetchDeckList(
        page: page,
        size: SquareState.pageSize,
        keyword: state.keyword.isEmpty ? null : state.keyword,
        sortLike: state.sort == SquareSort.like,
        sortRank: state.sort == SquareSort.rank,
      );
      state = state.copyWith(
        decks: append ? [...state.decks, ...result.decks] : result.decks,
        page: result.page,
        total: result.total,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }
}

final deckSquareProvider =
    NotifierProvider<SquareController, SquareState>(SquareController.new);
