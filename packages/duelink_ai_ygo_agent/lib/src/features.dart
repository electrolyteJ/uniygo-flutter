/// Feature encoding, ported 1:1 from ygo-agent `ygoinf/features.py`.
///
/// All tensors are `Uint8List` to match numpy `uint8` exactly (values wrap
/// mod 256 on assignment, same as numpy).
library;

import 'dart:typed_data';

import 'code_list.dart';
import 'constants.dart';
import 'enums.dart';
import 'models.dart';

/// Mutable record mirroring the upstream pydantic `LegalAction`, with the
/// same defaults (effect=-1, response=-100, ...).
class LegalAction {
  LegalAction({required this.msg});

  final MsgName msg;
  String spec = '';
  ActionAct act = ActionAct.none;
  ActionPhase phase = ActionPhase.none;
  bool finish = false;
  Position position = Position.none;
  int effect = -1;
  int number = 0;
  ActionPlace place = ActionPlace.none;
  Attribute attribute = Attribute.none;
  int cardIndex = 0;
  int cardId = 0;
  int response = -100;

  /// Temporary field for select_sum.
  bool canFinish = false;
}

/// Python `int_transform`: (x // 256, x % 256), written into [x] at [off]
/// as two uint8 bytes (high byte first).
void writeIntTransform(Uint8List x, int off, int v) {
  x[off] = (v ~/ 256) & 0xFF;
  x[off + 1] = (v % 256) & 0xFF;
}

/// Python `float_transform`: ((int(x) % 65536) // 256, (int(x) % 65536) %
/// 256). Dart's `%` is non-negative for positive divisors, matching Python.
void writeFloatTransform(Uint8List x, int off, int v) {
  final m = v % 65536;
  x[off] = (m ~/ 256) & 0xFF;
  x[off + 1] = m % 256;
}

/// Python `to_spec` applied to a [CardLocation].
String toSpec(CardLocation x) {
  final buf = StringBuffer();
  switch (x.location) {
    case Location.hand:
      buf.write('h');
    case Location.mzone:
      buf.write('m');
    case Location.szone:
      buf.write('s');
    case Location.grave:
      buf.write('g');
    case Location.removed:
      buf.write('r');
    case Location.extra:
      buf.write('x');
    case Location.deck:
      break; // No letter for deck.
  }
  buf.write(x.sequence + 1);
  if (x.overlaySequence >= 0) {
    buf.write('a${x.overlaySequence + 1}');
  }
  var spec = buf.toString();
  if (x.controller == Controller.opponent) {
    spec = 'o$spec';
  }
  return spec;
}

/// Python `to_spec` applied to a [CardInfo] (overlay_sequence = -1).
String cardInfoToSpec(CardInfo info) => toSpec(CardLocation.fromCardInfo(info));

/// Python `get_spec`.
String getSpec(Card c) => toSpec(CardLocation(
      controller: c.controller,
      location: c.location,
      sequence: c.sequence,
      overlaySequence: c.overlaySequence,
    ));

/// Python `place_to_select`.
ActionPlace placeToSelect(Place place) {
  final buf = StringBuffer();
  if (place.controller == Controller.opponent) {
    buf.write('o');
  }
  if (place.location == Location.mzone) {
    buf.write('m');
  } else if (place.location == Location.szone) {
    buf.write('s');
  } else {
    throw ArgumentError('Invalid location: ${place.location}');
  }
  buf.write(place.sequence + 1);
  return ActionPlace.fromValue(buf.toString());
}

