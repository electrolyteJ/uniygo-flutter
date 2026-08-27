import 'package:biz/service_singleton.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ygo_data/deck_info.dart';
import 'package:ygo_data/ygo_data.dart' show IDeckService;

part 'my_decks_controller.g.dart';

/// 我的卡组（本地，ygo_deck_mycard）控制器。
@Riverpod(keepAlive: true)
class MyDecksController extends _$MyDecksController {
  @override
  AsyncValue<List<DeckInfo>> build() {
    Future.microtask(refresh);
    return const AsyncValue.loading();
  }

  IDeckService get _decks => ServiceSingleton.instance.dataService;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _decks.loadDeckList());
  }

  Future<bool> deleteDeck(String name) async {
    final ok = await _decks.deleteDeck(name);
    if (ok) await refresh();
    return ok;
  }

  Future<bool> saveDeck(DeckInfo deck) async {
    final ok = await _decks.saveDeck(deck);
    if (ok) await refresh();
    return ok;
  }

  /// 复制一套卡组到本地（市场详情「复制到我的卡组」）。
  Future<bool> copyToLocal(DeckInfo deck, {String? rename}) async {
    final copy = deck.toDeckInfoCopy(rename: rename);
    return saveDeck(copy);
  }

  /// 导入 YDK 文本为新卡组。
  Future<DeckInfo?> importYdk(String content, String name) async {
    final deck = await _decks.importFromYdk(content, name);
    if (deck != null) await refresh();
    return deck;
  }
}

/// DeckInfo 复制助手（改名的拷贝）。
extension DeckInfoCopy on DeckInfo {
  DeckInfo toDeckInfoCopy({String? rename}) => DeckInfo(
        deckName: rename ?? deckName,
        mainDeck: mainDeck.map((c) => DeckCard(code: c.code, count: c.count)).toList(),
        extraDeck: extraDeck.map((c) => DeckCard(code: c.code, count: c.count)).toList(),
        sideDeck: sideDeck.map((c) => DeckCard(code: c.code, count: c.count)).toList(),
      );
}
