import 'summon_style.dart';
import 'normal_style.dart';
import 'special_style.dart';
import 'fusion_style.dart';
import 'synchro_style.dart';
import 'xyz_style.dart';
import 'link_style.dart';
import 'ritual_style.dart';
import 'pendulum_style.dart';
import 'spell_style.dart';
import 'trap_style.dart';

/// 根据召唤类型返回对应的视觉样式
SummonStyle styleForType(SummonType type) {
  switch (type) {
    case SummonType.normal:
      return NormalStyle.style;
    case SummonType.special:
      return SpecialStyle.style;
    case SummonType.fusion:
      return FusionStyle.style;
    case SummonType.synchro:
      return SynchroStyle.style;
    case SummonType.xyz:
      return XyzStyle.style;
    case SummonType.link:
      return LinkStyle.style;
    case SummonType.ritual:
      return RitualStyle.style;
    case SummonType.pendulum:
      return PendulumStyle.style;
    case SummonType.spell:
      return SpellStyle.style;
    case SummonType.trap:
      return TrapStyle.style;
  }
}
