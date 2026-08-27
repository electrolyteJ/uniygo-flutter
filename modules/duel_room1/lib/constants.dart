import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';

import 'package:duel_room1/l10n/app_localizations.dart';

/// 阶段名文案：优先取 l10n；未知/未翻译的阶段回退到 [DuelPhase.desc]，
/// 不再返回空串（空串会让 UI 显示成空白标签）。
String? getDuelPhaseText(BuildContext context, DuelPhase duelPhase) {
  // 未挂载时查不了 l10n，直接回退 desc（phaseLabel 闭包会被
  // DuelMessageRouter 异步调用，这里返回空串会产生空白阶段标签）。
  if (context.mounted == false) {
    return duelPhase.desc;
  }
  final l10n = AppLocalizations.of(context);
  switch (duelPhase) {
    case DuelPhase.dp:
      return l10n?.phase_dp ?? duelPhase.desc;
    case DuelPhase.sp:
      return l10n?.phase_sp ?? duelPhase.desc;
    case DuelPhase.m1:
      return l10n?.phase_m1 ?? duelPhase.desc;
    case DuelPhase.bp:
      return l10n?.phase_bp ?? duelPhase.desc;
    case DuelPhase.m2:
      return l10n?.phase_m2 ?? duelPhase.desc;
    case DuelPhase.ep:
      return l10n?.phase_ep ?? duelPhase.desc;
    default:
      // DuelPhase.idle 等未在 l10n 中定义阶段的兜底。
      return duelPhase.desc;
  }
}
