import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'duel_card.dart';

enum Side { own, foe }

Side otherSide(Side s) => s == Side.own ? Side.foe : Side.own;

enum DuelPhase {
  draw('抽牌阶段', 'DRAW PHASE'),
  standby('待机阶段', 'STANDBY PHASE'),
  main1('主要阶段1', 'MAIN PHASE 1'),
  battle('战斗阶段', 'BATTLE PHASE'),
  main2('主要阶段2', 'MAIN PHASE 2'),
  end('结束阶段', 'END PHASE');

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

  SideState({Random? rng}) : deck = CardDb.buildDeck(rng);

  int get monCount => mon.whereType<DuelCard>().length;
}

class BannerData {
  final int key;
  final String cn;
  final String en;
  const BannerData(this.key, this.cn, this.en);
}

class DuelState extends ChangeNotifier {
  DuelState({Random? rng}) : _rng = rng ?? Random();

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
  BannerData? banner;
  DuelCard? previewCard;
  String? lastAction;

  SideState own = SideState();
  SideState foe = SideState();
  int _bannerKey = 0;

  SideState side(Side s) => s == Side.own ? own : foe;

  bool isHuman(Side s) => mode == GameMode.local || s == Side.own;

  String nameOf(Side s) {
    if (mode == GameMode.ai) {
      return s == Side.own ? '决斗者' : 'AI对手';
    }
    return s == Side.own ? '玩家1' : '玩家2';
  }

  Future<void> _sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

  void showBanner(String cn, String en) {
    banner = BannerData(++_bannerKey, cn, en);
    notifyListeners();
  }

  void action(String text) {
    lastAction = text;
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
    previewCard = null;
    lastAction = null;
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
    lastAction = null;
    notifyListeners();
  }

  Future<void> beginFirstTurn() => humanStart(Side.own);

  Future<void> humanStart(Side s) async {
    turn = s;
    if (s == Side.own) turnN++;
    final st = side(s);
    st.summoned = false;
    for (final m in st.mon) {
      m?.used = false;
      m?.posChanged = false;
    }
    selectedZone = null;
    showBanner(
      mode == GameMode.ai
          ? (s == Side.own ? '你的回合' : '对手回合')
          : '${nameOf(s)} 回合',
      s == Side.own ? 'YOUR TURN' : 'OPPONENT TURN',
    );
    phase = DuelPhase.draw;
    notifyListeners();
    await _sleep(900);
    if (!(turnN == 1 && s == Side.own)) await drawCard(s);
    await _sleep(350);
    phase = DuelPhase.standby;
    notifyListeners();
    await _sleep(350);
    phase = DuelPhase.main1;
    notifyListeners();
    busy = false;
  }

