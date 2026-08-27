import '../../category.dart';
import 'summon_theme.dart';
import 'normal_theme.dart';
import 'special_theme.dart';
import 'flip_theme.dart';
import 'set_theme.dart';
import 'ritual_theme.dart';
import 'fusion_theme.dart';
import 'synchro_theme.dart';
import 'xyz_theme.dart';
import 'link_theme.dart';
import 'pendulum_theme.dart';
import 'spell_theme.dart';
import 'trap_theme.dart';

/// 根据召唤类别返回对应的视觉主题。
SummonTheme themeFor(SummonCategory category) {
  return switch (category) {
    SummonCategory.normal => NormalTheme.theme,
    SummonCategory.special => SpecialTheme.theme,
    SummonCategory.flip => FlipTheme.theme,
    SummonCategory.set => SetTheme.theme,
    SummonCategory.ritual => RitualTheme.theme,
    SummonCategory.fusion => FusionTheme.theme,
    SummonCategory.synchro => SynchroTheme.theme,
    SummonCategory.xyz => XyzTheme.theme,
    SummonCategory.link => LinkTheme.theme,
    SummonCategory.pendulum => PendulumTheme.theme,
    SummonCategory.spell => SpellTheme.theme,
    SummonCategory.trap => TrapTheme.theme,
  };
}
