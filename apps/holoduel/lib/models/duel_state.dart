import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../fx/fx_engine.dart';
import '../theme/duel_theme.dart';
import 'duel_card.dart';

enum Side { own, foe }

Side otherSide(Side s) => s == Side.own ? Side.foe : Side.own;

enum DuelPhase {
  draw('抽牌', 'DRAW'),
  standby('待机', 'STANDBY'),
  main1('主要1', 'MAIN 1'),
  battle('战斗', 'BATTLE'),
  main2('主要2', 'MAIN 2'),
  end('结束', 'END');

  final String label;
  final String en;
  const DuelPhase(this.label, this.en);
}

enum GameMode { ai, local }

class SideState {
  int lp = 8000;
  final List<DuelCard?> mon = List.filled(5, null);
  final List<DuelCard?> st = List.filled(5, null);
  final List<DuelCard> hand = [];
  final List<DuelCard> deck;
  final List<DuelCard> grave = [];
  bool summoned = false;
  bool buff = false;
  int damageDealt = 0;
  int kills = 0;

  SideState({Random? rng}) : deck = CardDb.buildDeck(rng);

  int get monCount => mon.whereType<DuelCard>().length;
}

class Popup {
  final int id;
  final Side? side;
  final String text;
  final bool good;
  const Popup(this.id, this.side, this.text, this.good);
}

class BannerData {
  final int key;
  final String cn;
  final String en;
  const BannerData(this.key, this.cn, this.en);
}

class TrapPromptData {
  final Side side;
  final DuelCard card;
  final Completer<bool> completer;
  TrapPromptData(this.side, this.card) : completer = Completer<bool>();
}

class RebirthRequest {
  final Side side;
  final List<DuelCard> candidates;
  final Completer<int> completer;
  RebirthRequest(this.side, this.candidates) : completer = Completer<int>();
}

class DuelState extends ChangeNotifier {
  DuelState({FxEngine? fx, Random? rng})
      : fx = fx ?? FxEngine(),
        _rng = rng ?? Random();

  final FxEngine fx;
  final Random _rng;

  GameMode mode = GameMode.ai;
  bool started = false;
  bool over = false;
  bool busy = true;
  Side turn = Side.own;
  DuelPhase phase = DuelPhase.main1;
  int turnN = 0;
  int? selectedZone;
  Side? winner;
  Side? handoffSide;
  BannerData? banner;
  TrapPromptData? trapPrompt;
  RebirthRequest? rebirthRequest;
  DuelCard? previewCard;
  final List<Popup> popups = [];

  SideState own = SideState();
  SideState foe = SideState();
  int _bannerKey = 0;
  int _popupKey = 0;

  SideState side(Side s) => s == Side.own ? own : foe;

  bool isHuman(Side s) => mode == GameMode.local || s == Side.own;

  Side get viewer => mode == GameMode.ai ? Side.own : turn;

  String nameOf(Side s) {
    if (mode == GameMode.ai) {
      return s == Side.own ? '星辰决斗者' : '深渊行者';
    }
    return s == Side.own ? '玩家1' : '玩家2';
  }

  String zoneKey(Side s, String kind, int i) =>
      '${s == Side.own ? 'own' : 'foe'}_${kind}_$i';

  int effAtk(Side s, DuelCard c) => c.atk + (side(s).buff ? 800 : 0);

  Future<void> _sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

  void showBanner(String cn, String en) {
    banner = BannerData(++_bannerKey, cn, en);
    notifyListeners();
  }

  void popup(String text, {Side? side, bool good = false}) {
    popups.add(Popup(++_popupKey, side, text, good));
    notifyListeners();
  }

