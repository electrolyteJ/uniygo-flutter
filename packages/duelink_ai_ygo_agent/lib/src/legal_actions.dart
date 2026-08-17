/// `get_legal_actions`, ported 1:1 from ygo-agent `ygoinf/features.py`.
///
/// The select_sum branch depends on CPython `set` iteration order
/// (`next(iter(c))` picks the representative card of each combination).
/// [PyIntSet] simulates CPython 3.11 `setobject.c` for small non-negative
/// ints so the Dart side produces actions in the exact same order.
library;

import 'code_list.dart';
import 'enums.dart';
import 'features.dart';
import 'models.dart';

/// Raised where upstream raises `NotImplementedError` (unsupported msg
/// shapes; the duel engine should fall back to the rule-based AI).
class NotSupportedException implements Exception {
  NotSupportedException(this.message);
  final String message;
  @override
  String toString() => 'NotSupportedException: $message';
}

// ─────────────────────────────────────────────────────────────────────
// PyIntSet: CPython 3.11 set simulation for small non-negative ints.
//
// Line-by-line port of Objects/setobject.c (v3.11) probing semantics:
//  - hash(n) = n; table starts at PySet_MINSIZE (8), open addressing
//  - set_add_entry/set_lookkey probe: per outer iteration, a do-while
//    run checking `probes + 1` slots (probes = LINEAR_PROBES (9) when
//    i + 9 <= mask, else 0), then perturb >>= 5; i = (i*5+1+perturb)&mask
//  - inserts prefer the LAST dummy seen on the probe path, else the
//    empty slot; growth only when an empty slot is used and
//    fill*5 >= mask*3, to the first power of two > used*4
//  - set_insert_clean (rehash/merge): check slot i then the 9 slots
//    after it, then perturb from the original i
//  - removals leave dummy slots (fill unchanged); resize away dummies
//    when fill-used > mask/4 after a difference_update
//  - set(list): generic-iterator build — plain incremental inserts, no
//    pre-sizing
//  - copy() = set_merge into an empty set: pre-resize to first power of
//    two > 2*used when used*5 >= mask*3, then verbatim copy (same mask,
//    no dummies) or insert-clean rehash in slot order
//  - `c - selected`: (len(c) >> 2) > len(selected) -> copy+discard,
//    else fresh set inserting c's elements in iteration order
// Verified against real CPython 3.11 output in pysim_golden_test.dart.
// ─────────────────────────────────────────────────────────────────────

class PyIntSet {
  static const int _minSize = 8;
  static const int _linearProbes = 9;
  static const int _perturbShift = 5;

  // Slot states: 0 = empty, 1 = active, 2 = dummy.
  List<int> _key = List<int>.filled(_minSize, 0);
  List<int> _state = List<int>.filled(_minSize, 0);
  int _mask = _minSize - 1;
  int used = 0;
  int _fill = 0;

  PyIntSet();

  /// `set(iterable)` — inserts in iteration order of [values].
  PyIntSet.of(Iterable<int> values) {
    for (final v in values) {
      add(v);
    }
  }

  /// `set()` literal.
  PyIntSet.empty();

  bool contains(int key) {
    final slot = _findSlot(key);
    return _state[slot] == 1;
  }

  /// `set.add` — port of `set_add_entry`. Growth check only on the
  /// empty-slot path (`found_unused`); reusing a dummy slot never grows.
  bool add(int key) {
    final slot = _findSlot(key);
    if (_state[slot] == 1) {
      return false; // found_active
    }
    final wasEmpty = _state[slot] == 0;
    _key[slot] = key;
    _state[slot] = 1;
    used++;
    if (wasEmpty) {
      _fill++;
      if (_fill * 5 >= _mask * 3) {
        _resize(used * 4);
      }
    }
    return true;
  }

