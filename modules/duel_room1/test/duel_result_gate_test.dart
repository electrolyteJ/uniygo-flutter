import 'package:duel_room1/duel_room_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dismiss restores parent interactions and a new result reopens', () {
    final result = <String, Object?>{'round': 1};
    final dismissal = DuelResultDismissal();
    expect(dismissal.effective(result), same(result));
    dismissal.dismiss(result);
    expect(dismissal.effective(result), isNull);

    final next = <String, Object?>{'round': 2};
    expect(dismissal.effective(next), same(next));
  });
}
