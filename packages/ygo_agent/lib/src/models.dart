/// Data models, ported from ygo-agent `ygoinf/models.py`.
///
/// JSON field names match the wire format (snake_case), which is also the
/// format of the golden `*_input.json` files.
library;

import 'enums.dart';

class CardInfo {
  CardInfo({
    required this.code,
    required this.controller,
    required this.location,
    required this.sequence,
  });

  factory CardInfo.fromJson(Map<String, dynamic> json) => CardInfo(
        code: json['code'] as int,
        controller: Controller.fromValue(json['controller'] as String),
        location: Location.fromValue(json['location'] as String),
        sequence: json['sequence'] as int,
      );

  final int code;
  final Controller controller;
  final Location location;
  final int sequence;
}

class CardLocation {
  CardLocation({
    required this.controller,
    required this.location,
    required this.sequence,
    required this.overlaySequence,
  });

  factory CardLocation.fromJson(Map<String, dynamic> json) => CardLocation(
        controller: Controller.fromValue(json['controller'] as String),
        location: Location.fromValue(json['location'] as String),
        sequence: json['sequence'] as int,
        overlaySequence: json['overlay_sequence'] as int,
      );

  factory CardLocation.fromCardInfo(CardInfo info) => CardLocation(
        controller: info.controller,
        location: info.location,
        sequence: info.sequence,
        overlaySequence: -1,
      );

  final Controller controller;
  final Location location;
  final int sequence;

  /// Overlay index starting from 0, or -1 when not an xyz material.
  final int overlaySequence;
}

class Card {
  Card({
    required this.code,
    required this.location,
    required this.sequence,
    required this.controller,
    required this.position,
    required this.overlaySequence,
    required this.attribute,
    required this.race,
    required this.level,
    required this.counter,
    required this.negated,
    required this.attack,
    required this.defense,
    required this.types,
  });

  factory Card.fromJson(Map<String, dynamic> json) => Card(
        code: json['code'] as int,
        location: Location.fromValue(json['location'] as String),
        sequence: json['sequence'] as int,
        controller: Controller.fromValue(json['controller'] as String),
        position: Position.fromValue(json['position'] as String),
        overlaySequence: json['overlay_sequence'] as int,
        attribute: Attribute.fromValue(json['attribute'] as String),
        race: Race.fromValue(json['race'] as String),
        level: json['level'] as int,
        counter: json['counter'] as int,
        negated: json['negated'] as bool,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        types: (json['types'] as List<dynamic>)
            .map((e) => CardType.fromValue(e as String))
            .toList(),
      );

  final int code;
  final Location location;
  final int sequence;
  final Controller controller;
  final Position position;
  final int overlaySequence;
  final Attribute attribute;
  final Race race;
  final int level;
  final int counter;
  final bool negated;
  final int attack;
  final int defense;
  final List<CardType> types;
}

class Global {
  Global({
    required this.myLp,
    required this.opLp,
    required this.turn,
    required this.phase,
    required this.isFirst,
    required this.isMyTurn,
  });

  factory Global.fromJson(Map<String, dynamic> json) => Global(
        myLp: json['my_lp'] as int,
        opLp: json['op_lp'] as int,
        turn: json['turn'] as int,
        phase: Phase.fromValue(json['phase'] as String),
        isFirst: json['is_first'] as bool,
        isMyTurn: json['is_my_turn'] as bool,
      );

  final int myLp;
  final int opLp;
  final int turn;
  final Phase phase;
  final bool isFirst;
  final bool isMyTurn;
}

class Place {
  Place({
    required this.controller,
    required this.location,
    required this.sequence,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        controller: Controller.fromValue(json['controller'] as String),
        location: Location.fromValue(json['location'] as String),
        sequence: json['sequence'] as int,
      );

  final Controller controller;
  final Location location;
  final int sequence;
}

class Option {
  Option({required this.code, required this.response});

  factory Option.fromJson(Map<String, dynamic> json) => Option(
        code: json['code'] as int,
        response: json['response'] as int,
      );

  final int code;
  final int response;
}

class Chain {
  Chain({
    required this.code,
    required this.location,
    required this.effectDescription,
    required this.response,
  });

  factory Chain.fromJson(Map<String, dynamic> json) => Chain(
        code: json['code'] as int,
        location: CardLocation.fromJson(
            json['location'] as Map<String, dynamic>),
        effectDescription: json['effect_description'] as int,
        response: json['response'] as int,
      );

  final int code;
  final CardLocation location;
  final int effectDescription;
  final int response;
}

enum IdleCmdType {
  summon('summon'),
  spSummon('sp_summon'),
  reposition('reposition'),
  mset('mset'),
  set('set'),
  activate('activate'),
  toBp('to_bp'),
  toEp('to_ep');

