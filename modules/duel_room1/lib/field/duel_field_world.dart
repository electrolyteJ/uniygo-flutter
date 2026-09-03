import 'dart:async';
import 'dart:ui' as ui;
import 'package:biz/card_image_loader.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:cardlive/cardlive.dart';
import 'components/battle_presentation_component.dart';
import 'components/card_move_animator.dart';
import 'package:duel_room1/field/components/summon_effect_adapter.dart';
import 'components/board_component.dart';
import 'components/center_timer_component.dart';
import 'components/zone/zone_component.dart';
import 'components/phase_rail/phase_rail_component.dart';
import 'duel_field_game.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';

// 布局常量已抽离为独立文件；export 保持既有 import 链（page/component）不破。
export 'package:duel_room1/field/util/duel_field_layout.dart';

/// 决斗场地世界：持有棋盘网格与全部卡槽组件（世界坐标 = 以棋盘中心
/// 为原点的像素坐标，视口居中/偏移由 [CameraComponent] 负责）。
///
/// 状态一律经 [DuelFieldGame.snapshot] 读取（widget 层推送的
/// Riverpod 状态快照），world 与 component 不依赖任何 store/Provider。
class DuelFieldWorld extends World with HasGameReference<DuelFieldGame> {
  PhaseRailComponent? _phaseRail;
  ZoneComponent? _zones;
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
    add(BoardComponent());
    _zones = ZoneComponent(
      onCardSelect: game.onCardSelect,
      onZoneInspect: game.onZoneInspect,
      onPlaceSlotTap: game.onPlaceSlotTap,
    );
    add(_zones!);
    add(_ZoneTapRouter(_zones!));
    _zones!.rebuild();
    add(BattlePresentationComponent());
    add(_summonDriver);
    add(_summonAdapter);
    add(CardMoveAnimator());
    _phaseRail = PhaseRailComponent(
      onTap: game.onPhaseLampTap,
      enabledGetter: game.isPhaseLampEnabled,
      onSurrenderTap: game.onSurrenderTap,
      surrenderEnabledGetter: game.isSurrenderEnabled,
    )..compactMode = game.compactHud;
    add(_phaseRail!);
    // 场地中央计时器：直读快照渲染，无需重建触发。
    add(CenterTimerComponent());
  }

  /// Hot reload 支持：移除并重建全部子组件。
  /// 由 [DuelFieldGame.reload] → [State.reassemble] 调用，
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

  /// 重建场地区域（委托给 [ZoneComponent]）。
  void rebuildField() => _zones?.rebuild();

  /// 快照变更后刷新阶段轨道（当前阶段/可点击态）。
  void refreshPhaseRail() => _phaseRail?.notifyStateChanged();

  /// 阶段轨道组件（紧凑模式的锚点矩形换算用；未挂载时为 null）。
  PhaseRailComponent? get phaseRailComponent => _phaseRail;

  bool dispatchZonePrimaryTap(Vector2 worldPoint) =>
      _zones?.dispatchPrimaryTap(worldPoint) ?? false;

  bool canDispatchZonePrimaryTap(Vector2 worldPoint) =>
      _zones?.canDispatchPrimaryTap(worldPoint) ?? false;

  /// 紧凑 HUD 模式切换（由 [DuelFieldGame] 按视口高度驱动）：
  /// 阶段轨道反缩放为固定屏幕尺寸；玩家状态卡/中央计时器在世界内
  /// 直读 game.compactHud 自行隐藏（让位给 widget 层紧凑件）。
  void setCompactHudMode(bool compact) {
    _phaseRail?.compactMode = compact;
  }

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

  /// 无 3D 投影：棋盘坐标即世界坐标，直接返回。
  /// 保留此方法作为语义别名，调用方（战斗演出等）仍按「区域 key → 世界位置」取值。
  Vector2? worldPositionForZoneKey(String zoneKey) =>
      boardPositionForZoneKey(zoneKey);

  // ── 卡图图片缓存 ──────────────────────────────────────────────

  /// 同步获取已缓存的卡图（未加载时返回 null）。
  ui.Image? getCachedCardImage(int code) => CardImageLoader.I.get(code);

  /// 异步加载卡图：委托给 [CardImageLoader]（统一缓存，跨 Flame / Flutter Widget 复用）。
  ///
  /// 降采样解码到场地卡槽所需尺寸：卡槽 68 世界单位，即使最大 zoom（2.6）
  /// 也只显示约 177 逻辑 px，256 目标宽度（≈2x）已足够清晰，避免全尺寸
  /// 400px 解码的内存与耗时。
  Future<ui.Image?> loadCardImage(int code) =>
      CardImageLoader.I.load(code, targetWidth: _fieldCardDecodeWidth);

  /// Flame 场地卡槽的统一解码目标宽度（对齐 CardImage 的最小解码宽度）。
  static const int _fieldCardDecodeWidth = 256;
}

class _ZoneTapRouter extends PositionComponent with TapCallbacks {
  _ZoneTapRouter(this.zones)
    : super(
        position: Vector2(-1000, -1000),
        size: Vector2.all(2000),
        priority: -100,
      );

  final ZoneComponent zones;

  Vector2 _worldPoint(Vector2 localPoint) => localPoint + position;

  @override
  bool containsLocalPoint(Vector2 point) =>
      zones.canDispatchPrimaryTap(_worldPoint(point));

  @override
  void onTapUp(TapUpEvent event) =>
      zones.dispatchPrimaryTap(_worldPoint(event.localPosition));
}