  /// Slot of [key] if active; otherwise the slot where an insert would go
  /// (last dummy seen on the probe path, else the empty slot terminating
  /// the probe). Faithful port of the shared probing in `set_lookkey` /
  /// `set_add_entry`: each outer iteration re-evaluates whether a linear
  /// run fits, and the do-while with post-decrement `probes--` inspects
  /// `probes + 1` slots.
  int _findSlot(int key) {
    var i = key & _mask; // hash(n) == n for small non-negative ints
    int? freeslot;
    var perturb = key;
    while (true) {
      var idx = i;
      final probes = (i + _linearProbes <= _mask) ? _linearProbes : 0;
      // do { ... entry++; } while (probes--); — checks i .. i + probes.
      for (var p = 0; p <= probes; p++) {
        switch (_state[idx]) {
          case 0: // empty
            return freeslot ?? idx;
          case 1: // active
            if (_key[idx] == key) {
              return idx;
            }
          default: // dummy
            // No NULL guard upstream: the last dummy wins.
            freeslot = idx;
        }
        idx++;
      }
      perturb >>= _perturbShift;
      i = (i * 5 + 1 + perturb) & _mask;
    }
  }

  /// `set_table_resize` — smallest power-of-two size strictly greater than
  /// [minUsed]; rehashes active entries with [_insertClean] in old slot
  /// order, dropping dummies (fill = used afterwards).
  void _resize(int minUsed) {
    var newSize = _minSize;
    while (newSize <= minUsed) {
      newSize <<= 1;
    }
    final oldKey = _key;
    final oldState = _state;
    _key = List<int>.filled(newSize, 0);
    _state = List<int>.filled(newSize, 0);
    _mask = newSize - 1;
    _fill = 0;
    used = 0;
    for (var s = 0; s < oldKey.length; s++) {
      if (oldState[s] == 1) {
        _insertClean(oldKey[s]);
        _fill++;
        used++;
      }
    }
  }

  /// `set_insert_clean` — probe for an empty slot in a table known not to
  /// contain [key] or dummies: check slot i, then the LINEAR_PROBES slots
  /// after it (only when the run fits), then perturb from the original i.
  void _insertClean(int key) {
    var i = key & _mask;
    var perturb = key;
    while (true) {
      if (_state[i] == 0) {
        _key[i] = key;
        _state[i] = 1;
        return;
      }
      if (i + _linearProbes <= _mask) {
        for (var j = 1; j <= _linearProbes; j++) {
          if (_state[i + j] == 0) {
            _key[i + j] = key;
            _state[i + j] = 1;
            return;
          }
        }
      }
      perturb >>= _perturbShift;
      i = (i * 5 + 1 + perturb) & _mask;
    }
  }

  /// `set.discard(key)` — port of `set_discard_entry`: marks the slot as
  /// dummy (state 2), leaving fill unchanged.
  void discard(int key) {
    final slot = _findSlot(key);
    if (_state[slot] == 1) {
      _state[slot] = 2;
      used--;
    }
  }

  /// Iteration order: slot scan, skipping empty and dummy slots.
  Iterable<int> iter() sync* {
    for (var s = 0; s < _key.length; s++) {
      if (_state[s] == 1) {
        yield _key[s];
      }
    }
  }

  /// `next(iter(set))` — first element in iteration order.
  int firstIter() {
    for (final v in iter()) {
      return v;
    }
    throw StateError('iter() of empty set');
  }

