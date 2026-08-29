
import 'package:resource_deck_mdpro3/services/deck_api_client.dart';

Future<void> main() async {
  final api = DeckApiClient();
  print('baseUrl = ' + api.baseUrl);

  final page = await api.fetchDeckList(page: 1, size: 3);
  print('list: total=' + page.total.toString() + ' decks=' + page.decks.length.toString());
  for (final d in page.decks) {
    print('  - ' + d.deckId + ' | ' + d.name + ' | ' + d.contributor + ' | likes=' + d.likeCount.toString() + ' | cover=' + d.coverCode.toString());
  }

  final detail = await api.fetchDeckDetail(page.decks.first.deckId);
  print('detail: ' + detail.name + ' main=' + detail.mainCount.toString() + ' extra=' + detail.extraCount.toString() + ' side=' + detail.sideCount.toString());

  final id = await api.generateDeckId();
  print('new deckId = ' + id);

  final search = await api.fetchDeckList(page: 1, size: 2, keyword: '白龙');
  print('search 白龙: total=' + search.total.toString());
  api.dispose();
}
