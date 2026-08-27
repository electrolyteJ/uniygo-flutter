import 'package:biz/service_singleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/deck_info.dart';

import 'editor_rules.dart';

/// 编辑器状态：卡组内容 + 校验信息 + 卡池搜索结果。
class EditorState {
  const EditorState({
    required this.deck,
    this.structuralErrors = const [],
    this.banlistErrors = const [],
    this.searchResults = const [],
    this.searching = false,
    this.lastAddResult,
    this.dirty = false,
  });

  final DeckEditState deck;
  final List<String> structuralErrors;
  final List<String> banlistErrors;
  final List<CardInfo> searchResults;
  final bool searching;
  final AddCardResult? lastAddResult;
  final bool dirty;

  bool get hasErrors =>
      structuralErrors.isNotEmpty || banlistErrors.isNotEmpty;

  EditorState copyWith({
    DeckEditState? deck,
    List<String>? structuralErrors,
    List<String>? banlistErrors,
    List<CardInfo>? searchResults,
    bool? searching,
    AddCardResult? lastAddResult,
    bool? dirty,
  }) {
    return EditorState(
      deck: deck ?? this.deck,
      structuralErrors: structuralErrors ?? this.structuralErrors,
      banlistErrors: banlistErrors ?? this.banlistErrors,
      searchResults: searchResults ?? this.searchResults,
      searching: searching ?? this.searching,
      lastAddResult: lastAddResult,
      dirty: dirty ?? this.dirty,
    );
  }
}

/// 组卡编辑器控制器。
class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() => EditorState(deck: DeckEditState());

  YgoDataService get _data => ServiceSingleton.instance.dataService;

  /// 新建空白卡组。
  void newDeck() {
    state = EditorState(deck: DeckEditState());
  }

  /// 载入既有卡组。
  void loadDeck(DeckInfo deck) {
    state = EditorState(deck: DeckEditState.fromDeckInfo(deck));
    _revalidate();
  }

  void rename(String name) {
    state.deck.name = name;
    state = state.copyWith(deck: state.deck, dirty: true);
  }

  /// 加卡（自动路由到合法分区：额外怪 → extra，其余 → main）。
  AddCardResult addCard(CardInfo info) {
    final zone = allowedZones(info).contains(DeckZone.main)
        ? DeckZone.main
        : DeckZone.extra;
    return addCardTo(info, zone);
  }

  AddCardResult addCardTo(CardInfo info, DeckZone zone) {
    final result = tryAddCard(state.deck, info, zone);
    state = state.copyWith(lastAddResult: result, dirty: true);
    if (result == AddCardResult.ok) _revalidate();
    return result;
  }

  bool removeCard(int code, DeckZone zone) {
    final removed = tryRemoveCard(state.deck, code, zone);
    if (removed) {
      state = state.copyWith(dirty: true);
      _revalidate();
    }
    return removed;
  }

  /// 搜索卡池。
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = state.copyWith(searchResults: const [], searching: false);
      return;
    }
    state = state.copyWith(searching: true);
    try {
      final results = await _data.searchCards(keyword.trim());
      state = state.copyWith(searchResults: results, searching: false);
    } catch (_) {
      state = state.copyWith(searchResults: const [], searching: false);
    }
  }

  /// 保存到本地（ygo_deck_mycard）。
  Future<bool> save() async {
    final ok = await _data.saveDeck(state.deck.toDeckInfo());
    if (ok) state = state.copyWith(dirty: false);
    return ok;
  }

  void _revalidate() {
    final errors = structuralErrors(state.deck);
    // 禁限表校验需要 CardInfo 列表（展开数量）
    List<String> banlistErrors = const [];
    final mainInfos = <CardInfo>[];
    final extraInfos = <CardInfo>[];
    final sideInfos = <CardInfo>[];
    var allLoaded = true;
    for (final c in state.deck.main) {
      final info = _data.getCardCached(c.code);
      if (info == null) { allLoaded = false; break; }
      for (var i = 0; i < c.count; i++) { mainInfos.add(info); }
    }
    if (allLoaded) {
      for (final c in state.deck.extra) {
        final info = _data.getCardCached(c.code);
        if (info == null) { allLoaded = false; break; }
        for (var i = 0; i < c.count; i++) { extraInfos.add(info); }
      }
    }
    if (allLoaded) {
      for (final c in state.deck.side) {
        final info = _data.getCardCached(c.code);
        if (info == null) { allLoaded = false; break; }
        for (var i = 0; i < c.count; i++) { sideInfos.add(info); }
      }
    }
    if (allLoaded) {
      banlistErrors = _data.validateDeck(mainInfos, extraInfos, sideInfos);
    }
    state = state.copyWith(
      structuralErrors: errors,
      banlistErrors: banlistErrors,
    );
  }
}

final deckEditorProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
