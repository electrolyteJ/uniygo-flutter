import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';

void main() {
  group('MatchStore', () {
    test('setMatchResult updates state', () {
      final store = MatchStore();
      store.isSearching = true;
      bool notified = false;
      store.addListener(() => notified = true);
      store.setMatchResult('host', 7211, 'pass');
      expect(store.serverAddress, 'host');
      expect(store.isSearching, false);
      expect(notified, true);
    });
  });
}
