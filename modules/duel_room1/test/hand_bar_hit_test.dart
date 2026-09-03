import 'package:duel_room1/field/components/hand_card/hand.dart';
import 'package:duel_room1/field/duel_field_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact hand cards have unique 44px screen targets', (
    tester,
  ) async {
    final taps = <int>[];
    final game = DuelFieldGame(onHandCardTap: (index, _) => taps.add(index));
    await tester.pumpWidget(
      SizedBox(width: 640, height: 360, child: GameWidget(game: game)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    game.setHandBarsVisible(true);
    game.selfHandBar!.applySnapshot(
      const HandSnapshot(
        codes: [1001, 1002, 1003],
        faceUp: false,
        selectedIndex: null,
        highlightedIndices: {},
        checkedIndices: {},
        chainOrderByIndex: {},
        shuffleTick: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final first = game.selfHandBar!.cardSlotRect(0).center;
    final second = game.selfHandBar!.cardSlotRect(1).center;
    await tester.tapAt(first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps, [0]);

    await tester.tapAt(first.translate(-22, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps, [0, 0]);

    final before = taps.length;
    await tester.tapAt(
      Offset((first.dx + second.dx) / 2, (first.dy + second.dy) / 2),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps.length, before + 1);
  });
}
