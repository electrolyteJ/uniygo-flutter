import 'package:duel_room3/scene3d/standee_diff.dart';
import 'package:flutter_test/flutter_test.dart';

StandeeCardView card(String key, int code, {int position = 1, int overlay = 0}) =>
    StandeeCardView(
      zoneKey: key,
      code: code,
      position: position,
      overlayCount: overlay,
    );

void main() {
  test('空 → 有：全部 added', () {
    final diff = diffStandeeCards({}, {'0_4_0': card('0_4_0', 1000)});
    expect(diff.added.keys, ['0_4_0']);
    expect(diff.removed, isEmpty);
    expect(diff.updated, isEmpty);
  });

  test('消失 → removed；内容变化 → updated；不变 → 不在 diff 中', () {
    final prev = {
      '0_4_0': card('0_4_0', 1000),
      '0_4_1': card('0_4_1', 2000),
      '1_4_0': card('1_4_0', 3000),
    };
    final next = {
      '0_4_0': card('0_4_0', 1000), // 不变
      '0_4_1': card('0_4_1', 2000, position: 4), // 改守备
    };
    final diff = diffStandeeCards(prev, next);
    expect(diff.removed, ['1_4_0']);
    expect(diff.updated.keys, ['0_4_1']);
    expect(diff.added, isEmpty);
  });

  test('同 key 同内容新实例 → isEmpty（快照短路语义）', () {
    final prev = {'0_4_0': card('0_4_0', 1000, overlay: 2)};
    final next = {'0_4_0': card('0_4_0', 1000, overlay: 2)};
    expect(diffStandeeCards(prev, next).isEmpty, isTrue);
  });
}