  const IdleCmdType(this.value);
  final String value;

  static final Map<String, IdleCmdType> _byValue = {
    for (final e in values) e.value: e,
  };
  static IdleCmdType fromValue(String v) =>
      enumFromValue(_byValue, v, 'idle_cmd_type');
}

class IdleCmdData {
  IdleCmdData({
    required this.cardInfo,
    required this.effectDescription,
    required this.response,
  });

  factory IdleCmdData.fromJson(Map<String, dynamic> json) => IdleCmdData(
        cardInfo: CardInfo.fromJson(json['card_info'] as Map<String, dynamic>),
        effectDescription: json['effect_description'] as int,
        response: json['response'] as int,
      );

  final CardInfo cardInfo;
  final int effectDescription;
  final int response;
}

class IdleCmd {
  IdleCmd({required this.cmdType, this.data});

  factory IdleCmd.fromJson(Map<String, dynamic> json) => IdleCmd(
        cmdType: IdleCmdType.fromValue(json['cmd_type'] as String),
        data: json['data'] == null
            ? null
            : IdleCmdData.fromJson(json['data'] as Map<String, dynamic>),
      );

  final IdleCmdType cmdType;
  final IdleCmdData? data;
}

enum BattleCmdType {
  attack('attack'),
  activate('activate'),
  toM2('to_m2'),
  toEp('to_ep');

  const BattleCmdType(this.value);
  final String value;

  static final Map<String, BattleCmdType> _byValue = {
    for (final e in values) e.value: e,
  };
  static BattleCmdType fromValue(String v) =>
      enumFromValue(_byValue, v, 'battle_cmd_type');
}

class BattleCmdData {
  BattleCmdData({
    required this.cardInfo,
    required this.effectDescription,
    required this.directAttackable,
    required this.response,
  });

  factory BattleCmdData.fromJson(Map<String, dynamic> json) => BattleCmdData(
        cardInfo: CardInfo.fromJson(json['card_info'] as Map<String, dynamic>),
        effectDescription: json['effect_description'] as int,
        directAttackable: json['direct_attackable'] as bool,
        response: json['response'] as int,
      );

  final CardInfo cardInfo;
  final int effectDescription;
  final bool directAttackable;
  final int response;
}

class BattleCmd {
  BattleCmd({required this.cmdType, this.data});

  factory BattleCmd.fromJson(Map<String, dynamic> json) => BattleCmd(
        cmdType: BattleCmdType.fromValue(json['cmd_type'] as String),
        data: json['data'] == null
            ? null
            : BattleCmdData.fromJson(json['data'] as Map<String, dynamic>),
      );

  final BattleCmdType cmdType;
  final BattleCmdData? data;
}

class SelectAbleCard {
  SelectAbleCard({required this.location, required this.response});

  factory SelectAbleCard.fromJson(Map<String, dynamic> json) => SelectAbleCard(
        location:
            CardLocation.fromJson(json['location'] as Map<String, dynamic>),
        response: json['response'] as int,
      );

  final CardLocation location;
  final int response;
}

class SelectTributeCard {
  SelectTributeCard({
    required this.location,
    required this.level,
    required this.response,
  });

  factory SelectTributeCard.fromJson(Map<String, dynamic> json) =>
      SelectTributeCard(
        location:
            CardLocation.fromJson(json['location'] as Map<String, dynamic>),
        level: json['level'] as int,
        response: json['response'] as int,
      );

  final CardLocation location;
  final int level;
  final int response;
}

class SelectSumCard {
  SelectSumCard({
    required this.location,
    required this.level1,
    required this.level2,
    required this.response,
  });

  factory SelectSumCard.fromJson(Map<String, dynamic> json) => SelectSumCard(
        location:
            CardLocation.fromJson(json['location'] as Map<String, dynamic>),
        level1: json['level1'] as int,
        level2: json['level2'] as int,
        response: json['response'] as int,
      );

  final CardLocation location;
  final int level1;
  final int level2;
  final int response;
}

class SelectUnselectCard {
  SelectUnselectCard({required this.location, required this.response});

  factory SelectUnselectCard.fromJson(Map<String, dynamic> json) =>
      SelectUnselectCard(
        location:
            CardLocation.fromJson(json['location'] as Map<String, dynamic>),
        response: json['response'] as int,
      );

  final CardLocation location;
  final int response;
}

class AnnounceAttrib {
  AnnounceAttrib({required this.attribute, required this.response});

  factory AnnounceAttrib.fromJson(Map<String, dynamic> json) => AnnounceAttrib(
        attribute: Attribute.fromValue(json['attribute'] as String),
        response: json['response'] as int,
      );

  final Attribute attribute;
  final int response;
}

class AnnounceNumber {
  AnnounceNumber({required this.number, required this.response});

