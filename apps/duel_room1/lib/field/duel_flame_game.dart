import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:biz/duel/models/field_card.dart';

import 'duel_field_world.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';

/// 决斗场地 FlameGame：只持有 [DuelFieldWorld] 与观察它的
/// [CameraComponent]，负责鼠标视差输入与 Flutter 侧锚点上报。
/// 场地内容（棋盘、卡槽）全部挂在 world 下。
///
/// 数据来源：widget 层（DuelFieldPage）watch biz/duel 的 Riverpod
/// Provider 后，把 [FlameFieldSnapshot] 经 [applySnapshot] 推入本游戏；
/// Flame 侧不订阅任何 Provider（渲染循环与状态管理解耦）。
class DuelFlameGame extends FlameGame<DuelFieldWorld>
    with MouseMovementDetector {
  static final _phaseLampSize = DuelFieldLayout.phaseLampSize;

  /// 沉浸式布局参数：把卡槽阵列在「扣除 HUD 的可见区」内最大化铺满。
  /// 所有数值均为世界/像素坐标（project3D 恒等时两者相等）。
  //
  /// 卡槽阵列内容尺寸（含 hover 中心缩放的小幅溢出与边距余量）。
  /// 注：场地卡槽的 hover 上浮(lift)当前已关闭，仅 1.12 中心缩放，
  /// 每边溢出约 4-6px，故高度取静态阵列 496 + 少量边距。
  static const _boardContentWidth = 600.0; // 2 * (colX[6] + slotWidth/2 + 边距)
  static const _boardContentHeight = 510.0; // 双方怪兽/魔陷两层 + EMZ + 边距
  /// 视口四周需为 HUD 预留的不可侵占空间（对称水平预留，用于左右状态卡；
  /// 不考虑检查器展开的覆盖）。
  static const _horizontalReserved = 96.0;
  static const _topReserved = 230.0; // 顶部 HUD + 对手手牌预留
  static const _bottomReserved = 116.0; // 己方手牌栏 height:96 + 间隙
  /// zoom 上下限。下限取很小的值：沉浸式相机的目的就是让卡槽阵列「恰好」
  /// 装进扣除 HUD 的可见区，不应被下限强行放大而溢出到上下手牌栏。
  static const _minZoom = 0.1;
  static const _maxZoom = 2.6;

  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;
  final VoidCallback? onPhaseLampTap;
  final bool Function()? isPhaseLampEnabled;

  /// 点击可放置槽位（MSG_SELECT_PLACE）的回调（槽位 key 为
  /// `controller_zone_sequence`）。
  final void Function(String slotKey)? onPlaceSlotTap;
  ValueChanged<PlaymatAnchorData>? onAnchorsChanged;

  String? _lastAnchorSignature;

  /// 当前状态快照；world 与各 component 经 `game.snapshot` 读取。
  FlameFieldSnapshot snapshot = FlameFieldSnapshot.empty();

  DuelFlameGame({
    this.onCardSelect,
    this.onZoneInspect,
    this.onPhaseLampTap,
    this.isPhaseLampEnabled,
    this.onPlaceSlotTap,
    this.onAnchorsChanged,
  }) : super(world: DuelFieldWorld());

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
    _applyImmersiveCamera();
    _emitAnchors();
  }

  /// 接收 widget 层推送的最新快照并驱动场地重建。
  ///
  /// 等价旧实现里 ChangeNotifier 监听触发的重建：每次 Riverpod 状态变更
  /// → 页面 build → 本方法。world 尚未加载完成时只替换快照引用，
  /// 首次 onLoad 会直接按最新快照构建。
  void applySnapshot(FlameFieldSnapshot next) {
    // 内容判等短路：纯 UI 状态变化（弹窗/检视/菜单）触发的页面 build
    // 也会推送快照，但 Flame 渲染字段未变时跳过全量卡槽重建。
    final changed = next != snapshot;
    snapshot = next;
    if (world.isLoaded) {
      if (changed) world.rebuildField();
      // 阶段灯不走判等短路：其可点击态依赖 phaseActionsProvider
      // （selectWindowProvider 的选择窗口/阶段动作可用性），该输入不在
      // FlameFieldSnapshot 字段里。空闲指令（MSG_SELECT_IDLE_CMD）到达时
      // 快照内容往往不变，判等短路会漏掉刷新，使灯停在禁用态点了没反应。
      world.refreshPhaseLamp();
    }
    if (changed) _emitAnchors();
  }

  /// Hot reload 支持：重建 world 全部子组件并强制重新上报锚点。
  /// 由 Flame 内置的 [onHotReload] 钩子触发（GameWidget.reassemble →
  /// game.onHotReload），无需在 Flutter State 中覆写 reassemble。
  @override
  void onHotReload() {
    super.onHotReload();
    world.reload();
    _lastAnchorSignature = null;
    _emitAnchors();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 自适应 zoom：视口尺寸变化时重算，让卡槽阵列始终铺满可见区。
    _applyImmersiveCamera();
    if (isLoaded) {
      _emitAnchors();
    }
  }

  /// 依据当前视口尺寸计算沉浸式 zoom 与 camera position。
  ///
  /// - zoom：取「可见区宽 / 棋盘内容宽」与「可见区高 / 棋盘内容高」的较小者，
  ///   保证卡槽阵列完整可见且最大化铺满。
  /// - position：把棋盘中心（世界原点）对齐到「扣除 HUD 的可见区中心」，
  ///   水平方向对称预留（左右状态卡），因此 x 中心为 0。
  void _applyImmersiveCamera() {
    final vw = size.x;
    final vh = size.y;
    if (vw <= 0 || vh <= 0) return;

    const res = _horizontalReserved;
    final availW = (vw - res * 2).clamp(1.0, vw);
    final availH = (vh - _topReserved - _bottomReserved).clamp(1.0, vh);
    final zoomW = availW / _boardContentWidth;
    final zoomH = availH / _boardContentHeight;
    final zoom = (zoomW < zoomH ? zoomW : zoomH).clamp(_minZoom, _maxZoom);

    camera.viewfinder.zoom = zoom;
    // 可见区中心相对视口中心的像素偏移，换算成世界坐标（除以 zoom）。
    // 水平预留对称，centerX = 0；y = (bottom - top)/2。
    final centerY = (_bottomReserved - _topReserved) / (2 * zoom);
    camera.viewfinder.position = Vector2(0, centerY);
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
    final selfController = snapshot.myController;
    final opponentController = 1 - selfController;
    final slotRects = <String, Rect>{};

    void addRect(String zoneKey, double boardX, double boardY) {
      final center = worldToWidget(world.project3D(boardX, boardY));
      slotRects[zoneKey] = Rect.fromCenter(
        center: center,
        width: DuelFieldLayout.slotWidth,
        height: DuelFieldLayout.slotHeight,
      );
    }

    const colX = DuelFieldLayout.colX;
    const monsterY = DuelFieldLayout.monsterY;
    const stY = DuelFieldLayout.stY;

    // SpellTrap 行: [EXTRA][S/T1-5][DECK] / [DECK][S/T5-1][EXTRA]
    // Monster 行: FIELD 与 M1-5 同一水平线。
    // 己方 [FIELD][M1-5][GRAVE]；对手 [GRAVE][M5-1][FIELD]
    // EMZ 行 (y=0): [对手BANISH colX[0]][EMZ1 -84][EMZ2 +84][己方BANISH colX[6]]

    addRect('opp_deck', colX[0], -stY);
    addRect('opp_grave', colX[0], -monsterY);
    addRect('opp_removed', colX[0], 0); // BANISH 移至 EMZ 行左侧
    addRect('opp_extra', colX[6], -stY);

    addRect('self_deck', colX[6], stY);
    addRect('self_grave', colX[6], monsterY);
    addRect('self_removed', colX[6], 0); // BANISH 移至 EMZ 行右侧（PhaseLamp 锚点）
    addRect('self_extra', colX[0], stY);

    addRect('${selfController}_8_5', colX[0], monsterY);
    addRect('${opponentController}_8_5', colX[6], -monsterY);

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
    // EMZ 物理槽位双方镜像：己方 s5 ↔ 对手 s6（emz1），己方 s6 ↔ 对手 s5（emz2）。
    slotRects['${selfController}_4_5'] = emz1Rect;
    slotRects['${opponentController}_4_6'] = emz1Rect;
    slotRects['${selfController}_4_6'] = emz2Rect;
    slotRects['${opponentController}_4_5'] = emz2Rect;

    final phaseReference =
        slotRects['self_grave'] ??
        slotRects['self_removed'] ??
        slotRects['${selfController}_4_4'];
    final phaseLampRect = phaseReference == null
        ? Rect.fromLTWH(
            viewport.width * DuelFieldLayout.phaseLampFallbackRatio.dx,
            viewport.height * DuelFieldLayout.phaseLampFallbackRatio.dy,
            _phaseLampSize.width,
            _phaseLampSize.height,
          )
        : Rect.fromCenter(
            center: Offset(
              phaseReference.center.dx + DuelFieldLayout.phaseLampOffset.dx,
              phaseReference.center.dy + DuelFieldLayout.phaseLampOffset.dy,
            ),
            width: _phaseLampSize.width,
            height: _phaseLampSize.height,
          );

    return PlaymatAnchorData(
      slotRects: slotRects,
      phaseLampRect: phaseLampRect,
    );
  }
}
