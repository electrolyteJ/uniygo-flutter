import 'ChainLink.dart';
import 'DuelPhase.dart';
import 'FieldCard.dart';

class DuelBoardState {
  final Map<String, FieldCard> fieldCards = {};
  final List<int> selfHand = [];
  final List<int> opponentHand = [];
  final List<int> selfGraveCodes = [];
  final List<int> opponentGraveCodes = [];
  final List<int> selfRemovedCodes = [];
  final List<int> opponentRemovedCodes = [];
  final List<int> selfExtraCodes = [];
  final List<int> opponentExtraCodes = [];

  int selfDeck = 0;
  int selfExtra = 0;
  int selfGrave = 0;
  int selfRemoved = 0;
  int oppDeck = 0;
  int oppExtra = 0;
  int oppGrave = 0;
  int oppRemoved = 0;
  int selfLp = 8000;
  int opponentLp = 8000;
  int currentPlayer = 0;
  int phase = 0;
  int turnCount = 0;
  int myController = 0;

  List<DuelPhase> phases = [];
  List<ChainLink> chains = [];
  String? lastSummonKey;
  String? lastAttackFrom;
  String? lastAttackTo;
  String? inspectedZoneKey;

  void reset() {
    fieldCards.clear();
    selfHand.clear();
    opponentHand.clear();
    selfGraveCodes.clear();
    opponentGraveCodes.clear();
    selfRemovedCodes.clear();
    opponentRemovedCodes.clear();
    selfExtraCodes.clear();
    opponentExtraCodes.clear();
    selfDeck = selfExtra = selfGrave = selfRemoved = 0;
    oppDeck = oppExtra = oppGrave = oppRemoved = 0;
    selfLp = opponentLp = 8000;
    currentPlayer = 0;
    phase = 0;
    turnCount = 0;
    myController = 0;
    phases = [];
    chains = [];
    lastSummonKey = null;
    lastAttackFrom = null;
    lastAttackTo = null;
    inspectedZoneKey = null;
  }
}
