/// ygo-agent 动作消息解码器测试：按本 fork 线格式手工构造各 MSG 载荷，
/// 验证解码结果与 env（ygopro.h）语义一致。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferWriter;
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';

void main() {
  group('decodeAgentActionMsg', () {
    test('idle cmd：分组内下标 + to_ep 在 to_bp 可用时省略', () {
      final w = BufferWriter();
      w.writeUint8(1); // player
      // summon ×1
      w.writeUint8(1);
      w.writeUint32(100);
      w.writeUint8(1);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(2);
      // sp_summon ×0 / repos ×0 / mset ×0 / set ×0
      w.writeUint8(0);
      w.writeUint8(0);
      w.writeUint8(0);
      w.writeUint8(0);
      // activate ×2（带 desc）
      w.writeUint8(2);
      w.writeUint32(200);
      w.writeUint8(0);
      w.writeUint8(LOCATION_SZONE);
      w.writeUint8(1);
      w.writeUint32(11); // desc
      w.writeUint32(201);
      w.writeUint8(0);
      w.writeUint8(LOCATION_HAND);
      w.writeUint8(4);
      w.writeUint32(12); // desc
      w.writeUint8(1); // to_bp
      w.writeUint8(1); // to_ep（应被省略）
      w.writeUint8(1); // can_shuffle

      final msg = decodeAgentActionMsg(MSG_SELECT_IDLECMD, w.toBytes());
      expect(msg.player, 1);
      final idle = msg.data as MsgSelectIdleCmd;
      expect(idle.idleCmds, hasLength(4)); // summon + 2 activate + toBp
      expect(idle.idleCmds[0].cmdType, IdleCmdType.summon);
      expect(idle.idleCmds[0].data!.cardInfo.code, 100);
      expect(idle.idleCmds[0].data!.cardInfo.controller, Controller.me);
      expect(idle.idleCmds[0].data!.response, 0); // (0<<16)|0
      expect(idle.idleCmds[1].cmdType, IdleCmdType.activate);
      expect(idle.idleCmds[1].data!.effectDescription, 11);
      expect(idle.idleCmds[1].data!.response, 5); // (0<<16)|5
      expect(idle.idleCmds[2].data!.response, (1 << 16) | 5);
      expect(idle.idleCmds[3].cmdType, IdleCmdType.toBp);
    });

    test('idle cmd：仅 to_ep 可用时保留 toEp', () {
      final w = BufferWriter();
      w.writeUint8(0);
      for (var i = 0; i < 6; i++) {
        w.writeUint8(0);
      }
      w.writeUint8(0); // to_bp
      w.writeUint8(1); // to_ep
      w.writeUint8(0);

      final idle =
          decodeAgentActionMsg(MSG_SELECT_IDLECMD, w.toBytes()).data
              as MsgSelectIdleCmd;
      expect(idle.idleCmds.single.cmdType, IdleCmdType.toEp);
    });

    test('battle cmd：activate 在前、to_ep 在 to_m2 可用时省略', () {
      final w = BufferWriter();
      w.writeUint8(0); // player
      // activate ×1
      w.writeUint8(1);
      w.writeUint32(300);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(0);
      w.writeUint32(21); // desc
      // attack ×1
      w.writeUint8(1);
      w.writeUint32(301);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(1);
      w.writeUint8(1); // directAttackable
      w.writeUint8(1); // to_m2
      w.writeUint8(1); // to_ep（应被省略）

      final msg = decodeAgentActionMsg(MSG_SELECT_BATTLECMD, w.toBytes());
      final battle = msg.data as MsgSelectBattleCmd;
      expect(battle.battleCmds, hasLength(3)); // activate + attack + toM2
      expect(battle.battleCmds[0].cmdType, BattleCmdType.activate);
      expect(battle.battleCmds[0].data!.effectDescription, 21);
      expect(battle.battleCmds[0].data!.response, 0); // (0<<16)|0
      expect(battle.battleCmds[1].cmdType, BattleCmdType.attack);
      expect(battle.battleCmds[1].data!.directAttackable, isTrue);
      expect(battle.battleCmds[1].data!.response, (0 << 16) | 1);
      expect(battle.battleCmds[2].cmdType, BattleCmdType.toM2);
    });

    test('chain：forced 取任一链；code 不做显示层取模', () {
      final w = BufferWriter();
      w.writeUint8(0); // player
      w.writeUint8(2); // size
      w.writeUint8(1); // spe_count（跳过）
      w.writeUint32(0); // hint0
      w.writeUint32(0); // hint1
      // chain0：带高位标志的 code（验证无 % 1000000000 hack）
      w.writeUint8(0);
      w.writeUint8(0); // 非强制
      w.writeUint32(0x80000123);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE | LOCATION_OVERLAY);
      w.writeUint8(3);
      w.writeUint8(1); // overlay sequence
      w.writeUint32(31);
      // chain1：强制
      w.writeUint8(0);
      w.writeUint8(1);
      w.writeUint32(400);
      w.writeUint8(1); // 对方
      w.writeUint8(LOCATION_SZONE);
      w.writeUint8(0);
      w.writeUint8(POS_FACEUP);
      w.writeUint32(32);

      final msg = decodeAgentActionMsg(MSG_SELECT_CHAIN, w.toBytes());
      final chain = msg.data as MsgSelectChain;
      expect(chain.forced, isTrue);
      expect(chain.chains, hasLength(2));
      expect(chain.chains[0].code, 0x80000123);
      expect(chain.chains[0].location.overlaySequence, 1);
      expect(chain.chains[0].location.controller, Controller.me);
      expect(chain.chains[0].response, 0);
      expect(chain.chains[1].location.controller, Controller.opponent);
      expect(chain.chains[1].response, 1);
    });

    test('select card：跳过 code 字段，overlay 位置解析', () {
      final w = BufferWriter();
      w.writeUint8(1); // player
      w.writeUint8(1); // cancelable
      w.writeUint8(1); // min
      w.writeUint8(2); // max
      w.writeUint8(2); // count
      w.writeUint32(500);
      w.writeUint8(1);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(0);
      w.writeUint8(POS_FACEUP_ATTACK);
      w.writeUint32(501);
      w.writeUint8(1);
      w.writeUint8(LOCATION_MZONE | LOCATION_OVERLAY);
      w.writeUint8(2);
      w.writeUint8(0); // overlay sequence

      final msg = decodeAgentActionMsg(MSG_SELECT_CARD, w.toBytes());
      final card = msg.data as MsgSelectCard;
      expect(card.cancelable, isTrue);
      expect(card.min, 1);
      expect(card.max, 2);
      expect(card.selected, isEmpty);
      expect(card.cards, hasLength(2));
      expect(card.cards[0].location.sequence, 0);
      expect(card.cards[0].location.overlaySequence, -1);
      expect(card.cards[0].response, 0);
      expect(card.cards[1].location.overlaySequence, 0);
      expect(card.cards[1].response, 1);
    });

    test('tribute：release_param → level', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(0); // cancelable
      w.writeUint8(1);
      w.writeUint8(2);
      w.writeUint8(1);
      w.writeUint32(600);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(4);
      w.writeUint8(8); // release_param

      final tribute =
          decodeAgentActionMsg(MSG_SELECT_TRIBUTE, w.toBytes()).data
              as MsgSelectTribute;
      expect(tribute.cards.single.level, 8);
      expect(tribute.cards.single.response, 0);
    });

    test('unselect card：可选列表在前，已选应答基址 = 可选数量', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(1); // finishable
      w.writeUint8(0); // cancelable
      w.writeUint8(1);
      w.writeUint8(1);
      // selectable ×2
      w.writeUint8(2);
      for (var i = 0; i < 2; i++) {
        w.writeUint32(700 + i);
        w.writeUint8(0);
        w.writeUint8(LOCATION_HAND);
        w.writeUint8(i);
        w.writeUint8(POS_FACEDOWN);
      }
      // selected ×1
      w.writeUint8(1);
      w.writeUint32(710);
      w.writeUint8(0);
      w.writeUint8(LOCATION_HAND);
      w.writeUint8(3);
      w.writeUint8(POS_FACEDOWN);

      final msg = decodeAgentActionMsg(MSG_SELECT_UNSELECT_CARD, w.toBytes());
      final un = msg.data as MsgSelectUnselectCard;
      expect(un.finishable, isTrue);
      expect(un.selectableCards.map((c) => c.response), [0, 1]);
      expect(un.selectedCards.single.response, 2);
    });

    test('sum：首字节 mode、次字节 player；level1/level2 拆分', () {
      final w = BufferWriter();
      w.writeUint8(1); // mode → overflow
      w.writeUint8(1); // player
      w.writeInt32(6); // level sum
      w.writeUint8(1);
      w.writeUint8(2);
      // must ×1
      w.writeUint8(1);
      w.writeUint32(800);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(0);
      w.writeUint32((2 << 16) | 3); // level1=3 level2=2
      // selectable ×1
      w.writeUint8(1);
      w.writeUint32(801);
      w.writeUint8(0);
      w.writeUint8(LOCATION_HAND);
      w.writeUint8(1);
      w.writeUint32(4);

      final msg = decodeAgentActionMsg(MSG_SELECT_SUM, w.toBytes());
      expect(msg.player, 1);
      final sum = msg.data as MsgSelectSum;
      expect(sum.overflow, isTrue);
      expect(sum.levelSum, 6);
      expect(sum.mustCards.single.level1, 3);
      expect(sum.mustCards.single.level2, 2);
      expect(sum.cards.single.level1, 4);
      expect(sum.cards.single.level2, 0);
    });

    test('position：按位升序枚举', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint32(900);
      w.writeUint8(0x5); // faceup_attack | faceup_defense

      final pos =
          decodeAgentActionMsg(MSG_SELECT_POSITION, w.toBytes()).data
              as MsgSelectPosition;
      expect(pos.code, 900);
      expect(pos.positions, [Position.faceupAttack, Position.faceupDefense]);
    });

    test('effectyn / yesno / option', () {
      final yn = BufferWriter();
      yn.writeUint8(0);
      yn.writeUint32(950);
      yn.writeUint8(1);
      yn.writeUint8(LOCATION_MZONE);
      yn.writeUint8(0);
      yn.writeUint8(POS_FACEUP);
      yn.writeUint32(41);
      final effectYn =
          decodeAgentActionMsg(MSG_SELECT_EFFECTYN, yn.toBytes()).data
              as MsgSelectEffectYn;
      expect(effectYn.code, 950);
      expect(effectYn.effectDescription, 41);
      expect(effectYn.location.controller, Controller.opponent);

      final yes = BufferWriter();
      yes.writeUint8(1);
      yes.writeUint32(42);
      expect(
        (decodeAgentActionMsg(MSG_SELECT_YESNO, yes.toBytes()).data
                as MsgSelectYesNo)
            .effectDescription,
        42,
      );

      final opt = BufferWriter();
      opt.writeUint8(0);
      opt.writeUint8(3);
      opt.writeUint32(1);
      opt.writeUint32(2);
      opt.writeUint32(3);
      final option =
          decodeAgentActionMsg(MSG_SELECT_OPTION, opt.toBytes()).data
              as MsgSelectOption;
      expect(option.options.map((o) => o.response), [0, 1, 2]);
    });

    test('place：count==0 按 1；flag 位清除 = 可用格', () {
      final w = BufferWriter();
      w.writeUint8(0); // player
      w.writeUint8(0); // count → 1
      // byte0 我方怪兽区 bit0 清除（seq0 可用）；byte2 对方怪兽区 bit2 清除
      final flag = 0xfe | (0xff << 8) | (0xfb << 16) | (0xff << 24);
      w.writeUint32(flag);

      final msg = decodeAgentActionMsg(MSG_SELECT_PLACE, w.toBytes());
      final place = msg.data as MsgSelectPlace;
      expect(place.count, 1);
      expect(place.places, hasLength(2));
      expect(place.places[0].controller, Controller.me);
      expect(place.places[0].location, Location.mzone);
      expect(place.places[0].sequence, 0);
      expect(place.places[1].controller, Controller.opponent);
      expect(place.places[1].location, Location.mzone);
      expect(place.places[1].sequence, 2);
    });

    test('place：count != 1 抛 NotSupportedException', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(2);
      w.writeUint32(0);
      expect(
        () => decodeAgentActionMsg(MSG_SELECT_PLACE, w.toBytes()),
        throwsA(isA<NotSupportedException>()),
      );
    });

    test('disfield：与 place 同格式', () {
      final w = BufferWriter();
      w.writeUint8(1);
      w.writeUint8(1);
      w.writeUint32(0xffffffff ^ 0x100); // 我方魔陷区 seq0 可用

      final dis =
          decodeAgentActionMsg(MSG_SELECT_DISFIELD, w.toBytes()).data
              as MsgSelectDisfield;
      expect(dis.places.single.controller, Controller.me);
      expect(dis.places.single.location, Location.szone);
      expect(dis.places.single.sequence, 0);
    });

    test('announce attrib：本 fork 无 min 字节；应答 = 原始位', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(1); // count
      w.writeUint32(ATTRIBUTE_EARTH | ATTRIBUTE_FIRE);

      final msg = decodeAgentActionMsg(MSG_ANNOUNCE_ATTRIB, w.toBytes());
      final attrib = msg.data as MsgAnnounceAttrib;
      expect(attrib.attributes, hasLength(2));
      expect(attrib.attributes[0].attribute, Attribute.earth);
      expect(attrib.attributes[0].response, ATTRIBUTE_EARTH);
      expect(attrib.attributes[1].attribute, Attribute.fire);
      expect(attrib.attributes[1].response, ATTRIBUTE_FIRE);
    });

    test('announce attrib：count != 1 抛 NotSupportedException', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(2);
      w.writeUint32(0x7f);
      expect(
        () => decodeAgentActionMsg(MSG_ANNOUNCE_ATTRIB, w.toBytes()),
        throwsA(isA<NotSupportedException>()),
      );
    });

    test('announce number：1..12 校验', () {
      final w = BufferWriter();
      w.writeUint8(0);
      w.writeUint8(3);
      w.writeUint32(1);
      w.writeUint32(6);
      w.writeUint32(12);
      final num =
          decodeAgentActionMsg(MSG_ANNOUNCE_NUMBER, w.toBytes()).data
              as MsgAnnounceNumber;
      expect(num.numbers.map((n) => n.number), [1, 6, 12]);
      expect(num.numbers.map((n) => n.response), [0, 1, 2]);

      final bad = BufferWriter();
      bad.writeUint8(0);
      bad.writeUint8(1);
      bad.writeUint32(13);
      expect(
        () => decodeAgentActionMsg(MSG_ANNOUNCE_NUMBER, bad.toBytes()),
        throwsA(isA<NotSupportedException>()),
      );
    });

    test('env 不支持的 func 抛 NotSupportedException', () {
      expect(
        () => decodeAgentActionMsg(MSG_SELECT_COUNTER, Uint8List(1)),
        throwsA(isA<NotSupportedException>()),
      );
      expect(
        () => decodeAgentActionMsg(MSG_SORT_CARD, Uint8List(1)),
        throwsA(isA<NotSupportedException>()),
      );
    });
  });
}
