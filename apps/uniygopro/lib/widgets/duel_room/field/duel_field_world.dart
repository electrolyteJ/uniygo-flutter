import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset, Size;
import '../../../models/field_card.dart';
import '../../../models/field_zone_key.dart';
import '../../../pages/duel_room/duel/bloc/duel_bloc.dart';
import '../../../pages/duel_room/duel/bloc/duel_state.dart';
import '../../../image/card_image_loader.dart';
import 'component/battle_presentation_component.dart';
import 'component/board_mesh_component.dart';
import 'component/zone_component.dart';
import 'component/phase_lamp_component.dart';
import 'duel_flame_game.dart';

/// 棋盘布局常量（世界/逻辑坐标，原点为棋盘中心）。
class DuelFieldLayout {
  DuelFieldLayout._();

  /// 7 列布局的 x 坐标。
  static const colX = [-252.0, -168.0, -84.0, 0.0, 84.0, 168.0, 252.0];
  // 怪兽行 y：EMZ 在 y=0（半高 48，跨越 ±48），怪兽行需 ≥ 96 才不重叠；
  // 取 100 留 4px 间隙（与怪兽-魔陷行间距一致）。
  static const monsterY = 100.0;
  // 魔陷行紧贴怪兽行外侧：中心相距 100，扣除两张卡半高后留约 4px 间隙。
  static const stY = 200.0;
  static const slotWidth = 68.0;
  static const slotHeight = 96.0;

  /// Deck（卡组）区域 x 坐标（绝对值）。
  /// self 在 colX[0] 左侧（-deckX），opponent 在 colX[6] 右侧（+deckX）。
  /// 间距与 colX 列间距一致（84）。
  static const deckX = 336.0; // colX[6] + 84 = 252 + 84

  /// PhaseLamp 锚点：self_grave（墓地）卡槽（第 7 列 / Monster 行）。
  /// 己方墓地位于 Monster 行 monsterY 的 colX[6] 位置（己方 Monster 行最右）。
  /// PhaseLamp 左下边 = 墓地卡槽右上边 + (gap, -gap)（右移 8px，上移 8px）。
  static const phaseLampRefBoardX = 252.0; // colX[6]
  static const phaseLampRefBoardY = monsterY; // 100

  /// PhaseLamp 的尺寸（Flutter 与 Flame 共用）。
  static const phaseLampWidth = 132.0;
  static const phaseLampHeight = 44.0;
  static const phaseLampSize = Size(phaseLampWidth, phaseLampHeight);

  /// PhaseLamp 左下角与锚点卡槽右上角之间的间距（px）。
  /// 同时决定 x 向右、y 向上的偏移，形成对角间隙。需要更松/更紧时调它即可。
  static const phaseLampGap = 8.0;

  /// PhaseLamp 相对锚点卡槽「中心」的偏移：使灯的左下角落在卡槽右上角
  /// 外侧 [phaseLampGap] 像素处（向右 gap、向上 gap）。
  /// 推导：center→center 偏移 = (半宽和 + gap, -(半高和 + gap))。
  /// 在原型(Flutter)/火焰(Flame) 两侧统一引用（project3D 为恒等时世界坐标=像素）。
  static const phaseLampOffset = Offset(
    (slotWidth + phaseLampWidth) / 2 + phaseLampGap, // 34 + 66 + 8 = 108
    -((slotHeight + phaseLampHeight) / 2 +
        phaseLampGap), // -(48 + 22 + 8) = -78
  );

  /// PhaseLamp 未找到锚点时的 fallback（相对视口比例）。
  /// x: 0.88 对应 self_grave（我方墓地，棋盘右区 colX[6]）；
  /// y: 0.53 对应 Monster 行上沿附近，留边缘安全距离。
  static const phaseLampFallbackRatio = Offset(0.88, 0.53);
}

/// 决斗场地世界：持有棋盘网格与全部卡槽组件，并统一负责
/// Stylized 3D 投影（世界坐标 = 投影后、以棋盘中心为原点的坐标，
/// 视口居中/偏移由 [CameraComponent] 负责）。
class DuelFieldWorld extends World with HasGameReference<DuelFlameGame> {
  final DuelBloc duelBloc;
  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;
  final VoidCallback? onPhaseLampTap;
  final bool Function()? isPhaseLampEnabled;

  /// 当前对局状态快照（便捷访问，等价于 duelBloc.state）。
  DuelState get duelStore => duelBloc.state;

  PhaseLampComponent? _phaseLamp;
  ZonesComponent? _zones;

  /// 卡图图片缓存（由 [CardImageLoader] 统一管理）。
  CardImageLoader get _loader => CardImageLoader.I;

  DuelFieldWorld({
    required this.duelBloc,
    this.onCardSelect,
    this.onZoneInspect,
    this.onPhaseLampTap,
    this.isPhaseLampEnabled,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initComponents();
  }

  void _initComponents() {
    add(BoardMeshComponent());
    _zones = ZonesComponent(
      duelBloc: duelBloc,
      onCardSelect: onCardSelect,
      onZoneInspect: onZoneInspect,
    );
    add(_zones!);
    _zones!.rebuild();
    add(BattlePresentationComponent(duelBloc: duelBloc));
    _phaseLamp = PhaseLampComponent(
      duelBloc: duelBloc,
      onTap: onPhaseLampTap,
      enabledGetter: isPhaseLampEnabled,
    );
    add(_phaseLamp!);
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
    _phaseLamp = null;
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

  /// lift（Z 轴提升）换算成世界坐标 y 方向位移。
  /// 临时关闭 3D 后直接返回原值，hover 仍可垂直抬起。
  double projectLiftY(double lift) {
    return lift;
    // final double alpha = (45 * pi / 180) + _parallaxTilt.x;
    // return lift * sin(alpha) * 0.85;
  }

  /// 重建场地区域（委托给 [ZonesComponent]）。
  void rebuildField() => _zones?.rebuild();

  Vector2? boardPositionForSlotId(String slotId) {
    final parsed = parseZoneKey(slotId);
    if (parsed == null) return null;
    final controller = parsed.controller;
    final zone = parsed.zone;
    final sequence = parsed.sequence;

    const colX = DuelFieldLayout.colX;
    final isSelf = controller == duelStore.myController;

    if (zone == 4) {
      if (sequence == 5) return Vector2(-84, 0);
      if (sequence == 6) return Vector2(84, 0);
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

  Vector2? worldPositionForSlotId(String slotId) {
    final board = boardPositionForSlotId(slotId);
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
