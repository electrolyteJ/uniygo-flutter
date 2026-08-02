import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:ygo_card/card_info.dart' as pkg;

import '../models/duel_board_state.dart';
import '../models/FieldCard.dart';

class DuelBoardController {
  final DuelBoardState board;
  final Future<void> Function(int code) ensureCardInfo;
  final pkg.CardInfo? Function(int code) getCardInfo;

  DuelBoardController({
    required this.board,
    required this.ensureCardInfo,
    required this.getCardInfo,
  });

  void applyDraw(MsgDraw msg) {
    final isMyDraw = msg.player == board.myController;
    final hand = isMyDraw ? board.selfHand : board.opponentHand;
    hand.addAll(msg.cards);
    if (isMyDraw) {
      board.selfDeck -= msg.count;
    } else {
      board.oppDeck -= msg.count;
    }
  }

  void applyUpdateData(MsgUpdateData msg) {
    for (final action in msg.actions) {
      final location = action.location;
      final code = action.code;
      if (location == null || code == null) {
        continue;
      }
      applyUpdateAction(
        controller: location.controller,
        zone: location.location,
        sequence: location.sequence,
        position: location.position,
        code: code,
        action: action,
      );
    }
  }

  void applyUpdateCard(MsgUpdateCard msg) {
    final action = msg.action;
    if (action == null) return;
    applyUpdateAction(
      controller: msg.player,
      zone: msg.zone,
      sequence: msg.sequence,
      position: action.location?.position ?? 0,
      code: action.code ?? 0,
      action: action,
    );
  }

  void applyReloadField(MsgReloadField msg) {
    board.fieldCards.clear();
    board.selfHand.clear();
    board.opponentHand.clear();

    for (final playerState in msg.players) {
      final isSelf = playerState.player == board.myController;
      if (isSelf) {
        board.selfLp = playerState.lp;
      } else {
        board.opponentLp = playerState.lp;
      }

      int deck = 0, extra = 0, grave = 0, removed = 0, hand = 0;
      for (final action in playerState.zoneActions) {
        switch (action.zone) {
          case CARD_ZONE_DECK:
            deck++;
            break;
          case CARD_ZONE_EXTRA:
            extra++;
            break;
          case CARD_ZONE_GRAVE:
            grave++;
            break;
          case CARD_ZONE_REMOVED:
            removed++;
            break;
          case CARD_ZONE_HAND:
            hand++;
            break;
          default:
            if (action.zone & CARD_ZONE_ONFIELD != 0) {
              board.fieldCards['${playerState.player}_${action.zone}_${action.sequence}'] = FieldCard(
                code: 0,
                controller: playerState.player,
                zone: action.zone,
                sequence: action.sequence,
                position: action.position ?? 0,
                overlayCount: action.overlayCount,
                disabled: false,
              );
            }
        }
      }

      if (isSelf) {
        board.selfDeck = deck;
        board.selfExtra = extra;
        board.selfGrave = grave;
        board.selfRemoved = removed;
        board.selfHand
          ..clear()
          ..addAll(List<int>.filled(hand, 0));
      } else {
        board.oppDeck = deck;
        board.oppExtra = extra;
        board.oppGrave = grave;
        board.oppRemoved = removed;
        board.opponentHand
          ..clear()
          ..addAll(List<int>.filled(hand, 0));
      }
    }
  }

  void applyMove(MsgMove msg) {
    removeCardFromLocation(msg.from.controller, msg.from.location, msg.from.sequence);
    addCardToLocation(
      msg.code,
      msg.to.controller,
      msg.to.location,
      msg.to.sequence,
      msg.to.position,
    );
  }

  void applyFieldDisabled(MsgFieldDisabled msg) {
    for (final action in msg.actions) {
      final key = '${action.controller}_${action.zone}_${action.sequence}';
      final current = board.fieldCards[key];
      if (current == null) continue;
      board.fieldCards[key] = FieldCard(
        code: current.code,
        controller: current.controller,
        zone: current.zone,
        sequence: current.sequence,
        position: current.position,
        overlayCount: current.overlayCount,
        disabled: action.disabled,
        attack: current.attack,
        defense: current.defense,
        name: current.name,
      );
    }
  }