  /// `==` — same size and every element of the smaller set in the larger.
  @override
  bool operator ==(Object other) {
    if (other is! PyIntSet) return false;
    if (used != other.used) return false;
    final smaller = used <= other.used ? this : other;
    final larger = identical(smaller, this) ? other : this;
    for (final v in smaller.iter()) {
      if (!larger.contains(v)) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var h = used;
    for (final v in iter()) {
      h ^= v * 0x9E3779B1;
    }
    return h;
  }

  /// `set.copy()` — port of `set_copy` -> `make_new_set(type, so)` ->
  /// `set_merge(empty, this)`: one up-front resize to the first power of
  /// two strictly greater than `2*used` (when `used*5 >= mask*3`), then
  /// either a verbatim table copy (same mask, no dummies) or a rehash via
  /// [_insertClean] in slot order.
  PyIntSet copy() {
    final s = PyIntSet.empty();
    if (used == 0) {
      return s;
    }
    if ((s._fill + used) * 5 >= s._mask * 3) {
      s._resize((s.used + used) * 2);
    }
    if (s._fill == 0 && s._mask == _mask && _fill == used) {
      s._key = List<int>.of(_key);
      s._state = List<int>.of(_state);
      s.used = used;
      s._fill = _fill;
      return s;
    }
    s._fill = used;
    s.used = used;
    for (var i = 0; i < _key.length; i++) {
      if (_state[i] == 1) {
        s._insertClean(_key[i]);
      }
    }
    return s;
  }

  /// `this - other` — port of `set_difference` with CPython's size-based
  /// strategy choice.
  PyIntSet difference(PyIntSet other) {
    if ((used >> 2) > other.used) {
      // set_copy_and_difference: copy, then discard other's elements.
      final result = copy();
      for (final v in other.iter()) {
        result.discard(v);
      }
      // "If more than 1/4th are dummies, then resize them away."
      // (The `(len(other) >> 3) > len(result)` intersection shortcut is
      // unreachable here: the copy path implies other.used < used/4.)
      if ((result._fill - result.used) > result._mask ~/ 4) {
        result._resize(result.used * 4);
      }
      return result;
    }
    // Fresh empty set; insert elements not in other, in iteration order
    // (normal set_add_entry growth along the way).
    final result = PyIntSet.empty();
    for (final v in iter()) {
      if (!other.contains(v)) {
        result.add(v);
      }
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────
// select_sum combination helpers
// ─────────────────────────────────────────────────────────────────────

/// Python `sum_to2`. [weights] is per-card level lists; [ind] the chosen
/// card indices; checks whether the remaining sum [r] is reachable picking
/// one level from each remaining card.
bool sumTo2(List<List<int>> weights, List<int> ind, int r) =>
    _sumTo2Helper(weights, ind, 0, r);

bool _sumTo2Helper(List<List<int>> w, List<int> ind, int i, int r) {
  if (r <= 0) {
    return false;
  }
  final n = ind.length;
  final wI = w[ind[i]];
  if (i == n - 1) {
    if (wI.length == 1) {
      return wI[0] == r;
    } else {
      return wI[0] == r || wI[1] == r;
    }
  }
  if (wI.length == 1) {
    return _sumTo2Helper(w, ind, i + 1, r - wI[0]);
  } else {
    return _sumTo2Helper(w, ind, i + 1, r - wI[0]) ||
        _sumTo2Helper(w, ind, i + 1, r - wI[1]);
  }
}

/// Python `itertools.combinations(range(n), k)` in lexicographic order.
Iterable<List<int>> _combinations(int n, int k) sync* {
  if (k > n) return;
  final indices = List<int>.generate(k, (i) => i);
  final pool = List<int>.generate(n, (i) => i);
  yield [for (final i in indices) pool[i]];
  while (true) {
    var i = k - 1;
    while (i >= 0 && indices[i] == i + n - k) {
      i--;
    }
    if (i < 0) return;
    indices[i] += 1;
    for (var j = i + 1; j < k; j++) {
      indices[j] = indices[j - 1] + 1;
    }
    yield [for (final idx in indices) pool[idx]];
  }
}

/// Python `combinations_with_weight2`: all index subsets (k = 1..n) whose
/// two-choice weights can sum to [r].
List<PyIntSet> combinationsWithWeight2(List<List<int>> weights, int r) {
  final n = weights.length;
  final results = <PyIntSet>[];
  for (var k = 1; k <= n; k++) {
    for (final comb in _combinations(n, k)) {
      if (sumTo2(weights, comb, r)) {
        results.add(PyIntSet.of(comb));
      }
    }
  }
  return results;
}

// ─────────────────────────────────────────────────────────────────────
// get_legal_actions
// ─────────────────────────────────────────────────────────────────────

/// Python `get_legal_actions`. Throws [NotSupportedException] exactly where
/// upstream raises `NotImplementedError`.
List<LegalAction> getLegalActions(ActionMsg actionMsg, CodeList codeList) {
  final data = actionMsg.data;
  final actions = <LegalAction>[];

  switch (data) {
    case MsgSelectIdleCmd msg:
      for (final cmd in msg.idleCmds) {
        final action = LegalAction(msg: MsgName.selectIdlecmd);
        if (cmd.data != null) {
          action.response = cmd.data!.response;
          action.spec = cardInfoToSpec(cmd.data!.cardInfo);
        }
        switch (cmd.cmdType) {
          case IdleCmdType.summon:
            action.act = ActionAct.summonFaceupAttack;
          case IdleCmdType.spSummon:
            action.act = ActionAct.specialSummon;
          case IdleCmdType.reposition:
            action.act = ActionAct.reposition;
          case IdleCmdType.mset:
            action.act = ActionAct.summonFacedownDefense;
          case IdleCmdType.set:
            action.act = ActionAct.set;
          case IdleCmdType.activate:
            final desc = cmd.data!.effectDescription;
            var code = cmd.data!.cardInfo.code;
            if ((code & 0x80000000) != 0) {
              code &= 0x7FFFFFFF;
            }
            var (codeD, effIdx) = unpackDesc(code, desc);
            if (desc == 0) {
              codeD = code;
            }
            action.act = ActionAct.activate;
            action.spec = cardInfoToSpec(cmd.data!.cardInfo);
            action.effect = effIdx;
            if (codeD != 0) {
              action.cardId = codeList.idOf(codeD);
            }
          case IdleCmdType.toBp:
            action.phase = ActionPhase.battle;
            action.response = 6;
          case IdleCmdType.toEp:
            action.phase = ActionPhase.end;
            action.response = 7;
        }
        actions.add(action);
      }
    case MsgSelectChain msg:
      for (final chain in msg.chains) {
        final action = LegalAction(msg: MsgName.selectChain);
        action.response = chain.response;
        final code = chain.code;
        final desc = chain.effectDescription;
        var (codeD, effIdx) = unpackDesc(code, desc);
        if (desc == 0) {
          codeD = code;
        }
        action.act = ActionAct.activate;
        action.spec = toSpec(chain.location);
        action.effect = effIdx;
        if (codeD != 0) {
          action.cardId = codeList.idOf(codeD);
        }
        actions.add(action);
      }
      if (!msg.forced) {
        final action = LegalAction(msg: MsgName.selectChain);
        action.response = -1;
        action.act = ActionAct.cancel;
        actions.add(action);
      }
    case MsgSelectPosition msg:
      for (final pos in msg.positions) {
        final action = LegalAction(msg: MsgName.selectPosition);
        action.position = pos;
        action.response = positionToResponse(pos);
        actions.add(action);
      }
    case MsgSelectYesNo msg:
      final desc = msg.effectDescription;
      var (code, effIdx) = unpackDesc(0, desc);
      if (desc == 0) {
        throw ArgumentError('Unknown desc $desc in select_yesno');
      }
      final yes = LegalAction(msg: MsgName.selectYesno);
      yes.response = 1;
      yes.act = ActionAct.activate;
      yes.effect = effIdx;
      if (code != 0) {
        yes.cardId = codeList.idOf(code);
      }
      actions.add(yes);

      final no = LegalAction(msg: MsgName.selectYesno);
      no.response = 0;
      no.act = ActionAct.cancel;
      actions.add(no);
    case MsgSelectEffectYn msg:
      final yes = LegalAction(msg: MsgName.selectEffectyn);
      yes.response = 1;
      final code = msg.code;
      final desc = msg.effectDescription;
      var (codeD, effIdx) = unpackDesc(code, desc);
      if (desc == 0) {
        codeD = code;
      }
      yes.act = ActionAct.activate;
      yes.spec = toSpec(msg.location);
      yes.effect = effIdx;
      if (codeD != 0) {
        yes.cardId = codeList.idOf(codeD);
      }
      actions.add(yes);

      final no = LegalAction(msg: MsgName.selectEffectyn);
      no.response = 0;
      no.act = ActionAct.cancel;
      actions.add(no);
    case MsgSelectBattleCmd msg:
      for (final cmd in msg.battleCmds) {
        final action = LegalAction(msg: MsgName.selectBattlecmd);
        if (cmd.data != null) {
          action.spec = cardInfoToSpec(cmd.data!.cardInfo);
          action.response = cmd.data!.response;
        }
        switch (cmd.cmdType) {
          case BattleCmdType.activate:
            action.act = ActionAct.activate;
            var codeT = cmd.data!.cardInfo.code;
            final desc = cmd.data!.effectDescription;
            final code = codeT;
            if ((codeT & 0x80000000) != 0) {
              codeT &= 0x7FFFFFFF;
            }
            var (codeD, effIdx) = unpackDesc(codeT, desc);
            if (desc == 0) {
              codeD = code;
            }
            action.effect = effIdx;
            if (codeD != 0) {
              action.cardId = codeList.idOf(codeD);
            }
          case BattleCmdType.attack:
            if (cmd.data!.directAttackable) {
              action.act = ActionAct.directAttack;
            } else {
              action.act = ActionAct.attack;
            }
          case BattleCmdType.toM2:
            action.phase = ActionPhase.main2;
            action.response = 2;
          case BattleCmdType.toEp:
            action.response = 3;
            action.phase = ActionPhase.end;
        }
        actions.add(action);
      }
    case MsgSelectOption msg:
      for (final option in msg.options) {
        final desc = option.code;
        var (code, effIdx) = unpackDesc(0, desc);
        if (desc == 0) {
          throw ArgumentError('Unknown desc $desc in select_option');
        }
        final action = LegalAction(msg: MsgName.selectOption);
        action.response = option.response;
        action.act = ActionAct.activate;
        action.effect = effIdx;
        if (code != 0) {
          action.cardId = codeList.idOf(code);
        }
        actions.add(action);
      }
    case MsgSelectPlace msg:
      for (var i = 0; i < msg.places.length; i++) {
        final action = LegalAction(msg: MsgName.selectPlace);
        action.response = i;
        action.place = placeToSelect(msg.places[i]);
        actions.add(action);
      }
    case MsgSelectDisfield msg:
      for (final place in msg.places) {
        final action = LegalAction(msg: MsgName.selectDisfield);
        action.response = -1;
        action.place = placeToSelect(place);
        actions.add(action);
      }
    case MsgAnnounceAttrib msg:
      if (msg.count != 1) {
        throw NotSupportedException(
            'Multiple attributes are not supported.');
      }
      for (final attrib in msg.attributes) {
        final action = LegalAction(msg: MsgName.announceAttrib);
        action.response = attrib.response;
        action.attribute = attrib.attribute;
        actions.add(action);
      }
    case MsgAnnounceNumber msg:
      if (msg.count != 1) {
        throw NotSupportedException('Multiple numbers are not supported.');
      }
      for (final number in msg.numbers) {
        // NOTE(uniygo-golden): upstream bug fix. Original compared the
        // AnnounceNumber object to an int (TypeError). See golden manifest
        // vendor_patches.
        if (number.number <= 0 || number.number > 12) {
          throw NotSupportedException(
              'Number out of range, only 1-12 are supported.');
        }
        final action = LegalAction(msg: MsgName.announceNumber);
        action.response = number.response;
        action.number = number.number;
        actions.add(action);
      }
    case MsgSelectUnselectCard msg:
      for (final card in msg.selectableCards) {
        final action = LegalAction(msg: MsgName.selectUnselectCard);
        action.response = card.response;
        action.spec = toSpec(card.location);
        actions.add(action);
      }
      if (msg.finishable) {
        final action = LegalAction(msg: MsgName.selectUnselectCard);
        action.response = -1;
        action.finish = true;
        actions.add(action);
      }
    case MsgSelectCard msg:
      if (msg.min == 0) {
        throw NotSupportedException('min=0 is not supported.');
      }
      _selectCardOrTribute(
        actions,
        msgName: MsgName.selectCard,
        min: msg.min,
        max: msg.max,
        specs: [for (final c in msg.cards) toSpec(c.location)],
        responses: [for (final c in msg.cards) c.response],
        selected: msg.selected,
        tributeCheck: null,
      );
    case MsgSelectTribute msg:
      if (msg.min == 0) {
        throw NotSupportedException(
            'min=0 is not supported for select_tribute.');
      }
      if (msg.min != msg.max) {
        throw NotSupportedException(
            'min != max is not supported for select_tribute.');
      }
      for (final c in msg.cards) {
        if (c.level != 1) {
          throw NotSupportedException(
              'Only level=1 cards are supported for select_tribute.');
        }
      }
      _selectCardOrTribute(
        actions,
        msgName: MsgName.selectTribute,
        min: msg.min,
        max: msg.max,
        specs: [for (final c in msg.cards) toSpec(c.location)],
        responses: [for (final c in msg.cards) c.response],
        selected: msg.selected,
        tributeCheck: null,
      );
    case MsgSelectSum msg:
      _selectSum(actions, msg, codeList);
  }
  return actions;
}

void _selectCardOrTribute(
  List<LegalAction> actions, {
  required MsgName msgName,
  required int min,
  required int max,
  required List<String> specs,
  required List<int> responses,
  required List<int> selected,
  required Object? tributeCheck, // unused; keeps call sites explicit
}) {
  final idx = selected.length;
  for (var i = 0; i < specs.length; i++) {
    if (!selected.contains(i)) {
      final action = LegalAction(msg: msgName);
      action.response = responses[i];
      action.spec = specs[i];
      actions.add(action);
    }
  }
  if ((idx == max - 1 && idx >= min) || idx >= min) {
    final action = LegalAction(msg: msgName);
    action.response = -1;
    action.finish = true;
    actions.add(action);
  }
}

void _selectSum(
    List<LegalAction> actions, MsgSelectSum msg, CodeList codeList) {
  if (msg.overflow) {
    throw NotSupportedException('overflow is not supported for select_sum.');
  } else if (msg.mustCards.length > 2) {
    throw NotSupportedException(
        'must select more than 2 cards is not supported for select_sum.');
  }
  var levelSum = msg.levelSum;
  for (final c in msg.mustCards) {
    levelSum -= c.level1;
  }
  final cardLevels = <List<int>>[];
  for (final c in msg.cards) {
    final levels = <int>[];
    if (c.level1 > 0) {
      levels.add(c.level1);
    }
    if (c.level2 > 0 && c.level2 != c.level1) {
      levels.add(c.level2);
    }
    cardLevels.add(levels);
  }
  // Upstream dict insertion order decides the action order; the
  // representative card of each combination is `next(iter(c))` under
  // CPython set semantics (simulated by PyIntSet).
  for (final (i, f) in selectSumActionOrder(cardLevels, levelSum, msg.selected)) {
    final action = LegalAction(msg: MsgName.selectTribute);
    final c = msg.cards[i];
    action.response = c.response;
    action.spec = toSpec(c.location);
    action.canFinish = f;
    actions.add(action);
  }
}

/// Python `selected.issubset(c)` — equivalent to upstream's
/// `c.intersection(selected) == selected`.
bool _isSubset(PyIntSet subset, PyIntSet of) {
  for (final v in subset.iter()) {
    if (!of.contains(v)) {
      return false;
    }
  }
  return true;
}

/// The select_sum combination pipeline, factored out for golden testing:
/// combinations_with_weight2 -> filter by selected -> dedupe ->
/// (card_index, can_finish) in upstream dict insertion order.
List<(int, bool)> selectSumActionOrder(
    List<List<int>> cardLevels, int levelSum, List<int> selectedList) {
  var combs = combinationsWithWeight2(cardLevels, levelSum);
  // Find combinations containing selected.
  final selected = PyIntSet.of(selectedList);
  combs = [
    for (final c in combs)
      if (_isSubset(selected, c)) c.difference(selected),
  ];
  // Deduplicate.
  final combs2 = <PyIntSet>[];
  for (final c in combs) {
    if (!combs2.contains(c)) {
      combs2.add(c);
    }
  }
  if (combs2.contains(PyIntSet.empty())) {
    throw NotSupportedException('empty select in select_sum.');
  }
  final canFinish = <int, bool>{};
  for (final c in combs2) {
    final i = c.firstIter();
    final f = c.used == 1;
    canFinish[i] = (canFinish[i] ?? false) || f;
  }
  return [
    for (final e in canFinish.entries) (e.key, e.value),
  ];
}
