/// `duelink_ai_ygo_agent` 模型 → predict 服务 wire JSON 的序列化器。
///
/// duelink_ai_ygo_agent 的模型只有 `fromJson`（供 golden 回放），远端 predict 服务
/// 需要把 [Input] 作为请求体发出，这里补齐反向序列化。字段名与
/// neos-ts `src/api/ygoAgent/schema.ts` / golden `*_input.json` 完全一致。
library;

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';

extension InputToJson on Input {
  Map<String, dynamic> toJson() => {
        'global': global.toJson(),
        'cards': [for (final c in cards) c.toJson()],
        'action_msg': actionMsg.toJson(),
      };
}

extension GlobalToJson on Global {
  Map<String, dynamic> toJson() => {
        'my_lp': myLp,
        'op_lp': opLp,
        'turn': turn,
        'phase': phase.value,
        'is_first': isFirst,
        'is_my_turn': isMyTurn,
      };
}

extension CardToJson on Card {
  Map<String, dynamic> toJson() => {
        'code': code,
        'location': location.value,
        'sequence': sequence,
        'controller': controller.value,
        'position': position.value,
        'overlay_sequence': overlaySequence,
        'attribute': attribute.value,
        'race': race.value,
        'level': level,
        'counter': counter,
        'negated': negated,
        'attack': attack,
        'defense': defense,
        'types': [for (final t in types) t.value],
      };
}

extension CardLocationToJson on CardLocation {
  Map<String, dynamic> toJson() => {
        'controller': controller.value,
        'location': location.value,
        'sequence': sequence,
        'overlay_sequence': overlaySequence,
      };
}

extension CardInfoToJson on CardInfo {
  Map<String, dynamic> toJson() => {
        'code': code,
        'controller': controller.value,
        'location': location.value,
        'sequence': sequence,
        'overlay_sequence': overlaySequence,
      };
}

extension PlaceToJson on Place {
  Map<String, dynamic> toJson() => {
        'controller': controller.value,
        'location': location.value,
        'sequence': sequence,
      };
}

extension ActionMsgToJson on ActionMsg {
  Map<String, dynamic> toJson() => {'data': data.toJson()};
}

extension ActionMsgDataToJson on ActionMsgData {
  Map<String, dynamic> toJson() {
    final self = this;
    return switch (self) {
      MsgSelectIdleCmd m => {
          'msg_type': 'select_idlecmd',
          'idle_cmds': [for (final c in m.idleCmds) c.toJson()],
        },
      MsgSelectChain m => {
          'msg_type': 'select_chain',
          'forced': m.forced,
          'chains': [for (final c in m.chains) c.toJson()],
        },
      MsgSelectCard m => {
          'msg_type': 'select_card',
          'cancelable': m.cancelable,
          'min': m.min,
          'max': m.max,
          'cards': [for (final c in m.cards) c.toJson()],
          'selected': m.selected,
        },
      MsgSelectTribute m => {
          'msg_type': 'select_tribute',
          'cancelable': m.cancelable,
          'min': m.min,
          'max': m.max,
          'cards': [for (final c in m.cards) c.toJson()],
          'selected': m.selected,
        },
      MsgSelectSum m => {
          'msg_type': 'select_sum',
          'overflow': m.overflow,
          'level_sum': m.levelSum,
          'min': m.min,
          'max': m.max,
          'cards': [for (final c in m.cards) c.toJson()],
          'must_cards': [for (final c in m.mustCards) c.toJson()],
          'selected': m.selected,
        },
      MsgSelectPosition m => {
          'msg_type': 'select_position',
          'code': m.code,
          'positions': [for (final p in m.positions) p.value],
        },
      MsgSelectEffectYn m => {
          'msg_type': 'select_effectyn',
          'code': m.code,
          'location': m.location.toJson(),
          'effect_description': m.effectDescription,
        },
      MsgSelectYesNo m => {
          'msg_type': 'select_yesno',
          'effect_description': m.effectDescription,
        },
      MsgSelectBattleCmd m => {
          'msg_type': 'select_battlecmd',
          'battle_cmds': [for (final c in m.battleCmds) c.toJson()],
        },
      MsgSelectUnselectCard m => {
          'msg_type': 'select_unselect_card',
          'finishable': m.finishable,
          'cancelable': m.cancelable,
          'min': m.min,
          'max': m.max,
          'selected_cards': [for (final c in m.selectedCards) c.toJson()],
          'selectable_cards': [for (final c in m.selectableCards) c.toJson()],
        },
      MsgSelectOption m => {
          'msg_type': 'select_option',
          'options': [
            for (final o in m.options) {'code': o.code, 'response': o.response},
          ],
        },
      MsgSelectPlace m => {
          'msg_type': 'select_place',
          'count': m.count,
          'places': [for (final p in m.places) p.toJson()],
        },
      MsgSelectDisfield m => {
          'msg_type': 'select_disfield',
          'count': m.count,
          'places': [for (final p in m.places) p.toJson()],
        },
      MsgAnnounceAttrib m => {
          'msg_type': 'announce_attrib',
          'count': m.count,
          'attributes': [
            for (final a in m.attributes)
              {'attribute': a.attribute.value, 'response': a.response},
          ],
        },
      MsgAnnounceNumber m => {
          'msg_type': 'announce_number',
          'count': m.count,
          'numbers': [
            for (final n in m.numbers)
              {'number': n.number, 'response': n.response},
          ],
        },
    };
  }
}

extension IdleCmdToJson on IdleCmd {
  Map<String, dynamic> toJson() => {
        'cmd_type': cmdType.value,
        // 上游 wire 格式显式携带 null（如 to_bp/to_ep），不可省略。
        'data': data?.toJson(),
      };
}

extension IdleCmdDataToJson on IdleCmdData {
  Map<String, dynamic> toJson() => {
        'card_info': cardInfo.toJson(),
        'effect_description': effectDescription,
        'response': response,
      };
}

extension BattleCmdToJson on BattleCmd {
  Map<String, dynamic> toJson() => {
        'cmd_type': cmdType.value,
        // 上游 wire 格式显式携带 null（如 to_m2/to_ep），不可省略。
        'data': data?.toJson(),
      };
}

extension BattleCmdDataToJson on BattleCmdData {
  Map<String, dynamic> toJson() => {
        'card_info': cardInfo.toJson(),
        'effect_description': effectDescription,
        'direct_attackable': directAttackable,
        'response': response,
      };
}

extension ChainToJson on Chain {
  Map<String, dynamic> toJson() => {
        'code': code,
        'location': location.toJson(),
        'effect_description': effectDescription,
        'response': response,
      };
}

extension SelectAbleCardToJson on SelectAbleCard {
  Map<String, dynamic> toJson() =>
      {'location': location.toJson(), 'response': response};
}

extension SelectTributeCardToJson on SelectTributeCard {
  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'level': level,
        'response': response,
      };
}

extension SelectSumCardToJson on SelectSumCard {
  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'level1': level1,
        'level2': level2,
        'response': response,
      };
}

extension SelectUnselectCardToJson on SelectUnselectCard {
  Map<String, dynamic> toJson() =>
      {'location': location.toJson(), 'response': response};
}