  void applyBattle(MsgBattle msg) {
    updateBattleCardStats(msg.attacker, msg.attackerAttack, msg.attackerDefense);
    if (msg.hasDefender) {
      updateBattleCardStats(msg.defender, msg.defenderAttack, msg.defenderDefense);
    }
  }

  void applyPosChange(MsgPosChange msg) {
    final key = '${msg.cardInfo.controller}_${msg.cardInfo.location}_${msg.cardInfo.sequence}';
    final card = board.fieldCards[key];
    if (card == null) return;
    board.fieldCards[key] = FieldCard(
      code: card.code,
      controller: card.controller,
      zone: card.zone,
      sequence: card.sequence,
      position: msg.curPosition,
      overlayCount: card.overlayCount,
      disabled: card.disabled,
      attack: card.attack,
      defense: card.defense,
      name: card.name,
    );
  }

  void applyShuffleHand(MsgShuffleHand msg) {
    if (msg.player == board.myController) {
      board.selfHand
        ..clear()
        ..addAll(msg.cards);
    } else {
      board.opponentHand
        ..clear()
        ..addAll(List.filled(msg.count, 0));
    }
  }

  void updateBattleCardStats(CardLocation location, int attack, int defense) {
    final key = '${location.controller}_${location.location}_${location.sequence}';
    final current = board.fieldCards[key];
    if (current == null) return;
    board.fieldCards[key] = FieldCard(
      code: current.code,
      controller: current.controller,
      zone: current.zone,
      sequence: current.sequence,
      position: current.position,
      overlayCount: current.overlayCount,
      disabled: current.disabled,
      attack: attack,
      defense: defense,
      name: current.name,
    );
  }

  void applyUpdateAction({
    required int controller,
    required int zone,
    required int sequence,
    required int position,
    required int code,
    required MsgUpdateAction action,
  }) {
    if (zone & CARD_ZONE_HAND != 0) {
      final hand = controller == board.myController ? board.selfHand : board.opponentHand;
      while (hand.length <= sequence) {
        hand.add(0);
      }
      if (code > 0) {
        hand[sequence] = code;
        if (controller == board.myController) {
          unawaited(ensureCardInfo(code));
        }
      }
      return;
    }

    if (zone & CARD_ZONE_DECK != 0) {
      syncZoneCount(controller, zone, sequence);
      return;
    }

    if (zone & CARD_ZONE_EXTRA != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_GRAVE != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_REMOVED != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_ONFIELD != 0) {
      final key = '${controller}_${zone}_$sequence';
      final current = board.fieldCards[key];
      final effectiveCode = code > 0 ? code : (current?.code ?? 0);
      final overlayCount = action.overlayCards.isNotEmpty
          ? action.overlayCards.length
          : (current?.overlayCount ?? 0);
      board.fieldCards[key] = FieldCard(
        code: effectiveCode,
        controller: controller,
        zone: zone,
        sequence: sequence,
        position: position != 0 ? position : (current?.position ?? 0),
        overlayCount: overlayCount,
        disabled: current?.disabled ?? false,
        attack: action.attack ?? current?.attack,
        defense: action.defense ?? current?.defense,
        name: current?.name,
      );
      if (effectiveCode > 0) {
        unawaited(ensureCardInfo(effectiveCode));
      }
    }
  }