/// Python `encode_card`.
Uint8List encodeCard(Card card, CodeList codeList) {
  final x = Uint8List(nCardFeatures);

  writeIntTransform(x, 0, codeList.idOf(card.code));

  x[2] = locationToId[card.location]!;
  if (card.location == Location.mzone ||
      card.location == Location.szone ||
      card.location == Location.grave) {
    x[3] = (card.sequence + 1) & 0xFF;
  }
  x[4] = controllerToId[card.controller]!;

  var position = card.position;
  final overlay = card.overlaySequence != -1;
  if (overlay) {
    position = Position.faceup;
  } else if (card.location == Location.deck ||
      card.location == Location.hand ||
      card.location == Location.extra) {
    if (position == Position.facedownDefense ||
        position == Position.facedown ||
        position == Position.facedownAttack) {
      position = Position.facedown;
    }
  }
  x[5] = positionToId[position]!;

  x[6] = overlay ? 1 : 0;
  x[7] = attributeToId[card.attribute]!;
  x[8] = raceToId[card.race]!;
  x[9] = card.level.clamp(0, 13);
  x[10] = card.counter.clamp(0, 15);
  x[11] = card.negated ? 1 : 0;

  writeFloatTransform(x, 12, card.attack);
  writeFloatTransform(x, 14, card.defense);

  for (final t in card.types) {
    x[16 + typeToId[t]!] = 1;
  }
  return x;
}

/// Result of [encodeCards]: the padded cards tensor and the spec ->
/// (card_index, card_id) lookup (1-based index, 0 for unknown).
class CardsEncoding {
  CardsEncoding({required this.tensor, required this.specInfos});
  final Uint8List tensor;
  final Map<String, (int index, int codeId)> specInfos;
}

/// Python `encode_cards`. Truncates to 2*MAX_CARDS cards, pads the rest
/// with zeros. Duplicate specs overwrite earlier entries (Python dict).
CardsEncoding encodeCards(List<Card> cards, CodeList codeList) {
  final specInfos = <String, (int, int)>{};
  final truncated =
      cards.length > 2 * maxCards ? cards.sublist(0, 2 * maxCards) : cards;
  final x = Uint8List(2 * maxCards * nCardFeatures);
  for (var i = 0; i < truncated.length; i++) {
    final encoded = encodeCard(truncated[i], codeList);
    x.setRange(i * nCardFeatures, (i + 1) * nCardFeatures, encoded);
    specInfos[getSpec(truncated[i])] = (i + 1, codeList.idOf(truncated[i].code));
  }
  return CardsEncoding(tensor: x, specInfos: specInfos);
}

/// Python `count_location_cards`: 14 counters, my side then opponent side,
/// in the order deck, hand, mzone, szone, grave, removed, extra.
List<int> countLocationCards(List<Card> cards) {
  final counts = List<int>.filled(14, 0);
  for (final c in cards) {
    final base = c.controller == Controller.me ? 0 : 7;
    final idx = switch (c.location) {
      Location.deck => 0,
      Location.hand => 1,
      Location.mzone => 2,
      Location.szone => 3,
      Location.grave => 4,
      Location.removed => 5,
      Location.extra => 6,
    };
    counts[base + idx] += 1;
  }
  return counts;
}

/// Python `encode_global`.
Uint8List encodeGlobal(Global g, List<Card> cards) {
  final x = Uint8List(nGlobalFeatures);
  writeFloatTransform(x, 0, g.myLp);
  writeFloatTransform(x, 2, g.opLp);
  x[4] = g.turn.clamp(0, 16);
  x[5] = phaseToId[g.phase]!;
  x[6] = g.isFirst ? 1 : 0;
  x[7] = g.isMyTurn ? 1 : 0;
  final counts = countLocationCards(cards);
  for (var i = 0; i < 14; i++) {
    x[8 + i] = counts[i] & 0xFF;
  }
  // x[22] stays 0.
  return x;
}

/// Python `encode_action`.
Uint8List encodeAction(LegalAction action) {
  final x = Uint8List(nActionFeatures);
  x[0] = action.cardIndex & 0xFF;
  writeIntTransform(x, 1, action.cardId);
  x[3] = msgToId[action.msg]!;
  x[4] = actionActToId[action.act]!;
  x[5] = action.finish ? 1 : 0;

  var effect = action.effect;
  if (effect == -1) {
    effect = 0;
  } else if (effect == 0) {
    effect = 1;
  } else if (effect >= cardEffectOffset) {
    effect = effect - cardEffectOffset + 2;
  } else {
    final id = systemStringToId[effect];
    if (id == null) {
      throw ArgumentError('Unknown system string: $effect');
    }
    effect = id;
  }
  x[6] = effect & 0xFF;

  x[7] = actionPhaseToId[action.phase]!;
  x[8] = positionToId[action.position]!;
  x[9] = action.number.clamp(0, 12);
  x[10] = placeToId[action.place]!;
  x[11] = attributeToId[action.attribute]!;
  return x;
}