  factory AnnounceNumber.fromJson(Map<String, dynamic> json) => AnnounceNumber(
        number: json['number'] as int,
        response: json['response'] as int,
      );

  final int number;
  final int response;
}

// ─────────────────────────────────────────────────────────────────────
// Action messages (discriminated union on msg_type)
// ─────────────────────────────────────────────────────────────────────

sealed class ActionMsgData {
  MsgName get msgType;
}

class MsgSelectIdleCmd extends ActionMsgData {
  MsgSelectIdleCmd({required this.idleCmds});

  @override
  MsgName get msgType => MsgName.selectIdlecmd;

  final List<IdleCmd> idleCmds;
}

class MsgSelectChain extends ActionMsgData {
  MsgSelectChain({required this.forced, required this.chains});

  @override
  MsgName get msgType => MsgName.selectChain;

  final bool forced;
  final List<Chain> chains;
}

class MsgSelectCard extends ActionMsgData {
  MsgSelectCard({
    required this.cancelable,
    required this.min,
    required this.max,
    required this.cards,
    required this.selected,
  });

  @override
  MsgName get msgType => MsgName.selectCard;

  final bool cancelable; // Ignored upstream; kept for wire fidelity.
  final int min;
  final int max;
  final List<SelectAbleCard> cards;
  final List<int> selected;
}

class MsgSelectTribute extends ActionMsgData {
  MsgSelectTribute({
    required this.cancelable,
    required this.min,
    required this.max,
    required this.cards,
    required this.selected,
  });

  @override
  MsgName get msgType => MsgName.selectTribute;

  final bool cancelable;
  final int min;
  final int max;
  final List<SelectTributeCard> cards;
  final List<int> selected;
}

class MsgSelectSum extends ActionMsgData {
  MsgSelectSum({
    required this.overflow,
    required this.levelSum,
    required this.min,
    required this.max,
    required this.cards,
    required this.mustCards,
    required this.selected,
  });

  @override
  MsgName get msgType => MsgName.selectSum;

  final bool overflow;
  final int levelSum;
  final int min;
  final int max;
  final List<SelectSumCard> cards;
  final List<SelectSumCard> mustCards;
  final List<int> selected;
}

class MsgSelectPosition extends ActionMsgData {
  MsgSelectPosition({required this.code, required this.positions});

  @override
  MsgName get msgType => MsgName.selectPosition;

  final int code;
  final List<Position> positions;
}

class MsgSelectEffectYn extends ActionMsgData {
  MsgSelectEffectYn({
    required this.code,
    required this.location,
    required this.effectDescription,
  });

  @override
  MsgName get msgType => MsgName.selectEffectyn;

  final int code;
  final CardLocation location;
  final int effectDescription;
}

class MsgSelectYesNo extends ActionMsgData {
  MsgSelectYesNo({required this.effectDescription});

  @override
  MsgName get msgType => MsgName.selectYesno;

  final int effectDescription;
}

class MsgSelectBattleCmd extends ActionMsgData {
  MsgSelectBattleCmd({required this.battleCmds});

  @override
  MsgName get msgType => MsgName.selectBattlecmd;

  final List<BattleCmd> battleCmds;
}

class MsgSelectUnselectCard extends ActionMsgData {
  MsgSelectUnselectCard({
    required this.finishable,
    required this.cancelable,
    required this.min,
    required this.max,
    required this.selectedCards,
    required this.selectableCards,
  });

  @override
  MsgName get msgType => MsgName.selectUnselectCard;

  final bool finishable;
  final bool cancelable;
  final int min;
  final int max;
  final List<SelectUnselectCard> selectedCards;
  final List<SelectUnselectCard> selectableCards;
}

class MsgSelectOption extends ActionMsgData {
  MsgSelectOption({required this.options});

  @override
  MsgName get msgType => MsgName.selectOption;

  final List<Option> options;
}

class MsgSelectPlace extends ActionMsgData {
  MsgSelectPlace({required this.count, required this.places});

  @override
  MsgName get msgType => MsgName.selectPlace;

  final int count;
  final List<Place> places;
}

class MsgSelectDisfield extends ActionMsgData {
  MsgSelectDisfield({required this.count, required this.places});

  @override
  MsgName get msgType => MsgName.selectDisfield;

  final int count;
  final List<Place> places;
}

class MsgAnnounceAttrib extends ActionMsgData {
  MsgAnnounceAttrib({required this.count, required this.attributes});

  @override
  MsgName get msgType => MsgName.announceAttrib;

  final int count;
  final List<AnnounceAttrib> attributes;
}

class MsgAnnounceNumber extends ActionMsgData {
  MsgAnnounceNumber({required this.count, required this.numbers});

