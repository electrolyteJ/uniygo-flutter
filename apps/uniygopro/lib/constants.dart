import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';

import 'l10n/app_localizations.dart';

String? getDuelPhaseText(BuildContext context, DuelPhase duelPhase) {
  if(context.mounted == false) {
    return "";
  }
  final l10n = AppLocalizations.of(context);
  switch (duelPhase) {
    case DuelPhase.dp:
      return l10n?.phase_dp;
    case DuelPhase.sp:
      return l10n?.phase_sp;
    case DuelPhase.m1:
      return l10n?.phase_m1;
    case DuelPhase.bp:
      return l10n?.phase_bp;
    case DuelPhase.m2:
      return l10n?.phase_m2;
    case DuelPhase.ep:
      return l10n?.phase_ep;
    default:
      return "";
  }
}

final DUEL_PHASES = [
  {DuelPhase.dp: 'DP'},
  {DuelPhase.sp: 'SP'},
  {DuelPhase.m1: 'MAIN 1'},
  {DuelPhase.bp: 'BATTLE'},
  {DuelPhase.m2: 'MAIN 2'},
  {DuelPhase.ep: 'END'},
];
