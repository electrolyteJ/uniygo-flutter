import 'dart:async';
import 'dart:ui' as ui;
import 'package:biz/card_image_loader.dart';
import 'package:flame/components.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:cardlive/cardlive.dart';
import 'component/battle_presentation_component.dart';
import 'package:duel_room1/field/component/summon_effect_adapter.dart';
import 'component/board_mesh_component.dart';
import 'component/zone_component.dart';
import 'component/phase_rail_component.dart';
import 'duel_flame_game.dart';
import 'package:duel_room1/field/models/duel_field_layout.dart';

// 布局常量已抽离为独立文件；export 保持既有 import 链（page/component）不破。
export 'package:duel_room1/field/models/duel_field_layout.dart';

/// 决斗场地世界：持有棋盘网格与全部卡槽组件，并统一负责
/// Stylized 3D 投影（世界坐标 = 投影后、以棋盘中心为原点的坐标，
/// 视口居中/偏移由 [CameraComponent] 负责）。
///
/// 状态一律经 [DuelFlameGame.snapshot] 读取（widget 层推送的
/// Riverpod 状态快照），world 与 component 不依赖任何 store/Provider。
class DuelFieldWorld extends World with HasGameReference<DuelFlameGame> {
  PhaseRailComponent? _phaseRail;
  ZonesComponent? _zones;
  final SummonQueueDriver _summonDriver = SummonQueueDriver(priority: 25);
  late final SummonEffectAdapter _summonAdapter = SummonEffectAdapter(
    _summonDriver,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initComponents();
  }

  void _initComponents() {
    add(BoardMeshComponent());
    _zones = ZonesComponent(
      onCardSelect: game.onCardSelect,
      onZoneInspect: game.onZoneInspect,
      onPlaceSlotTap: game.onPlaceSlotTap,
    );
    add(_zones!);
    _zones!.rebuild();
    add(BattlePresentationComponent());
    add(_summonDriver);
    add(_summonAdapter);
    _phaseRail = PhaseRailComponent(
      onTap: game.onPhaseLampTap,
      enabledGetter: game.isPhaseLampEnabled,
    );
    add(_phaseRail!);
  }

  /// Hot reload 支持：移除并重建全部子组件。
  /// 由 [DuelFlameGame.reload] → [State.reassemble] 调用，
  /// 使修改后的 Component 类定义在 hot reload 后立即生效。
  void reload() {
    if (!isLoaded) return;
    for (final child in children.toList()) {
      child.removeFromParent();
    }
    _zones = null;
    _phaseRail = null;
    _initComponents();
  }

  // ⚠️ 临时关闭 3D 投影：返回恒等投影（原始 x,y），便于预览平面布局。
  // 恢复时还原下方注释的梯形投影算法。
  Vector2 project3D(double x, double y, {double lift = 0}) {
    return Vector2(x, y);
    // final tilt = _parallaxTilt;
    // final double alpha = (45 * pi / 180) + tilt.x;
    // final double cosA = cos(alpha);
    // final double sinA = sin(alpha);
    // final double yRot = (y * cosA) + (lift * sinA);
    // final double factor = 1.0 + (y * 0.0008);
    // return Vector2(
    //   (x * factor) + (tilt.y * 100 * factor),
    //   yRot * 0.85,
    // );
  }

  /// 3D 投影是否启用。当前临时关闭（[project3D] 为恒等变换），
  /// 供调用方在关闭期间跳过重投影同步等纯浪费工作；恢复投影时同步改为 true。
  bool get isProjectionEnabled => false;

  /// lift（Z 轴提升）换算成世界坐标 y 方向位移。
  /// 临时关闭 3D 后直接返回原值，hover 仍可垂直抬起。
  double projectLiftY(double lift) {
    return lift;
    // final double alpha = (45 * pi / 180) + _parallaxTilt.x;
    // return lift * sin(alpha) * 0.85;
  }

  /// 重建场地区域（委托给 [ZonesComponent]）。
  void rebuildField() => _zones?.rebuild();

  /// 快照变更后刷新阶段轨道（当前阶段/可点击态）。
  void refreshPhaseRail() => _phaseRail?.notifyStateChanged();

  Vector2? boardPositionForZoneKey(String zoneKey) {
    final parsed = parseZoneKey(zoneKey);
    if (parsed == null) return null;
    final controller = parsed.controller;
    final zone = parsed.zone;
    final sequence = parsed.sequence;

    const colX = DuelFieldLayout.colX;
    final isSelf = controller == game.snapshot.myController;

    if (zone == 4) {
      // EMZ 物理槽位双方镜像：己方 s5 / 对手 s6 在屏幕左（-84），
      // 己方 s6 / 对手 s5 在屏幕右（+84）。
      if (sequence == 5) return Vector2(isSelf ? -84 : 84, 0);
      if (sequence == 6) return Vector2(isSelf ? 84 : -84, 0);
      if (sequence < 0 || sequence > 4) return null;
      return Vector2(
        colX[1 + (isSelf ? sequence : 4 - sequence)],
        isSelf ? DuelFieldLayout.monsterY : -DuelFieldLayout.monsterY,
      );
    }

    if (zone == 8) {
      if (sequence == 5) {
        return Vector2(
          isSelf ? colX[0] : colX[6],
          isSelf ? DuelFieldLayout.monsterY : -DuelFieldLayout.monsterY,
        );
      }
      if (sequence < 0 || sequence > 4) return null;
      return Vector2(
        colX[1 + (isSelf ? sequence : 4 - sequence)],
        isSelf ? DuelFieldLayout.stY : -DuelFieldLayout.stY,
      );
    }

    return null;
  }

  Vector2? worldPositionForZoneKey(String zoneKey) {
    final board = boardPositionForZoneKey(zoneKey);
    if (board == null) return null;
    return project3D(board.x, board.y);
  }

  // ── 卡图图片缓存 ──────────────────────────────────────────────

  /// 同步获取已缓存的卡图（未加载时返回 null）。
  ui.Image? getCachedCardImage(int code) => CardImageLoader.I.get(code);

  /// 异步加载卡图：委托给 [CardImageLoader]（统一缓存，跨 Flame / Flutter Widget 复用）。
  Future<ui.Image?> loadCardImage(int code) => CardImageLoader.I.load(code);

  // _fetchNetworkImage 已移除——网络请求统一由 CardImageLoader 负责。
}