  @override
  MsgName get msgType => MsgName.announceNumber;

  final int count;
  final List<AnnounceNumber> numbers;
}

class ActionMsg {
  ActionMsg({required this.data});

  factory ActionMsg.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ActionMsg(data: _actionMsgDataFromJson(data));
  }

  final ActionMsgData data;
}

ActionMsgData _actionMsgDataFromJson(Map<String, dynamic> json) {
  final msgType = json['msg_type'] as String;
  List<Map<String, dynamic>> listOf(String key) =>
      (json[key] as List<dynamic>).cast<Map<String, dynamic>>();
  switch (msgType) {
    case 'select_idlecmd':
      return MsgSelectIdleCmd(
        idleCmds: listOf('idle_cmds').map(IdleCmd.fromJson).toList(),
      );
    case 'select_chain':
      return MsgSelectChain(
        forced: json['forced'] as bool,
        chains: listOf('chains').map(Chain.fromJson).toList(),
      );
    case 'select_card':
      return MsgSelectCard(
        cancelable: json['cancelable'] as bool,
        min: json['min'] as int,
        max: json['max'] as int,
        cards: listOf('cards').map(SelectAbleCard.fromJson).toList(),
        selected: (json['selected'] as List<dynamic>).cast<int>(),
      );
    case 'select_tribute':
      return MsgSelectTribute(
        cancelable: json['cancelable'] as bool,
        min: json['min'] as int,
        max: json['max'] as int,
        cards: listOf('cards').map(SelectTributeCard.fromJson).toList(),
        selected: (json['selected'] as List<dynamic>).cast<int>(),
      );
    case 'select_sum':
      return MsgSelectSum(
        overflow: json['overflow'] as bool,
        levelSum: json['level_sum'] as int,
        min: json['min'] as int,
        max: json['max'] as int,
        cards: listOf('cards').map(SelectSumCard.fromJson).toList(),
        mustCards: listOf('must_cards').map(SelectSumCard.fromJson).toList(),
        selected: (json['selected'] as List<dynamic>).cast<int>(),
      );
    case 'select_position':
      return MsgSelectPosition(
        code: json['code'] as int,
        positions: (json['positions'] as List<dynamic>)
            .map((e) => Position.fromValue(e as String))
            .toList(),
      );
    case 'select_effectyn':
      return MsgSelectEffectYn(
        code: json['code'] as int,
        location:
            CardLocation.fromJson(json['location'] as Map<String, dynamic>),
        effectDescription: json['effect_description'] as int,
      );
    case 'select_yesno':
      return MsgSelectYesNo(
        effectDescription: json['effect_description'] as int,
      );
    case 'select_battlecmd':
      return MsgSelectBattleCmd(
        battleCmds: listOf('battle_cmds').map(BattleCmd.fromJson).toList(),
      );
    case 'select_unselect_card':
      return MsgSelectUnselectCard(
        finishable: json['finishable'] as bool,
        cancelable: json['cancelable'] as bool,
        min: json['min'] as int,
        max: json['max'] as int,
        selectedCards:
            listOf('selected_cards').map(SelectUnselectCard.fromJson).toList(),
        selectableCards: listOf('selectable_cards')
            .map(SelectUnselectCard.fromJson)
            .toList(),
      );
    case 'select_option':
      return MsgSelectOption(
        options: listOf('options').map(Option.fromJson).toList(),
      );
    case 'select_place':
      return MsgSelectPlace(
        count: json['count'] as int,
        places: listOf('places').map(Place.fromJson).toList(),
      );
    case 'select_disfield':
      return MsgSelectDisfield(
        count: json['count'] as int,
        places: listOf('places').map(Place.fromJson).toList(),
      );
    case 'announce_attrib':
      return MsgAnnounceAttrib(
        count: json['count'] as int,
        attributes:
            listOf('attributes').map(AnnounceAttrib.fromJson).toList(),
      );
    case 'announce_number':
      return MsgAnnounceNumber(
        count: json['count'] as int,
        numbers: listOf('numbers').map(AnnounceNumber.fromJson).toList(),
      );
    default:
      throw FormatException('Unknown msg_type: "$msgType"');
  }
}

class Input {
  Input({required this.global, required this.cards, required this.actionMsg});

  factory Input.fromJson(Map<String, dynamic> json) => Input(
        global: Global.fromJson(json['global'] as Map<String, dynamic>),
        cards: (json['cards'] as List<dynamic>)
            .map((e) => Card.fromJson(e as Map<String, dynamic>))
            .toList(),
        actionMsg:
            ActionMsg.fromJson(json['action_msg'] as Map<String, dynamic>),
      );

  final Global global;
  final List<Card> cards;
  final ActionMsg actionMsg;
}
