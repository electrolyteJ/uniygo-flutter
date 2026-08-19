import 'dart:ui';

/// 召唤动画鉴赏页的怪兽条目。
///
/// 默认使用同一套程序化机械龙 rig（见 cyber_dragon_rig.dart），
/// 通过 [metalColor]/[jointColor]/[glowColor] 为每只怪兽换色；
/// [modelAsset] 非 null 时改加载真实 glb 模型（见 glb_dragon_rig.dart）。
class LiveMonster {
  const LiveMonster({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.accent,
    this.metalColor,
    this.jointColor,
    this.glowColor,
    this.modelAsset,
  });

  /// 条目唯一标识（用于 widget key）。
  final String id;

  /// 怪兽名。
  final String name;

  /// 卡片密码（ocgcore card code）。
  final int code;

  /// 一句话介绍。
  final String description;

  /// 列表 UI 强调色。
  final Color accent;

  /// rig 换色（null 时用电子龙默认配色）。
  final Color? metalColor;
  final Color? jointColor;
  final Color? glowColor;

  /// 可选 glb 模型资产（相对 cardlive 资产根 assets/ 之后，
  /// 如 models/cyber_dragon.glb）；null 时用程序化机械龙 rig。
  final String? modelAsset;
}

/// 鉴赏页怪兽列表。电子龙加载真实 glb 模型，其余用程序化 rig 换色。
const List<LiveMonster> monsterCatalog = [
  LiveMonster(
    id: 'cyber-dragon',
    name: '电子龙',
    code: 70095154,
    description: '真实 3D 模型 · 召唤演出 + 待机动画',
    accent: Color(0xFF35E8FF),
    modelAsset: 'models/cyber_dragon.glb',
  ),
  LiveMonster(
    id: 'blue-eyes-white-dragon',
    name: '青眼白龙',
    code: 89631139,
    description: '银白鳞甲，苍蓝毁灭喷射光',
    accent: Color(0xFF82C8FF),
    metalColor: Color(0xFFF4F8FF),
    jointColor: Color(0xFF61759B),
    glowColor: Color(0xFF82C8FF),
    modelAsset: 'models/DamagedHelmet.glb',
  ),
  LiveMonster(
    id: 'dark-magician',
    name: '黑魔术师',
    code: 46986414,
    description: '深紫法袍质感，品红魔力辉光',
    accent: Color(0xFFD06BFF),
    metalColor: Color(0xFF6A5AA0),
    jointColor: Color(0xFF33285C),
    glowColor: Color(0xFFD06BFF),
    modelAsset: 'models/cyber_dragon2.glb',
  ),
  LiveMonster(
    id: 'red-eyes-black-dragon',
    name: '真红眼黑龙',
    code: 74677422,
    description: '漆黑甲壳，真红眼炎光',
    accent: Color(0xFFFF4D4D),
    metalColor: Color(0xFF42464F),
    jointColor: Color(0xFF1A1D24),
    glowColor: Color(0xFFFF4D4D),
  ),
  LiveMonster(
    id: 'blue-eyes-ultimate-dragon',
    name: '青眼究极龙',
    code: 23995346,
    description: '三体融合辉光，冰蓝圣辉',
    accent: Color(0xFF9FD6FF),
    metalColor: Color(0xFFE9F1FF),
    jointColor: Color(0xFF7A8DB0),
    glowColor: Color(0xFF9FD6FF),
    modelAsset: 'models/generated_model_20260819_0033.glb',
  ),
  LiveMonster(
    id: 'elemental-hero-neos',
    name: '元素英雄 新宇侠',
    code: 89943723,
    description: '银白躯体，新宇能量橙光',
    accent: Color(0xFFFFA13D),
    metalColor: Color(0xFFEDE7DA),
    jointColor: Color(0xFF9C5A3C),
    glowColor: Color(0xFFFFA13D),
    modelAsset: 'models/elemental_hero_neos.glb',
  ),
];
