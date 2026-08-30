/// 洗牌动效落点与卡槽布局的一致性测试。
///
/// 防回归：洗牌动画的落点必须与 buildZoneSlotSpecs 里 DECK/EXTRA 槽位
/// 完全一致（用户曾反馈"我方洗卡组动画落在额外卡组位置"）。
library;

import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/components/hand_card/hand.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/components/zone/zone_slot_spec.dart';
import 'package:duelink/duelink.dart' show DuelPhase;
import 'package:flutter_test/flutter_test.dart';

FlameFieldSnapshot _snapshotFor(int myController) => FlameFieldSnapshot(
  fieldCards: const <String, FieldCard>{},
  myController: myController,
  phase: DuelPhase.idle,
  inDamageStep: false,
  battlePresentation: null,
  selfDeckShuffleTick: 0,
  oppDeckShuffleTick: 0,
  selfExtraShuffleTick: 0,
  oppExtraShuffleTick: 0,
  summonEffectTick: 0,
  summonEffectEvent: null,
  selfDeck: 0,
  oppDeck: 0,
  zoneCodes: const {},
  inlineSelectedFieldKeys: const {},
  inlineSelectableFieldKeys: const {},
  placeTargetFieldKeys: const {},
  activatableZoneKeys: const {},
  chainOrderBySlotKey: const {},
  selfHand: const HandSnapshot.empty(),
  oppHand: const HandSnapshot.empty(),
);

void main() {
  group('洗牌动效落点与槽位规格一致', () {
    // 双方朝向各测一遍（myController 决定 self/opp 镜像）。
    for (final myController in [0, 1]) {
      test('myController=$myController 时主卡组/额外落点正确', () {
        final specs = buildZoneSlotSpecs(_snapshotFor(myController));

        ZoneSlotSpec findSlot(String label, double boardY, double boardX) =>
            specs.firstWhere(
              (s) =>
                  s.label == label && s.boardY == boardY && s.boardX == boardX,
            );

        // 己方主卡组：底排最右（colX[6], stY）
        final selfDeck = findSlot(
          'DECK',
          DuelFieldLayout.stY,
          DuelFieldLayout.colX[6],
        );
        final selfDeckPos = DuelFieldLayout.deckSlotPos(isSelf: true);
        expect(selfDeckPos.dx, selfDeck.boardX);
        expect(selfDeckPos.dy, selfDeck.boardY);

        // 对方主卡组：顶排最左（colX[0], -stY）
        final oppDeck = findSlot(
          'DECK',
          -DuelFieldLayout.stY,
          DuelFieldLayout.colX[0],
        );
        final oppDeckPos = DuelFieldLayout.deckSlotPos(isSelf: false);
        expect(oppDeckPos.dx, oppDeck.boardX);
        expect(oppDeckPos.dy, oppDeck.boardY);

        // 己方额外：底排最左（colX[0], stY）
        final selfExtra = findSlot(
          'EXTRA',
          DuelFieldLayout.stY,
          DuelFieldLayout.colX[0],
        );
        final selfExtraPos = DuelFieldLayout.extraSlotPos(isSelf: true);
        expect(selfExtraPos.dx, selfExtra.boardX);
        expect(selfExtraPos.dy, selfExtra.boardY);

        // 对方额外：顶排最右（colX[6], -stY）
        final oppExtra = findSlot(
          'EXTRA',
          -DuelFieldLayout.stY,
          DuelFieldLayout.colX[6],
        );
        final oppExtraPos = DuelFieldLayout.extraSlotPos(isSelf: false);
        expect(oppExtraPos.dx, oppExtra.boardX);
        expect(oppExtraPos.dy, oppExtra.boardY);
      });
    }
  });
}
