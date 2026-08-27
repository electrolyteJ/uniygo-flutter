import 'package:duelink/duelink.dart';

/// 阶段名文案（duel_room3 不做 l10n，直接用 duelink 的中文描述）。
String getDuelPhaseText(DuelPhase phase) {
  final desc = phase.desc;
  return desc.isEmpty ? phase.name.toUpperCase() : desc;
}