  void syncZoneCount(int controller, int zone, int sequence, {int? code}) {
    final nextCount = sequence + 1;
    final isSelf = controller == board.myController;
    if (zone & CARD_ZONE_DECK != 0) {
      if (isSelf) {
        board.selfDeck = board.selfDeck < nextCount ? nextCount : board.selfDeck;
      } else {
        board.oppDeck = board.oppDeck < nextCount ? nextCount : board.oppDeck;
      }
      return;
    }
    if (zone & CARD_ZONE_EXTRA != 0) {
      upsertZoneCode(isSelf ? board.selfExtraCodes : board.opponentExtraCodes, sequence, code);
      if (isSelf) {
        board.selfExtra = board.selfExtra < nextCount ? nextCount : board.selfExtra;
      } else {
        board.oppExtra = board.oppExtra < nextCount ? nextCount : board.oppExtra;
      }
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_GRAVE != 0) {
      upsertZoneCode(isSelf ? board.selfGraveCodes : board.opponentGraveCodes, sequence, code);
      if (isSelf) {
        board.selfGrave = board.selfGrave < nextCount ? nextCount : board.selfGrave;
      } else {
        board.oppGrave = board.oppGrave < nextCount ? nextCount : board.oppGrave;
      }
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_REMOVED != 0) {
      upsertZoneCode(isSelf ? board.selfRemovedCodes : board.opponentRemovedCodes, sequence, code);
      if (isSelf) {
        board.selfRemoved = board.selfRemoved < nextCount ? nextCount : board.selfRemoved;
      } else {
        board.oppRemoved = board.oppRemoved < nextCount ? nextCount : board.oppRemoved;
      }
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  void upsertZoneCode(List<int> list, int sequence, int? code) {
    while (list.length <= sequence) {
      list.add(0);
    }
    if (code != null && code > 0) {
      list[sequence] = code;
    }
  }

  void removeCardFromLocation(int controller, int location, int sequence) {
    if (location & CARD_ZONE_HAND != 0) {
      final hand = controller == board.myController ? board.selfHand : board.opponentHand;
      if (sequence < hand.length) {
        hand.removeAt(sequence);
      }
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      board.fieldCards.remove('${controller}_${location}_$sequence');
    } else if (location & CARD_ZONE_GRAVE != 0) {
      if (controller == board.myController) {
        board.selfGrave--;
      } else {
        board.oppGrave--;
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      if (controller == board.myController) {
        board.selfRemoved--;
      } else {
        board.oppRemoved--;
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == board.myController) {
        board.selfDeck--;
      } else {
        board.oppDeck--;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      if (controller == board.myController) {
        board.selfExtra--;
      } else {
        board.oppExtra--;
      }
    }
  }

  void addCardToLocation(int code, int controller, int location, int sequence, int position) {
    if (location & CARD_ZONE_HAND != 0) {
      if (controller == board.myController) {
        board.selfHand.add(code);
      } else {
        board.opponentHand.add(code);
      }
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      board.fieldCards['${controller}_${location}_$sequence'] = FieldCard(
        code: code,
        controller: controller,
        zone: location,
        sequence: sequence,
        position: position,
        disabled: false,
      );
      unawaited(ensureCardInfo(code));
    } else if (location & CARD_ZONE_GRAVE != 0) {
      if (controller == board.myController) {
        board.selfGrave++;
      } else {
        board.oppGrave++;
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      if (controller == board.myController) {
        board.selfRemoved++;
      } else {
        board.oppRemoved++;
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == board.myController) {
        board.selfDeck++;
      } else {
        board.oppDeck++;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      if (controller == board.myController) {
        board.selfExtra++;
      } else {
        board.oppExtra++;
      }
    }
  }

  void enrichFieldCard(int code, int controller, int location, int sequence) {
    final info = getCardInfo(code);
    if (info == null) return;
    final key = '${controller}_${location}_$sequence';
    final card = board.fieldCards[key];
    if (card == null || card.name != null) return;
    board.fieldCards[key] = FieldCard(
      code: card.code,
      controller: card.controller,
      zone: card.zone,
      sequence: card.sequence,
      position: card.position,
      overlayCount: card.overlayCount,
      disabled: card.disabled,
      attack: info.attack >= 0 ? info.attack : null,
      defense: info.defense >= 0 ? info.defense : null,
      name: info.name,
    );
  }
}
