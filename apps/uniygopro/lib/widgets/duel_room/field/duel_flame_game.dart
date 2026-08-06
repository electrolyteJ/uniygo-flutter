import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../models/FieldCard.dart';
import '../../../pages/duel_room/duel/duel_field_store.dart';
import 'playmat_anchor_data.dart';
import 'duel_field_world.dart';

/// 决斗场地 FlameGame：只持有 [DuelFieldWorld] 与观察它的
/// [CameraComponent]，负责鼠标视差输入与 Flutter 侧锚点上报。
/// 场地内容（棋盘、卡槽）全部挂在 world 下。
class DuelFlameGame extends FlameGame<DuelFieldWorld>
    with MouseMovementDetector {
  static const _phaseLampSize = Size(132, 44);

  /// 棋盘中心相对视口中心的下偏移量（还原效果图构图）。
  static const _boardCenterOffsetY = 40.0;

  final DuelFieldStore duelStore;
  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;
  ValueChanged<PlaymatAnchorData>? onAnchorsChanged;
  String? _lastAnchorSignature;

  DuelFlameGame({
    required this.duelStore,
    this.onCardSelect,
    this.onZoneInspect,
    this.onAnchorsChanged,
  }) : super(
         world: DuelFieldWorld(
           duelStore: duelStore,
           onCardSelect: onCardSelect,
           onZoneInspect: onZoneInspect,
         ),
       ) {
    duelStore.addListener(_onDuelStateChanged);
  }

  /// 鼠标位置（widget 坐标），驱动 world 的 3D 视差投影。
  Vector2 mousePos = Vector2.zero();

  @override
  void onMouseMove(PointerHoverInfo info) {
    mousePos = info.eventPosition.widget;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2(0, -_boardCenterOffsetY);
    _emitAnchors();
  }

  void _onDuelStateChanged() {
    world.rebuildField();
    _emitAnchors();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 居中由 camera 自动完成，resize 只需重算 Flutter 侧锚点。
    if (isLoaded) {
      _emitAnchors();
    }
  }

  /// 世界坐标 → widget 坐标（经由 camera viewfinder 变换）。
  Offset worldToWidget(Vector2 point) {
    final viewfinder = camera.viewfinder;
    return Offset(
      (point.x - viewfinder.position.x) * viewfinder.zoom + size.x / 2,
      (point.y - viewfinder.position.y) * viewfinder.zoom + size.y / 2,
    );
  }

  void _emitAnchors() {
    final callback = onAnchorsChanged;
    if (callback == null || !hasLayout || size.x <= 0 || size.y <= 0) {
      return;
    }
    final anchorData = buildAnchorDataForSize(Size(size.x, size.y));
    if (anchorData.signature == _lastAnchorSignature) return;
    _lastAnchorSignature = anchorData.signature;
    callback(anchorData);
  }

  PlaymatAnchorData buildAnchorDataForSize(Size viewport) {
    final selfController = duelStore.myController;
    final opponentController = 1 - selfController;
    final slotRects = <String, Rect>{};

    void addRect(String slotId, double boardX, double boardY) {
      final center = worldToWidget(world.project3D(boardX, boardY));
      slotRects[slotId] = Rect.fromCenter(
        center: center,
        width: DuelFieldLayout.slotWidth,
        height: DuelFieldLayout.slotHeight,
      );
    }

    const colX = DuelFieldLayout.colX;
    const monsterY = DuelFieldLayout.monsterY;
    const stY = DuelFieldLayout.stY;

    addRect('opp_extra', colX[0], -stY);
    addRect('opp_removed', colX[0], -monsterY);
    addRect('opp_grave', colX[6], -monsterY);
    addRect('self_grave', colX[0], monsterY);
    addRect('self_removed', colX[6], monsterY);
    addRect('self_extra', colX[6], stY);

    addRect('${opponentController}_8_5', colX[6], -stY);
    addRect('${selfController}_8_5', colX[0], stY);

    for (int i = 0; i < 5; i++) {
      addRect('${opponentController}_8_${4 - i}', colX[1 + i], -stY);
      addRect('${opponentController}_4_${4 - i}', colX[1 + i], -monsterY);
      addRect('${selfController}_4_$i', colX[1 + i], monsterY);
      addRect('${selfController}_8_$i', colX[1 + i], stY);
    }

    final emz1Rect = Rect.fromCenter(
      center: worldToWidget(world.project3D(-84.0, 0)),
      width: DuelFieldLayout.slotWidth,
      height: DuelFieldLayout.slotHeight,
    );
    final emz2Rect = Rect.fromCenter(
      center: worldToWidget(world.project3D(84.0, 0)),
      width: DuelFieldLayout.slotWidth,
      height: DuelFieldLayout.slotHeight,
    );
    slotRects['${selfController}_4_5'] = emz1Rect;
    slotRects['${opponentController}_4_5'] = emz1Rect;
    slotRects['${selfController}_4_6'] = emz2Rect;
    slotRects['${opponentController}_4_6'] = emz2Rect;

    final phaseReference =
        slotRects['self_removed'] ??
        slotRects['self_grave'] ??
        slotRects['${selfController}_4_4'];
    final phaseLampRect = phaseReference == null
        ? Rect.fromLTWH(
            viewport.width * 0.73,
            viewport.height * 0.53,
            _phaseLampSize.width,
            _phaseLampSize.height,
          )
        : Rect.fromCenter(
            center: Offset(
              phaseReference.center.dx - 8,
              phaseReference.center.dy - 42,
            ),
            width: _phaseLampSize.width,
            height: _phaseLampSize.height,
          );

    return PlaymatAnchorData(
      slotRects: slotRects,
      phaseLampRect: phaseLampRect,
    );
  }

  @override
  void onRemove() {
    duelStore.removeListener(_onDuelStateChanged);
    super.onRemove();
  }
}
