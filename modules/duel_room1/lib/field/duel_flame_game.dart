import 'package:biz/duel/models/playmat_anchor_data.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:biz/duel/models/draw_animation_event.dart';
import 'package:biz/duel/models/field_card.dart';

import 'components/card_flight_component.dart';
import 'components/hand_card/hand_bar_component.dart';
import 'components/lp/lp_change_toast_component.dart';
import 'duel_field_world.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/components/phase_rail/phase_rail_layout.dart';

/// 决斗场地 FlameGame：只持有 [DuelFieldWorld] 与观察它的
/// [CameraComponent]，负责鼠标视差输入与 Flutter 侧锚点上报。
/// 场地内容（棋盘、卡槽）全部挂在 world 下。
///
/// 数据来源：widget 层（DuelFieldPage）watch biz/duel 的 Riverpod
/// Provider 后，把 [FlameFieldSnapshot] 经 [applySnapshot] 推入本游戏；
/// Flame 侧不订阅任何 Provider（渲染循环与状态管理解耦）。
class DuelFlameGame extends FlameGame<DuelFieldWorld>
    with MouseMovementDetector {
  /// 阶段轨道（右侧垂直阶段按钮列，含末端阶段菜单按钮）的组件尺寸，
  /// 锚点上报用同一几何。
  static final _phaseRailSize = Size(
    PhaseRailLayout.turnBadgeWidth + 20,
    PhaseRailLayout.heightWithBadgeAndButton + 20,
  );

  /// 沉浸式布局参数：把卡槽阵列在「扣除 HUD 的可见区」内最大化铺满。
  /// 所有数值均为世界/像素坐标（project3D 恒等时两者相等）。
  //
  /// 卡槽阵列内容尺寸（含 hover 中心缩放的小幅溢出与边距余量）。
  /// 注：场地卡槽的 hover 上浮(lift)当前已关闭，仅 1.12 中心缩放，
  /// 每边溢出约 4-6px，故高度取静态阵列 496 + 少量边距。
  /// 宽度覆盖右侧阶段轨道与左侧玩家状态卡（见
  /// PhaseRailLayout.contentHalfExtent），横屏高度受限场景 zoom 不变，
  /// 左右附件免费入镜。
  static final _boardContentWidth = PhaseRailLayout.boardContentWidth;
  static const _boardContentHeight = 510.0; // 双方怪兽/魔陷两层 + EMZ + 边距
  /// 视口四周需为 HUD 预留的不可侵占空间。水平预留已收窄：左右状态卡
  /// 已下沉为世界内组件（计入棋盘内容宽），不再占用 HUD 预留。
  static const _horizontalReserved = 24.0;
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

  /// 点击己方手牌的回调（下标, 卡码）。
  final void Function(int index, int code)? onHandCardTap;
  ValueChanged<PlaymatAnchorData>? onAnchorsChanged;

  /// 己方（底部）/对方（顶部）手牌栏：viewport 层组件，屏幕空间固定尺寸。
  /// onLoad 时挂载；挂载前为空，读取方需判空。
  HandBarComponent? selfHandBar;
  HandBarComponent? oppHandBar;

  /// 对方手牌栏顶部 y（页面按 HUD 高度推入）。
  double _oppHandTopY = 0;

  /// 播放中的抽卡/发牌飞行动画（新对局时统一清除）。
  final Set<CardFlightComponent> _flights = {};

  /// 播放中的移动飞牌动画（CardMoveAnimator 注册；新对局统一清除）。
  final Set<CardFlightComponent> moveFlights = {};

  /// 移动飞牌期间隐藏的目标场上槽位 key（controller_zone_sequence）：
  /// 飞行完成前目标槽位不显示该卡（ZonesComponent 重建时跳过）。
  final Set<String> concealedMoveTargetKeys = {};

  String? _lastAnchorSignature;

  /// 当前状态快照；world 与各 component 经 `game.snapshot` 读取。
  FlameFieldSnapshot snapshot = FlameFieldSnapshot.empty();

  DuelFlameGame({
    this.onCardSelect,
    this.onZoneInspect,
    this.onPhaseLampTap,
    this.isPhaseLampEnabled,
    this.onPlaceSlotTap,
    this.onHandCardTap,
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
    // 手牌栏挂 viewport（屏幕空间 HUD 层）：不随场地相机缩放。
    // 双方在首帧即常驻挂载，可见性由 setHudVisible 控制。
    oppHandBar = HandBarComponent(isSelfSide: false)
      ..hudTopY = _oppHandTopY;
    selfHandBar = HandBarComponent(
      isSelfSide: true,
      onCardTap: onHandCardTap,
    );
    camera.viewport.addAll([oppHandBar!, selfHandBar!]);
    // LP 变动 toast：与手牌栏同层（viewport 屏幕空间），
    // 锚定受影响玩家手牌栏附近。
    camera.viewport.addAll([
      LpChangeToastComponent(isSelf: false),
      LpChangeToastComponent(isSelf: true),
    ]);
    _applyImmersiveCamera();
    _emitAnchors();
  }

  /// 接收 widget 层推送的最新快照并驱动场地重建。
  ///
  /// 由页面侧的 listenManual 订阅驱动（board/select/confirm/overlay
  /// 任一 provider 变更 → 页面组快照并推送，不经 build）。
  /// world 尚未加载完成时只替换快照引用，
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
      world.refreshPhaseRail();
    }
    // 手牌栏独立差分更新：不依赖 world 加载态（viewport 子树自己维护），
    // 组件未挂载时 applySnapshot 为空操作，挂载时按其 onLoad 读快照补齐。
    selfHandBar?.applySnapshot(next.selfHand);
    oppHandBar?.applySnapshot(next.oppHand);
    if (changed) _emitAnchors();
  }

  /// 手牌栏可见性（页面按对局阶段推入）：等待室/猜拳等阶段
  /// 场地页仅作背景时隐藏。手牌栏挂载晚于首次推入时由其
  /// onLoad 读取本值补齐。
  bool _handBarsVisible = false;

  /// 手牌栏当前是否应可见（HandBarComponent.onLoad 读取）。
  bool get handBarsVisible => _handBarsVisible;

  /// HUD（手牌栏）可见性：等待室/猜拳等阶段场地页仅作背景时隐藏。
  void setHandBarsVisible(bool visible) {
    _handBarsVisible = visible;
    selfHandBar?.barVisible = visible;
    oppHandBar?.barVisible = visible;
  }

  /// 页面推入对方手牌栏顶部 y（含状态栏/顶部 HUD 高度的视口坐标）。
  void setOppHandTopY(double y) {
    if (_oppHandTopY == y) return;
    _oppHandTopY = y;
    // setHudTopY 内部触发重排：页面在 build 路径推值，手牌栏可能已
    // 布局完毕，只改字段会让对方栏停在旧位置直到下一次快照/缩放。
    oppHandBar?.setHudTopY(y);
  }

  /// 选中己方手牌的屏幕矩形（Flutter 操作菜单的锚定，拉式查询）。
  Rect? selectedHandCardRect() => selfHandBar?.selectedCardRect();

  /// 阶段轨道末端「阶段菜单按钮」的屏幕矩形（阶段菜单的锚定，
  /// 拉式查询），与卡槽/手牌矩形同一几何口径（世界坐标 × zoom）。
  Rect phaseActionButtonRect() {
    final zoom = camera.viewfinder.zoom;
    final center = worldToWidget(
      world.project3D(
        PhaseRailLayout.centerX,
        PhaseRailLayout.centerY + PhaseRailLayout.actionButtonCenterY,
      ),
    );
    return Rect.fromCenter(
      center: center,
      width: PhaseRailLayout.actionButtonWidth * zoom,
      height: PhaseRailLayout.actionButtonHeight * zoom,
    );
  }

  /// 卡组槽位的屏幕矩形（抽卡/发牌飞行起点），与锚点上报同一几何。
  Rect deckSlotWidgetRect(bool isSelf) {
    final zoom = camera.viewfinder.zoom;
    final boardPos = DuelFieldLayout.deckSlotPos(isSelf: isSelf);
    final center = worldToWidget(world.project3D(boardPos.dx, boardPos.dy));
    return Rect.fromCenter(
      center: center,
      width: DuelFieldLayout.slotWidth * zoom,
      height: DuelFieldLayout.slotHeight * zoom,
    );
  }

  /// 抽卡事件提交（含排队）时预隐藏目标卡位：新抽的卡追加在手牌末尾，
  /// 隐藏末尾 N 张并返回其下标。
  ///
  /// 必须在事件「入队时」而非「开播时」隐藏：连续抽卡（开局发牌是
  /// 我方/对方两条 MSG_DRAW，或天使的施舍抽多张）时，排队事件的手牌
  /// 若等开播才隐藏，会先亮在手牌栏里、动画再叠着飞一遍。
  List<int> concealDrawTargets(DrawAnimationEvent event) {
    final bar = event.player == snapshot.myController
        ? selfHandBar
        : oppHandBar;
    return bar?.concealTrailing(event.codes.length) ?? const [];
  }

  /// 播放一次抽卡/发牌飞行动画：卡组槽位 → 手牌栏卡位，
  /// 逐张落地时揭示对应手牌；[onDone] 在整段播放完成后回调
  /// （页面据此推进 DrawAnimationQueue）。
  ///
  /// [targetIndices] 为 [concealDrawTargets] 在事件入队时返回的下标
  /// （隐藏与飞行的关联）；终点矩形在开播时按当前扇形排布现算。
  void playDrawFlight(
    DrawAnimationEvent event,
    List<int> targetIndices,
    VoidCallback onDone,
  ) {
    final isSelf = event.player == snapshot.myController;
    final bar = isSelf ? selfHandBar : oppHandBar;
    if (bar == null || targetIndices.isEmpty) {
      onDone();
      return;
    }
    final indices = targetIndices;
    final targets = [for (final i in indices) bar.cardSlotRect(i)];
    // late final：onAllDone 闭包在动画完成后才执行，届时已赋值。
    late final CardFlightComponent flight;
    flight = CardFlightComponent(
      codes: event.codes,
      // 己方抽卡显示卡面；对方抽卡显示卡背（revealCard 为公开抽卡例外）。
      faceUp: isSelf || event.revealCard,
      source: deckSlotWidgetRect(isSelf),
      targets: targets,
      onCardArrived: (i) {
        if (i < indices.length) bar.reveal(indices[i]);
      },
      onAllDone: () {
        _flights.remove(flight);
        onDone();
      },
    );
    _flights.add(flight);
    camera.viewport.add(flight);
  }

  /// 新对局开始（MSG_START）：取消未播完的飞行并揭示全部手牌，
  /// 避免上一局残留的动画飞进新局。
  void cancelDrawFlights() {
    for (final flight in _flights.toList()) {
      flight.removeFromParent();
    }
    _flights.clear();
    // 移动飞牌一并取消，隐藏的场上目标槽位解除隐藏并重建。
    for (final flight in moveFlights.toList()) {
      flight.removeFromParent();
    }
    moveFlights.clear();
    if (concealedMoveTargetKeys.isNotEmpty) {
      concealedMoveTargetKeys.clear();
      world.rebuildField();
    }
    selfHandBar?.revealAll();
    oppHandBar?.revealAll();
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
    // 预留量随视口高度收缩：横屏/矮视口下固定预留（230+116）可能
    // 吃掉整个屏高，把 availH 钳到 1、zoom 锁死下限、棋盘缩成一条缝。
    // 预留总量超过半屏时等比压缩，保证至少留一半高度给棋盘；
    // 竖屏高视口（vh ≳ 692）下总预留不超半屏，行为不变。
    var topReserved = _topReserved;
    var bottomReserved = _bottomReserved;
    final maxReserved = vh * 0.5;
    final totalReserved = topReserved + bottomReserved;
    if (totalReserved > maxReserved) {
      final scale = maxReserved / totalReserved;
      topReserved *= scale;
      bottomReserved *= scale;
    }
    final availH = (vh - topReserved - bottomReserved).clamp(1.0, vh);
    final zoomW = availW / _boardContentWidth;
    final zoomH = availH / _boardContentHeight;
    final zoom = (zoomW < zoomH ? zoomW : zoomH).clamp(_minZoom, _maxZoom);

    camera.viewfinder.zoom = zoom;
    // 可见区中心相对视口中心的像素偏移，换算成世界坐标（除以 zoom）。
    // 水平预留对称，centerX = 0；y = (bottom - top)/2。
    final centerY = (bottomReserved - topReserved) / (2 * zoom);
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

    // 槽位尺寸与阶段灯偏移均为世界单位，输出到 widget 坐标系需乘以
    // 相机 zoom（中心点已经 worldToWidget 完成 zoom 换算，是对的）。
    // zoom 变化后 rect 随之变化，signature 覆盖 center 与 width/height，
    // 会重新 emit。
    final zoom = camera.viewfinder.zoom;
    final slotW = DuelFieldLayout.slotWidth * zoom;
    final slotH = DuelFieldLayout.slotHeight * zoom;

    void addRect(String zoneKey, double boardX, double boardY) {
      final center = worldToWidget(world.project3D(boardX, boardY));
      slotRects[zoneKey] = Rect.fromCenter(
        center: center,
        width: slotW,
        height: slotH,
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
      width: slotW,
      height: slotH,
    );
    final emz2Rect = Rect.fromCenter(
      center: worldToWidget(world.project3D(84.0, 0)),
      width: slotW,
      height: slotH,
    );
    // EMZ 物理槽位双方镜像：己方 s5 ↔ 对手 s6（emz1），己方 s6 ↔ 对手 s5（emz2）。
    slotRects['${selfController}_4_5'] = emz1Rect;
    slotRects['${opponentController}_4_6'] = emz1Rect;
    slotRects['${selfController}_4_6'] = emz2Rect;
    slotRects['${opponentController}_4_5'] = emz2Rect;

    // 阶段轨道位置固定（PhaseRailLayout.centerX/centerY，棋盘中线右侧），
    // 不依赖卡槽锚点，直接由世界坐标换算。含末端按钮后几何中心较
    // 胶囊区中心下移 actionButtonShift（与组件 _syncPosition 同一偏移）。
    final railCenter = worldToWidget(
      world.project3D(
        PhaseRailLayout.centerX,
        PhaseRailLayout.centerY + PhaseRailLayout.actionButtonShift,
      ),
    );
    final phaseLampRect = Rect.fromCenter(
      center: railCenter,
      width: _phaseRailSize.width * zoom,
      height: _phaseRailSize.height * zoom,
    );

    return PlaymatAnchorData(
      slotRects: slotRects,
      phaseLampRect: phaseLampRect,
    );
  }
}
