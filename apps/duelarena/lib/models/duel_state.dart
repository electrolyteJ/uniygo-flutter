import 'package:flutter/foundation.dart';
import 'duel_card.dart';
import 'field_state.dart';

enum DuelPhase {
  draw('抽卡阶段'),
  standby('准备阶段'),
  main1('主要阶段1'),
  battle('战斗阶段'),
  main2('主要阶段2'),
  end('结束阶段');

  final String label;
  const DuelPhase(this.label);
}

class DuelState extends ChangeNotifier {
  int playerLp = 8000;
  int opponentLp = 8000;
  int turn = 1;
  bool isPlayerTurn = true;
  DuelPhase phase = DuelPhase.draw;

  final FieldState playerField = FieldState();
  final FieldState opponentField = FieldState();
  final List<DuelCard> playerHand = [];

  String playerName = 'Player';
  String opponentName = 'Opponent';

  DuelCard? selectedCard;
  int? selectedZoneIndex;

  bool _demoLoaded = false;

  void setPhase(DuelPhase p) {
    phase = p;
    notifyListeners();
  }

  void nextPhase() {
    final idx = DuelPhase.values.indexOf(phase);
    if (idx < DuelPhase.values.length - 1) {
      phase = DuelPhase.values[idx + 1];
    } else {
      isPlayerTurn = !isPlayerTurn;
      turn++;
      phase = DuelPhase.draw;
    }
    notifyListeners();
  }

  void updateLp({int? player, int? opponent}) {
    if (player != null) playerLp = player.clamp(0, 99999);
    if (opponent != null) opponentLp = opponent.clamp(0, 99999);
    notifyListeners();
  }

  void placeMonster(int zone, DuelCard card, {bool isOpponent = false}) {
    final field = isOpponent ? opponentField : playerField;
    field.monsterZones[zone] = card;
    notifyListeners();
  }

  void placeSpell(int zone, DuelCard card, {bool isOpponent = false}) {
    final field = isOpponent ? opponentField : playerField;
    field.spellZones[zone] = card;
    notifyListeners();
  }

  void addToHand(DuelCard card) {
    playerHand.add(card);
    notifyListeners();
  }

  void removeFromHand(int index) {
    if (index >= 0 && index < playerHand.length) {
      playerHand.removeAt(index);
      notifyListeners();
    }
  }

  void selectCard(DuelCard? card, {int? zoneIndex}) {
    selectedCard = card;
    selectedZoneIndex = zoneIndex;
    notifyListeners();
  }

  void loadDemoState() {
    if (_demoLoaded) return;
    _demoLoaded = true;
    playerHand.addAll([
      DuelCard(code: 89631139, name: '青眼白龙', attack: 3000, defense: 2500, level: 8, attribute: 0x10),
      DuelCard(code: 46986414, name: '黑魔术师', attack: 2500, defense: 2100, level: 7, attribute: 0x20),
      DuelCard(code: 4041838, name: '暗黑骑士 盖亚', attack: 2300, defense: 2100, level: 7, attribute: 0x01),
      DuelCard(code: 70781052, name: '天使的施舍', type: CardType.spell),
      DuelCard(code: 53129443, name: '黑洞', type: CardType.spell),
    ]);

    placeMonster(2, DuelCard(code: 89631139, name: '青眼白龙', attack: 3000, defense: 2500, level: 8, attribute: 0x10));
    placeMonster(1, DuelCard(code: 4041838, name: '暗黑骑士 盖亚', attack: 2300, defense: 2100, level: 7, attribute: 0x01));
    placeSpell(2, DuelCard(code: 70781052, name: '天使的施舍', type: CardType.spell));

    placeMonster(2, DuelCard(code: 46986414, name: '黑魔术师', attack: 2500, defense: 2100, level: 7, attribute: 0x20), isOpponent: true);
    placeMonster(3, DuelCard(code: 38033121, name: '黑魔术少女', attack: 2000, defense: 1700, level: 6, attribute: 0x20), isOpponent: true);
    placeSpell(1, DuelCard(code: 53129443, name: '黑洞', type: CardType.spell, position: CardPosition.faceDownDefense), isOpponent: true);

    playerField.deckCount = 35;
    opponentField.deckCount = 33;
    playerField.graveCount = 2;
    opponentField.graveCount = 4;
    playerField.banishedCount = 1;
    opponentField.banishedCount = 2;
    playerField.fieldZone = DuelCard(
      code: 22702055,
      name: '海',
      type: CardType.spell,
    );

    phase = DuelPhase.main1;
    notifyListeners();
  }
}
