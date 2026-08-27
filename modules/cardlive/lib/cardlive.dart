/// cardlive —— 游戏王召唤动画库 + 鉴赏应用。
///
/// 全仓库召唤动画的单一来源（阶段 1：架构迁移）：
/// - 权威分类 [SummonCategory]（12 类）与推断函数；
/// - 按类别的视觉主题 [SummonTheme]（鉴赏/场地双色板）；
/// - 通用 FIFO 队列驱动器 [SummonQueueDriver] + 类别动画注册表；
/// - 场地 2D 播放器 [FieldSummonPlayer]（决斗内小特效）；
/// - 全屏鉴赏动效（[SummonController] + [SummonOverlay]/[SummonInline]）；
/// - flame_3d 3D 演出（[Summon3DGame]/[Summon3DOverlay]，不支持 Web）；
/// - 鉴赏画廊 [CardLivePage]。
library;

// 核心
export 'src/category.dart';
export 'src/spec.dart';
export 'src/registry.dart';
export 'src/summon_manager.dart';
export 'src/driver/summon_queue_driver.dart';

// 2D
export 'src/twod/themes/summon_theme.dart';
export 'src/twod/themes/theme_provider.dart';
export 'src/twod/animations/field_summon_player.dart';
export 'src/twod/summon_controller.dart';
export 'src/twod/stage_sequence.dart';
export 'src/twod/components/beam_component.dart';
export 'src/twod/components/card_sprite.dart';
export 'src/twod/components/particle_system.dart';
export 'src/twod/components/ring_component.dart';

// 3D
export 'src/threed/cyber_dragon_rig.dart';
export 'src/threed/glb_dragon_rig.dart';
export 'src/threed/glb_mesh_loader.dart';
export 'src/threed/summon_3d_game.dart';
export 'src/threed/summon_3d_overlay.dart';

// 入口与鉴赏
export 'src/widgets/summon_overlay.dart';
export 'src/widgets/summon_inline.dart';
export 'src/card_live_page.dart';