  void removePopup(int id) {
    popups.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void setPreview(DuelCard? card) {
    previewCard = card;
    notifyListeners();
  }

  Future<void> startGame(GameMode m) async {
    mode = m;
    started = true;
    over = false;
    winner = null;
    busy = true;
    turnN = 0;
    turn = Side.own;
    phase = DuelPhase.main1;
    selectedZone = null;
    handoffSide = null;
    trapPrompt = null;
    rebirthRequest = null;
    previewCard = null;
    popups.clear();
    own = SideState(rng: _rng);
    foe = SideState(rng: _rng);
    for (var i = 0; i < 5; i++) {
      own.hand.add(own.deck.removeLast());
      foe.hand.add(foe.deck.removeLast());
    }
    notifyListeners();
  }

  void reset() {
    started = false;
    over = false;
    winner = null;
    busy = true;
    selectedZone = null;
    previewCard = null;
    popups.clear();
    notifyListeners();
  }

  Future<void> beginFirstTurn() => humanStart(Side.own);

  Future<void> humanStart(Side s) async {
    turn = s;
    if (s == Side.own) turnN++;
    final st = side(s);
    st.summoned = false;
    st.buff = false;
    for (final m in st.mon) {
      m?.used = false;
      m?.posChanged = false;
    }
    selectedZone = null;
    if (mode == GameMode.ai) {
      showBanner(s == Side.own ? '你的回合' : '对手回合',
          s == Side.own ? 'YOUR TURN' : 'OPPONENT TURN');
    } else {
      showBanner('${nameOf(s)} 回合', s == Side.own ? 'PLAYER 1' : 'PLAYER 2');
    }
    phase = DuelPhase.draw;
    notifyListeners();
    await _sleep(950);
    if (!(turnN == 1 && s == Side.own)) await drawCard(s);
    await _sleep(380);
    phase = DuelPhase.standby;
    notifyListeners();
    await _sleep(380);
    phase = DuelPhase.main1;
    notifyListeners();
    busy = false;
  }

  Future<void> drawCard(Side s) async {
    final st = side(s);
    if (st.deck.isEmpty) return;
    st.hand.add(st.deck.removeLast());
    notifyListeners();
  }

  Future<void> endTurn() async {
    if (busy || over || !started) return;
    if (mode == GameMode.ai && turn == Side.foe) return;
    busy = true;
    selectedZone = null;
    previewCard = null;
    notifyListeners();
    if (phase.index <= DuelPhase.main1.index) {
      phase = DuelPhase.battle;
      notifyListeners();
      await _sleep(360);
      phase = DuelPhase.main2;
      notifyListeners();
      await _sleep(360);
    } else if (phase == DuelPhase.battle) {
      phase = DuelPhase.main2;
      notifyListeners();
      await _sleep(360);
    }
    phase = DuelPhase.end;
    notifyListeners();
    await _sleep(300);
    side(turn).buff = false;
    final next = otherSide(turn);
    if (mode == GameMode.ai) {
      await aiTurn();
      if (!over) await humanStart(Side.own);
    } else {
      handoffSide = next;
      notifyListeners();
    }
  }

  Future<void> confirmHandoff() async {
    final s = handoffSide;
    if (s == null) return;
    handoffSide = null;
    notifyListeners();
    await humanStart(s);
  }

  Future<void> playCard(int handIndex, {int? monZone, int? stZone}) async {
    if (busy || over) return;
    if (phase != DuelPhase.main1 && phase != DuelPhase.main2) {
      popup('仅在主要阶段可操作');
      return;
    }
    final s = turn;
    final st = side(s);
    if (handIndex < 0 || handIndex >= st.hand.length) return;
    final card = st.hand[handIndex];
    busy = true;
    if (card.isMonster) {
      if (st.summoned) {
        popup('本回合已通常召唤');
        busy = false;
        return;
      }
      final zi = monZone ?? st.mon.indexOf(null);
      if (zi < 0 || st.mon[zi] != null) {
        busy = false;
        return;
      }
      st.hand.removeAt(handIndex);
      summon(s, zi, card);
      busy = false;
    } else if (card.type == CardType.spell) {
      st.hand.removeAt(handIndex);
      notifyListeners();
      await castSpell(s, card, ai: !isHuman(s));
      busy = false;
    } else {
      final zi = stZone ?? st.st.indexOf(null);
      if (zi < 0 || st.st[zi] != null) {
        busy = false;
        return;
      }
      st.hand.removeAt(handIndex);
      setTrap(s, zi, card);
      busy = false;
    }
  }

  void summon(Side s, int i, DuelCard card, {bool special = false}) {
    card
      ..faceDown = false
      ..position = BattlePosition.attack
      ..used = false
      ..posChanged = false;
    side(s).mon[i] = card;
    if (!special) side(s).summoned = true;
    final key = zoneKey(s, 'mon', i);
    fx
      ..burstAt(key, [DuelTheme.goldHi, DuelTheme.gold], n: 20, pow: 5)
      ..ringAt(key, DuelTheme.goldHi, max: 90);
    notifyListeners();
  }

  void setTrap(Side s, int i, DuelCard card) {
    card.faceDown = true;
    side(s).st[i] = card;
    fx.ringAt(zoneKey(s, 'st', i), DuelTheme.cyan, max: 70);
    notifyListeners();
  }

  Future<void> castSpell(Side s, DuelCard card, {bool ai = false}) async {
    popup('⛓ 连锁发动 ${card.name}');
    fx
      ..ringAt('field_center', DuelTheme.spell, max: 120)
      ..flash(const Color(0x142EE8A0));
    notifyListeners();
    await _sleep(560);
    final st = side(s);
    switch (card.id) {
      case 'solar':
        st.lp += 1500;
        popup('+1500', side: s, good: true);
        fx.pillarAt('plate_${s.name}', [const Color(0xFF5CFFB0), const Color(0xFFB6FFE3)]);
      case 'time':
        await drawCard(s);
        await _sleep(180);
        await drawCard(s);
      case 'obelisk':
        st.buff = true;
        popup('全场 ATK +800');
        for (var i = 0; i < 5; i++) {
          if (st.mon[i] != null) {
            fx.pillarAt(zoneKey(s, 'mon', i), [DuelTheme.goldHi, DuelTheme.gold]);
          }
        }
      case 'voidhole':
        fx
          ..flash(const Color(0x4D783CC8))
          ..ringAt('field_center', const Color(0xFFB45AFF), max: 260);
        popup('◉ 湮灭黑洞 !');
        await _sleep(380);
        for (final sd in Side.values) {
          for (var i = 0; i < 5; i++) {
            if (side(sd).mon[i] != null) await destroyMon(sd, i);
          }
        }
      case 'rebirth':
        final mons = st.grave.where((c) => c.isMonster).toList();
        final zi = st.mon.indexOf(null);
        if (mons.isEmpty) {
          popup('墓地没有怪兽');
        } else if (zi < 0) {
          popup('怪兽区已满');
        } else {
          var idx = -1;
          if (ai) {
            idx = 0;
            for (var i = 1; i < mons.length; i++) {
              if (mons[i].atk > mons[idx].atk) idx = i;
            }
          } else {
            final req = RebirthRequest(s, mons);
            rebirthRequest = req;
            notifyListeners();
            idx = await req.completer.future;
            rebirthRequest = null;
            notifyListeners();
          }
          if (idx >= 0 && idx < mons.length) {
            final m = mons[idx];
            st.grave.remove(m);
            summon(s, zi, m, special: true);
          }
        }
    }
    st.grave.add(card);
    notifyListeners();
  }

  Future<void> destroyMon(Side s, int i) async {
    final st = side(s);
    final card = st.mon[i];
    if (card == null) return;
    st.mon[i] = null;
    side(otherSide(s)).kills++;
    st.grave.add(card);
    final key = zoneKey(s, 'mon', i);
    fx
      ..burstAt(key, [DuelTheme.goldHi, const Color(0xFFFF9A2E), Colors.white], n: 36, pow: 8)
      ..ringAt(key, DuelTheme.goldHi, max: 130)
      ..flash(const Color(0x24FFE9A8));
    notifyListeners();
    await _sleep(520);
  }

  void dealDamage(Side attacker, Side target, int amt) {
    side(target).lp = (side(target).lp - amt).clamp(0, 99999);
    side(attacker).damageDealt += amt;
    popup('-$amt', side: target);
    if (amt >= 2000) fx.shake();
    notifyListeners();
  }

  Color _beamColor(String id) => switch (id) {
        'ra' => DuelTheme.goldHi,
        'serpent' => const Color(0xFFB45AFF),
        'drake' => DuelTheme.cyan,
        'hawk' => const Color(0xFFFFF7AE),
        'wraith' => const Color(0xFFE8C078),
        'crab' => const Color(0xFF78DCFF),
        _ => DuelTheme.goldHi,
      };

  Future<void> attack(Side aSide, int aIdx, int? dIdx) async {
    busy = true;
    selectedZone = null;
    notifyListeners();
    final ast = side(aSide);
    final a = ast.mon[aIdx];
    if (a == null) {
      busy = false;
      return;
    }
    a.used = true;
    final dSide = otherSide(aSide);
    final dst = side(dSide);

    final ti = dst.st.indexWhere((c) => c != null && c.faceDown);
    if (ti > -1) {
      final trapCard = dst.st[ti]!;
      bool act;
      if (isHuman(dSide)) {
        final prompt = TrapPromptData(dSide, trapCard);
        trapPrompt = prompt;
        notifyListeners();
        act = await prompt.completer.future;
        trapPrompt = null;
        notifyListeners();
      } else {
        await _sleep(500);
        act = _rng.nextDouble() < 0.85;
      }
      if (act) {
        trapCard.faceDown = false;
        notifyListeners();
        popup('⛓ ${trapCard.name} 发动 !');
        fx
          ..burstAt(zoneKey(dSide, 'st', ti), [DuelTheme.trap, const Color(0xFFFFB6EF)], n: 24, pow: 6)
          ..flash(const Color(0x29E84BD8));
        await _sleep(700);
        dst.st[ti] = null;
        dst.grave.add(trapCard);
        if (trapCard.id == 'scarab') {
          popup('⬡ 攻击无效 !');
          notifyListeners();
          busy = false;
          checkEnd();
          return;
        }
        if (trapCard.id == 'quicksand') {
          popup('◍ 流沙咒缚 !');
          await destroyMon(aSide, aIdx);
          busy = false;
          checkEnd();
          return;
        }
      }
    }

    final fromKey = zoneKey(aSide, 'mon', aIdx);
    if (dIdx == null) {
      final toKey = 'plate_${dSide.name}';
      fx.beam(fromKey, toKey, _beamColor(a.id));
      await _sleep(220);
      dealDamage(aSide, dSide, effAtk(aSide, a));
      final p = fx.anchor(toKey);
      if (p != null) fx.ring(p, DuelTheme.crimson, max: 120);
    } else {
      final d = dst.mon[dIdx];
      if (d == null) {
        busy = false;
        return;
      }
      final toKey = zoneKey(dSide, 'mon', dIdx);
      fx.beam(fromKey, toKey, _beamColor(a.id));
      await _sleep(220);
      var aDead = false;
      var dDead = false;
      Side? lpSide;
      var lpDmg = 0;
      final atkA = effAtk(aSide, a);
      final atkD = effAtk(dSide, d);
      if (d.position == BattlePosition.defense) {
        if (atkA > d.def) {
          dDead = true;
        } else if (atkA < d.def) {
          lpSide = aSide;
          lpDmg = d.def - atkA;
        }
      } else {
        if (atkA > atkD) {
          dDead = true;
          lpSide = dSide;
          lpDmg = atkA - atkD;
        } else if (atkA < atkD) {
          aDead = true;
          lpSide = aSide;
          lpDmg = atkD - atkA;
        } else {
          aDead = true;
          dDead = true;
        }
      }
      if (lpSide != null) dealDamage(aSide, lpSide, lpDmg);
      if (dDead) await destroyMon(dSide, dIdx);
      if (aDead) await destroyMon(aSide, aIdx);
    }
    await _sleep(400);
    busy = false;
    checkEnd();
  }

  void checkEnd() {
    if (over) return;
    if (foe.lp <= 0) {
      over = true;
      winner = Side.own;
      notifyListeners();
    } else if (own.lp <= 0) {
      over = true;
      winner = Side.foe;
      notifyListeners();
    }
  }

  void selectMonster(int i) {
    if (busy || over || phase != DuelPhase.battle) return;
    final m = side(turn).mon[i];
    if (m == null) return;
    if (m.used) {
      popup('该怪兽本回合已攻击');
      return;
    }
    selectedZone = selectedZone == i ? null : i;
    notifyListeners();
  }

  void attackTarget(int dIdx) {
    final sel = selectedZone;
    if (sel == null || busy || over) return;
    attack(turn, sel, dIdx);
  }

  void directAttack() {
    final sel = selectedZone;
    if (sel == null || busy || over) return;
    if (side(otherSide(turn)).mon.any((c) => c != null)) {
      popup('对方场上有怪兽,请选择目标');
      return;
    }
    attack(turn, sel, null);
  }

  void togglePosition(int i) {
    if (busy || over) return;
    if (phase != DuelPhase.main1 && phase != DuelPhase.main2) return;
    final m = side(turn).mon[i];
    if (m == null || m.posChanged) return;
    m.posChanged = true;
    m.position = m.position == BattlePosition.attack
        ? BattlePosition.defense
        : BattlePosition.attack;
    notifyListeners();
  }

  Future<void> aiTurn() async {
    turn = Side.foe;
    notifyListeners();
    showBanner('对手回合', 'OPPONENT TURN');
    phase = DuelPhase.draw;
    notifyListeners();
    await _sleep(900);
    await drawCard(Side.foe);
    await _sleep(380);
    phase = DuelPhase.standby;
    notifyListeners();
    await _sleep(380);
    phase = DuelPhase.main1;
    notifyListeners();
    await _sleep(420);

    final h = foe.hand;
    DuelCard? take(String id) {
      final i = h.indexWhere((c) => c.id == id);
      return i > -1 ? h.removeAt(i) : null;
    }

    DuelCard? c;
    if (foe.lp <= 4200 && _rng.nextDouble() < .7) {
      c = take('solar');
      if (c != null) {
        await castSpell(Side.foe, c, ai: true);
        await _sleep(520);
      }
    }
    if (foe.monCount >= 2 && !foe.buff && _rng.nextDouble() < .6) {
      c = take('obelisk');
      if (c != null) {
        await castSpell(Side.foe, c, ai: true);
        await _sleep(520);
      }
    }
    if (own.monCount >= 2 && foe.monCount <= 1 && _rng.nextDouble() < .5) {
      c = take('voidhole');
      if (c != null) {
        await castSpell(Side.foe, c, ai: true);
        await _sleep(620);
      }
    }
    if (foe.grave.any((g) => g.isMonster) &&
        foe.mon.contains(null) &&
        _rng.nextDouble() < .55) {
      c = take('rebirth');
      if (c != null) {
        await castSpell(Side.foe, c, ai: true);
        await _sleep(520);
      }
    }

    final zi = foe.mon.indexOf(null);
    final mons = h.where((x) => x.isMonster).toList();
    if (zi > -1 && mons.isNotEmpty && !foe.summoned) {
      mons.sort((x, y) => y.atk.compareTo(x.atk));
      final best = mons.first;
      h.remove(best);
      summon(Side.foe, zi, best);
      await _sleep(760);
    }
    final sti = foe.st.indexOf(null);
    final traps = h.where((x) => x.type == CardType.trap).toList();
    if (sti > -1 && traps.isNotEmpty && _rng.nextDouble() < .4) {
      h.remove(traps.first);
      setTrap(Side.foe, sti, traps.first);
      await _sleep(460);
    }

    phase = DuelPhase.battle;
    notifyListeners();
    await _sleep(430);
    for (final m in foe.mon) {
      m?.used = false;
      m?.posChanged = false;
    }
    for (var i = 0; i < 5; i++) {
      if (over) return;
      final m = foe.mon[i];
      if (m == null || m.used) continue;
      final targets = <int>[];
      for (var j = 0; j < 5; j++) {
        if (own.mon[j] != null) targets.add(j);
      }
      int? dIdx;
      if (targets.isNotEmpty) {
        targets.sort((x, y) =>
            effAtk(Side.own, own.mon[x]!).compareTo(effAtk(Side.own, own.mon[y]!)));
        final w = own.mon[targets.first]!;
        final wPower =
            w.position == BattlePosition.defense ? w.def : effAtk(Side.own, w);
        if (effAtk(Side.foe, m) > wPower || _rng.nextDouble() < .22) {
          dIdx = targets.first;
        }
      }
      if (dIdx != null) {
        await attack(Side.foe, i, dIdx);
        await _sleep(430);
      } else if (targets.isEmpty) {
        await attack(Side.foe, i, null);
        await _sleep(430);
      }
    }
    if (over) return;
    phase = DuelPhase.main2;
    notifyListeners();
    await _sleep(360);
    phase = DuelPhase.end;
    notifyListeners();
    await _sleep(300);
    foe.buff = false;
    notifyListeners();
  }

  @override
  void dispose() {
    fx.dispose();
    super.dispose();
  }
}
