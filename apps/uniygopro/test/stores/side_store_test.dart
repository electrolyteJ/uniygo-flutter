import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/pages/side/side_store.dart';

void main() {
  test('SideStore state transitions', () {
    final store = SideStore();
    expect(store.stage, SideStage.none);
    store.enterSide();
    expect(store.stage, SideStage.sideChanging);
    store.waiting();
    expect(store.stage, SideStage.waiting);
    store.startDuel();
    expect(store.stage, SideStage.duelStart);
    store.reset();
    expect(store.stage, SideStage.none);
  });
}
