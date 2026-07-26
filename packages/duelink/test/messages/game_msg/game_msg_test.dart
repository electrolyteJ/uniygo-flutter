import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:duelink/src/messages/stoc/stoc_game_msg.dart';
import 'package:duelink/src/messages/game_msg/msg_start.dart';
import 'package:duelink/src/messages/game_msg/msg_draw.dart';
import 'package:duelink/src/messages/game_msg/msg_new_turn.dart';
import 'package:duelink/src/messages/game_msg/msg_new_phase.dart';
import 'package:duelink/src/messages/game_msg/msg_win.dart';
import 'package:duelink/src/messages/game_msg/msg_wait.dart';
import 'package:duelink/src/messages/game_msg/msg_hint.dart';
import 'package:duelink/src/messages/game_msg/msg_move.dart';
import 'package:duelink/src/messages/game_msg/msg_attack.dart';
import 'package:duelink/src/messages/game_msg/msg_damage.dart';
import 'package:duelink/src/messages/game_msg/msg_recover.dart';
import 'package:duelink/src/messages/game_msg/msg_summoning.dart';
import 'package:duelink/src/messages/game_msg/msg_chaining.dart';
import 'package:duelink/src/messages/game_msg/msg_select_option.dart';
import 'package:duelink/src/messages/game_msg/msg_select_effect_yn.dart';
import 'package:duelink/src/messages/game_msg/msg_select_position.dart';
import 'package:duelink/src/messages/game_msg/msg_select_yes_no.dart';
import 'package:duelink/src/messages/game_msg/msg_hand_res.dart';
import 'package:duelink/src/messages/game_msg/msg_toss.dart';
import 'package:duelink/src/messages/game_msg/msg_field_disabled.dart';
import 'package:duelink/src/messages/game_msg/msg_confirm_cards.dart';
import 'package:duelink/src/messages/game_msg/msg_shuffle_deck.dart';
import 'package:duelink/src/messages/game_msg/msg_shuffle_hand.dart';
import 'package:duelink/src/messages/game_msg/msg_pos_change.dart';
import 'package:duelink/src/messages/game_msg/msg_set.dart';
import 'package:duelink/src/protocol/buffer_io.dart';
import 'package:duelink/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('GameMsg simple types', () {
    test('MsgWait encode/decode', () {
      expect(MsgWait.decode(Uint8List(0)) is MsgWait, true);
      expect(MsgWait().encode(), isEmpty);
    });

    test('MsgNewTurn encode/decode', () {
      final msg = MsgNewTurn(player: 0);
      final decoded = MsgNewTurn.decode(msg.encode());
      expect(decoded.player, 0);
    });

    test('MsgNewPhase encode/decode', () {
      final msg = MsgNewPhase(phase: PHASE_BATTLE_START);
      final decoded = MsgNewPhase.decode(msg.encode());
      expect(decoded.phase, PHASE_BATTLE_START);
    });

    test('MsgWin encode/decode', () {
      final msg = MsgWin(winPlayer: 0, reason: 1);
      final decoded = MsgWin.decode(msg.encode());
      expect(decoded.winPlayer, 0);
      expect(decoded.reason, 1);
    });

    test('MsgHint encode/decode', () {
      final msg =
          MsgHint(hintCommand: HINT_SELECTMSG, hintPlayer: 1, hintData: 1234);
      final decoded = MsgHint.decode(msg.encode());
      expect(decoded.hintCommand, HINT_SELECTMSG);
      expect(decoded.hintPlayer, 1);
      expect(decoded.hintData, 1234);
    });

    test('MsgShuffleDeck encode/decode', () {
      final msg = MsgShuffleDeck(player: 1);
      final decoded = MsgShuffleDeck.decode(msg.encode());
      expect(decoded.player, 1);
    });

    test('MsgHandRes encode/decode', () {
      final msg = MsgHandRes(result1: 2, result2: 3);
      final decoded = MsgHandRes.decode(msg.encode());
      expect(decoded.result1, 2);
      expect(decoded.result2, 3);
    });
  });

  group('GameMsg complex types', () {
    test('MsgDraw encode/decode', () {
      final msg = MsgDraw(player: 0, count: 2, cards: [89631139, 46986414]);
      final decoded = MsgDraw.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.count, 2);
      expect(decoded.cards, [89631139, 46986414]);
    });

    test('MsgMove encode/decode', () {
      final from = CardLocation(
          controller: 0, location: CARD_ZONE_HAND, sequence: 0, position: 0);
      final to = CardLocation(
          controller: 0,
          location: CARD_ZONE_MZONE,
          sequence: 3,
          position: POS_FACEUP_ATTACK);
      final msg = MsgMove(code: 89631139, from: from, to: to, reason: 0);
      final decoded = MsgMove.decode(msg.encode());
      expect(decoded.code, 89631139);
      expect(decoded.from, from);
      expect(decoded.to, to);
    });

    test('MsgAttack encode/decode', () {
      final attacker = CardLocation(
          controller: 0,
          location: CARD_ZONE_MZONE,
          sequence: 2,
          position: POS_FACEUP_ATTACK);
      final target = CardLocation(
          controller: 1,
          location: CARD_ZONE_MZONE,
          sequence: 3,
          position: POS_FACEUP_ATTACK);
      final msg = MsgAttack(attacker: attacker, target: target);
      final decoded = MsgAttack.decode(msg.encode());
      expect(decoded.attacker, attacker);
      expect(decoded.target, target);
    });

    test('MsgAttack direct attack (all-zero target)', () {
      final attacker = CardLocation(
          controller: 0,
          location: CARD_ZONE_MZONE,
          sequence: 1,
          position: POS_FACEUP_ATTACK);
      final msg = MsgAttack(attacker: attacker, target: null);
      final decoded = MsgAttack.decode(msg.encode());
      expect(decoded.target, isNull);
    });

    test('MsgDamage encode/decode', () {
      final msg = MsgDamage(player: 0, value: 1200);
      final decoded = MsgDamage.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.value, 1200);
    });

    test('MsgRecover encode/decode', () {
      final msg = MsgRecover(player: 1, value: 1000);
      final decoded = MsgRecover.decode(msg.encode());
      expect(decoded.player, 1);
      expect(decoded.value, 1000);
    });

    test('MsgSummoning encode/decode', () {
      final loc = CardLocation(
          controller: 0,
          location: CARD_ZONE_MZONE,
          sequence: 0,
          position: POS_FACEUP_ATTACK);
      final msg = MsgSummoning(code: 89631139, location: loc);
      final decoded = MsgSummoning.decode(msg.encode());
      expect(decoded.code, 89631139);
      expect(decoded.location, loc);
    });

    test('MsgChaining encode/decode', () {
      final loc = CardLocation(
          controller: 0,
          location: CARD_ZONE_SZONE,
          sequence: 2,
          position: POS_FACEDOWN);
      final msg = MsgChaining(code: 12345678, location: loc);
      final decoded = MsgChaining.decode(msg.encode());
      expect(decoded.code, 12345678);
      expect(decoded.location, loc);
    });

    test('MsgSelectOption encode/decode', () {
      final msg = MsgSelectOption(player: 0, count: 3, codes: [100, 200, 300]);
      final decoded = MsgSelectOption.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.count, 3);
      expect(decoded.codes, [100, 200, 300]);
    });

    test('MsgSelectEffectYn encode/decode', () {
      final loc = CardLocation(
          controller: 1,
          location: CARD_ZONE_MZONE,
          sequence: 3,
          position: POS_FACEUP_ATTACK);
      final msg =
          MsgSelectEffectYn(player: 0, code: 123, location: loc, effectDescription: 456);
      final decoded = MsgSelectEffectYn.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.code, 123);
      expect(decoded.location, loc);
      expect(decoded.effectDescription, 456);
    });

    test('MsgSelectPosition encode/decode', () {
      final msg = MsgSelectPosition(
          player: 1,
          code: 89631139,
          positions: POS_FACEUP_ATTACK | POS_FACEUP_DEFENSE);
      final decoded = MsgSelectPosition.decode(msg.encode());
      expect(decoded.player, 1);
      expect(decoded.code, 89631139);
      expect(decoded.positions, POS_FACEUP_ATTACK | POS_FACEUP_DEFENSE);
    });

    test('MsgSelectYesNo encode/decode', () {
      final msg = MsgSelectYesNo(player: 0, effectDescription: 999);
      final decoded = MsgSelectYesNo.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.effectDescription, 999);
    });

    test('MsgToss encode/decode', () {
      final msg = MsgToss(player: 0, count: 3, results: [1, 0, 1]);
      final decoded = MsgToss.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.count, 3);
      expect(decoded.results, [1, 0, 1]);
    });

    test('MsgFieldDisabled encode/decode', () {
      final msg = MsgFieldDisabled(flag: 0x12345678);
      final decoded = MsgFieldDisabled.decode(msg.encode());
      expect(decoded.flag, 0x12345678);
    });

    test('MsgConfirmCards encode/decode', () {
      final cards = [
        CardInfo(code: 100, controller: 0, location: CARD_ZONE_HAND, sequence: 0)
      ];
      final msg = MsgConfirmCards(player: 0, count: 1, cards: cards);
      final decoded = MsgConfirmCards.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.count, 1);
      expect(decoded.cards[0].code, 100);
    });

    test('MsgPosChange encode/decode', () {
      final info = CardInfo(
          code: 89631139,
          controller: 0,
          location: CARD_ZONE_MZONE,
          sequence: 3);
      final msg = MsgPosChange(
          cardInfo: info,
          prePosition: POS_FACEUP_DEFENSE,
          curPosition: POS_FACEUP_ATTACK);
      final decoded = MsgPosChange.decode(msg.encode());
      expect(decoded.cardInfo, info);
      expect(decoded.prePosition, POS_FACEUP_DEFENSE);
      expect(decoded.curPosition, POS_FACEUP_ATTACK);
    });

    test('MsgSet encode/decode', () {
      final loc = CardLocation(
          controller: 0,
          location: CARD_ZONE_SZONE,
          sequence: 2,
          position: POS_FACEDOWN);
      final msg = MsgSet(code: 1234, location: loc);
      final decoded = MsgSet.decode(msg.encode());
      expect(decoded.code, 1234);
      expect(decoded.location, loc);
    });

    test('MsgShuffleHand encode/decode', () {
      final msg = MsgShuffleHand(player: 1, count: 2, cards: [100, 200]);
      final decoded = MsgShuffleHand.decode(msg.encode());
      expect(decoded.count, 2);
      expect(decoded.cards, [100, 200]);
    });
  });

  group('StocGameMessage wrapper', () {
    test('wraps MsgStart', () {
      final inner = MsgStart(
        playerType: 0,
        life1: 8000,
        life2: 8000,
        deckSize1: 40,
        extraSize1: 15,
        deckSize2: 40,
        extraSize2: 15,
      );
      final msg = StocGameMessage(func: MSG_START, innerMsg: inner);
      final encoded = msg.encode();
      final decoded = StocGameMessage.decode(encoded);
      expect(decoded.func, MSG_START);
      final start = decoded.innerMsg as MsgStart;
      expect(start.life1, 8000);
      expect(start.deckSize1, 40);
    });

    test('wraps MsgDraw', () {
      final inner = MsgDraw(player: 0, count: 1, cards: [89631139]);
      final msg = StocGameMessage(func: MSG_DRAW, innerMsg: inner);
      final decoded = StocGameMessage.decode(msg.encode());
      final draw = decoded.innerMsg as MsgDraw;
      expect(draw.cards, [89631139]);
    });
  });

  group('MsgStart', () {
    test('with masterRule', () {
      final msg = MsgStart(
        playerType: 0,
        masterRule: 5,
        life1: 8000,
        life2: 8000,
        deckSize1: 40,
        extraSize1: 15,
        deckSize2: 40,
        extraSize2: 15,
      );
      final decoded = MsgStart.decode(msg.encode());
      expect(decoded.masterRule, 5);
      expect(decoded.life1, 8000);
    });

    test('without masterRule', () {
      final msg = MsgStart(
        playerType: 0,
        life1: 8000,
        life2: 8000,
        deckSize1: 40,
        extraSize1: 15,
        deckSize2: 60,
        extraSize2: 15,
      );
      final decoded = MsgStart.decode(msg.encode());
      expect(decoded.masterRule, isNull);
      expect(decoded.extraSize2, 15);
    });
  });
}
