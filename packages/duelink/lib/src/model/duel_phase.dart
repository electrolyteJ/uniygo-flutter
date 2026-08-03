import '../constants.dart';
import 'dart:developer' as console;

enum DuelPhase {
  idle("Idle"),
  dp("Draw Phase"),
  sp("Standby Phase"),
  m1("Main Phase 1"),
  bp("Battle Phase"),
  m2("Main Phase 2"),
  ep("End Phase");

  final String desc;

  const DuelPhase(this.desc);

  static DuelPhase of(int value) {
    switch (value) {
      case 0:
        return DuelPhase.idle;
      case PHASE_DRAW:
        return DuelPhase.dp;
      case PHASE_STANDBY:
        return DuelPhase.sp;
      case PHASE_MAIN1:
        return DuelPhase.m1;
      case PHASE_BATTLE_START:
      case PHASE_BATTLE_STEP:
      case PHASE_DAMAGE:
      case PHASE_DAMAGE_CAL:
      case PHASE_BATTLE:
        return DuelPhase.bp;
      case PHASE_MAIN2:
        return DuelPhase.m2;
      case PHASE_END:
        return DuelPhase.ep;
      default:
        console.log('Unknown duel phase value: $value');
        return DuelPhase.idle;
    }
  }
}