/// Python `find_spec_info`.
(int, int) findSpecInfo(
    Map<String, (int, int)> specInfos, String spec) {
  return specInfos[spec] ?? (0, 0);
}

/// Python `encode_legal_actions`. Mutates [actions] (fills card_index and
/// card_id), then encodes. The upstream `print(actions[0].msg)` debug line
/// is intentionally not ported.
Uint8List encodeLegalActions(
    List<LegalAction> actions, Map<String, (int, int)> specInfos) {
  final truncated =
      actions.length > maxActions ? actions.sublist(0, maxActions) : actions;
  final x = Uint8List(maxActions * nActionFeatures);
  for (var i = 0; i < truncated.length; i++) {
    final action = truncated[i];
    final (cardIndex, cardId) = findSpecInfo(specInfos, action.spec);
    action.cardIndex = cardIndex;
    if (action.cardId == 0) {
      action.cardId = cardId;
    }
    final encoded = encodeAction(action);
    x.setRange(i * nActionFeatures, (i + 1) * nActionFeatures, encoded);
  }
  return x;
}

/// Python `unpack_desc`.
(int, int) unpackDesc(int code, int desc) {
  if (desc < descriptionLimit) {
    return (0, desc);
  }
  final codeOut = desc >> 4;
  final idx = desc & 0xF;
  if (idx < 0 || idx >= 14) {
    throw ArgumentError('Invalid effect index: $idx (code: $code, desc: $desc)');
  }
  return (codeOut, idx + cardEffectOffset);
}

/// Python `posotion_to_response` (upstream typo kept in the doc only).
int positionToResponse(Position position) {
  switch (position) {
    case Position.faceupAttack:
      return 0x1;
    case Position.facedownAttack:
      return 0x2;
    case Position.faceupDefense:
      return 0x4;
    case Position.facedownDefense:
      return 0x8;
    default:
      throw ArgumentError('Invalid position: $position');
  }
}

/// Python `encode_history_actions`.
///
/// Ring buffer `h_actions`/`ha_p` is unwrapped so the newest action is
/// last, then column 12 is rewritten as the clamped turn diff.
Uint8List encodeHistoryActions(
    Uint8List hActions, int haP, int turn) {
  const rowLen = hActionsFeats;
  final n = nHistoryActions;
  final x = Uint8List(n * rowLen);
  final n1 = n - haP;
  // x[:n1] = h_actions[ha_p:]
  for (var r = 0; r < n1; r++) {
    x.setRange(r * rowLen, (r + 1) * rowLen, hActions, (haP + r) * rowLen);
  }
  // x[n1:] = h_actions[:ha_p]
  for (var r = 0; r < haP; r++) {
    x.setRange((n1 + r) * rowLen, (n1 + r + 1) * rowLen, hActions, r * rowLen);
  }
  // turn_diff = np.minimum(16, turn - x[:, 12]); uint8 wraps mod 256.
  // x[:, 12] = np.where(x[:, 3] != 0, turn_diff, 0)
  for (var r = 0; r < n; r++) {
    final stored = x[r * rowLen + 12];
    final diff = (turn - stored) & 0xFF;
    final turnDiff = diff < 16 ? diff : 16;
    x[r * rowLen + 12] = x[r * rowLen + 3] != 0 ? turnDiff : 0;
  }
  return x;
}

/// Python `HistoryActions`.
class HistoryActions {
  final Uint8List hActions = Uint8List(nHistoryActions * hActionsFeats);
  int haP = 0;

  Uint8List encode(int turn) => encodeHistoryActions(hActions, haP, turn);

  /// [action] is one encoded action row (12 uint8 features).
  void update(Uint8List action, int turn, Phase phase) {
    haP -= 1;
    if (haP < 0) {
      haP = nHistoryActions - 1;
    }
    final base = haP * hActionsFeats;
    for (var i = 0; i < action.length; i++) {
      hActions[base + i] = action[i];
    }
    hActions[base] = 0;
    hActions[base + 12] = turn & 0xFF;
    hActions[base + 13] = phaseToId[phase]!;
  }
}