  Future<void> drawCard(Side s) async {
    final st = side(s);
    if (st.deck.isEmpty) return;
    st.hand.add(st.deck.removeLast());
    action('${nameOf(s)} 抽了一张牌');
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
      await _sleep(320);
      phase = DuelPhase.main2;
      notifyListeners();
      await _sleep(320);
    } else if (phase == DuelPhase.battle) {
      phase = DuelPhase.main2;
      notifyListeners();
      await _sleep(320);
    }
    phase = DuelPhase.end;
    notifyListeners();
    await _sleep(280);
    final next = otherSide(turn);
    if (mode == GameMode.ai) {
      await aiTurn();
      if (!over) await humanStart(Side.own);
    } else {
      await humanStart(next);
    }
  }

  Future<void> playCard(int handIndex, {int? monZone, int? stZone}) async {
    if (busy || over) return;
    if (phase != DuelPhase.main1 && phase != DuelPhase.main2) {
      action('仅在主要阶段可操作');
      return;
    }
    final s = turn;
    final st = side(s);
    if (handIndex < 0 || handIndex >= st.hand.length) return;
    final card = st.hand[handIndex];
    busy = true;
    if (card.isMonster) {
      if (st.summoned) {
        action('本回合已通常召唤');
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
      await castSpell(s, card);
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
    action('${card.name} ${special ? "特殊召唤" : "召唤"}!');
    notifyListeners();
  }

  void setTrap(Side s, int i, DuelCard card) {
    card.faceDown = true;
    side(s).st[i] = card;
    action('盖放了一张卡');
    notifyListeners();
  }

  Future<void> castSpell(Side s, DuelCard card) async {
    action('发动 ${card.name}');
    notifyListeners();
    await _sleep(500);
    final st = side(s);
    switch (card.id) {
      case 'pot':
        await drawCard(s);
        await _sleep(150);
        await drawCard(s);
      case 'darkhole':
        action('黑洞! 全场怪兽破坏!');
        await _sleep(350);
        for (final sd in Side.values) {
          for (var i = 0; i < 5; i++) {
            if (side(sd).mon[i] != null) await destroyMon(sd, i);
          }
        }
      case 'monsterreborn':
        final mons = st.grave.where((c) => c.isMonster).toList();
        final zi = st.mon.indexOf(null);
        if (mons.isNotEmpty && zi >= 0) {
          var idx = 0;
          for (var i = 1; i < mons.length; i++) {
            if (mons[i].atk > mons[idx].atk) idx = i;
          }
          final m = mons[idx];
          st.grave.remove(m);
          summon(s, zi, m, special: true);
        }
      case 'mystical':
        final ost = side(otherSide(s));
        final ti = ost.st.indexWhere((c) => c != null);
        if (ti >= 0) {
          final t = ost.st[ti]!;
          ost.st[ti] = null;
          ost.grave.add(t);
          action('破坏 ${t.name}');
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
    st.grave.add(card);
    action('${card.name} 被破坏!');
    notifyListeners();
    await _sleep(480);
  }

  void dealDamage(Side attacker, Side target, int amt) {
    side(target).lp = (side(target).lp - amt).clamp(0, 99999);
    action('${nameOf(target)} 受到 $amt 伤害');
    notifyListeners();
  }

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
      await _sleep(400);
      final act = _rng.nextDouble() < 0.7;
      if (act) {
        trapCard.faceDown = false;
        notifyListeners();
        action('${trapCard.name} 发动!');
        await _sleep(600);
        dst.st[ti] = null;
        dst.grave.add(trapCard);
        if (trapCard.id == 'mirror') {
          action('反射镜力! 攻击怪兽破坏!');
          for (var i = 0; i < 5; i++) {
            if (ast.mon[i] != null && ast.mon[i]!.isAttack) {
              await destroyMon(aSide, i);
            }
          }
          busy = false;
          checkEnd();
          return;
        }
        if (trapCard.id == 'trapdust') {
          action('落穴! 攻击怪兽破坏!');
          await destroyMon(aSide, aIdx);
          busy = false;
          checkEnd();
          return;
        }
        if (trapCard.id == 'solemn') {
          action('神之宣告! 攻击无效!');
          busy = false;
          checkEnd();
          return;
        }
      }
    }

    action('${a.name} 攻击!');
    if (dIdx == null) {
      await _sleep(300);
      dealDamage(aSide, dSide, a.atk);
    } else {
      final d = dst.mon[dIdx];
      if (d == null) {
        busy = false;
        return;
      }
      await _sleep(300);
      var aDead = false;
      var dDead = false;
      Side? lpSide;
      var lpDmg = 0;
      if (d.position == BattlePosition.defense) {
        if (a.atk > d.def) {
          dDead = true;
        } else if (a.atk < d.def) {
          lpSide = aSide;
          lpDmg = d.def - a.atk;
        }
      } else {
        if (a.atk > d.atk) {
          dDead = true;
          lpSide = dSide;
          lpDmg = a.atk - d.atk;
        } else if (a.atk < d.atk) {
          aDead = true;
          lpSide = aSide;
          lpDmg = d.atk - a.atk;
        } else {
          aDead = true;
          dDead = true;
        }
      }
      if (lpSide != null) dealDamage(aSide, lpSide, lpDmg);
      if (dDead) await destroyMon(dSide, dIdx);
      if (aDead) await destroyMon(aSide, aIdx);
    }
    await _sleep(380);
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
      action('该怪兽本回合已攻击');
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
      action('对方场上有怪兽');
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
    await _sleep(850);
    await drawCard(Side.foe);
    await _sleep(350);
    phase = DuelPhase.standby;
    notifyListeners();
    await _sleep(350);
    phase = DuelPhase.main1;
    notifyListeners();
    await _sleep(400);

    final h = foe.hand;
    DuelCard? take(String id) {
      final i = h.indexWhere((c) => c.id == id);
      return i > -1 ? h.removeAt(i) : null;
    }

    DuelCard? c;
    if (foe.monCount >= 2 && _rng.nextDouble() < .5) {
      c = take('pot');
      if (c != null) {
        await castSpell(Side.foe, c);
        await _sleep(480);
      }
    }
    if (own.monCount >= 2 && foe.monCount <= 1 && _rng.nextDouble() < .5) {
      c = take('darkhole');
      if (c != null) {
        await castSpell(Side.foe, c);
        await _sleep(580);
      }
    }
    if (foe.grave.any((g) => g.isMonster) && foe.mon.contains(null) && _rng.nextDouble() < .5) {
      c = take('monsterreborn');
      if (c != null) {
        await castSpell(Side.foe, c);
        await _sleep(480);
      }
    }

    final zi = foe.mon.indexOf(null);
    final mons = h.where((x) => x.isMonster).toList();
    if (zi > -1 && mons.isNotEmpty && !foe.summoned) {
      mons.sort((x, y) => y.atk.compareTo(x.atk));
      final best = mons.first;
      h.remove(best);
      summon(Side.foe, zi, best);
      await _sleep(700);
    }
    final sti = foe.st.indexOf(null);
    final traps = h.where((x) => x.type == CardType.trap).toList();
    if (sti > -1 && traps.isNotEmpty && _rng.nextDouble() < .4) {
      h.remove(traps.first);
      setTrap(Side.foe, sti, traps.first);
      await _sleep(420);
    }

    phase = DuelPhase.battle;
    notifyListeners();
    await _sleep(400);
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
        targets.sort((x, y) => own.mon[x]!.atk.compareTo(own.mon[y]!.atk));
        final w = own.mon[targets.first]!;
        final wPower = w.position == BattlePosition.defense ? w.def : w.atk;
        if (m.atk > wPower || _rng.nextDouble() < .2) {
          dIdx = targets.first;
        }
      }
      if (dIdx != null) {
        await attack(Side.foe, i, dIdx);
        await _sleep(400);
      } else if (targets.isEmpty) {
        await attack(Side.foe, i, null);
        await _sleep(400);
      }
    }
    if (over) return;
    phase = DuelPhase.main2;
    notifyListeners();
    await _sleep(320);
    phase = DuelPhase.end;
    notifyListeners();
    await _sleep(280);
    notifyListeners();
  }
}
