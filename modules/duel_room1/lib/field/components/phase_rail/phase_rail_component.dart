import 'dart:math';

import 'package:duelink/duelink.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:duel_room1/field/duel_field_world.dart';
import 'package:duel_room1/field/components/phase_rail/phase_rail_layout.dart';

/// 阶段轨道：棋盘右侧的垂直阶段按钮列（DP/SP/M1/BP/M2/EP），
/// 顶部（DP 上方）挂回合徽章（T{n} · 我方/对方），
/// 末端（EP 下方）挂一个阶段操作菜单按钮（≡）。
///
/// 视觉语义：
/// - 已过阶段：青色淡填充（本回合已走过的流程）；
/// - 当前阶段：发光胶囊（纯展示，不可点击）；
/// - 未到阶段：暗色空心；
/// - idle（回合间隙）：全部按未到处理；
/// - 末端按钮（≡）：阶段菜单的唯一点击入口，可点击时呼吸发光；
///   胶囊区域不响应点击。
///
/// 几何全部来自 [PhaseRailLayout]（纯数据，单测锁定与相机内容宽度的
/// 关系）；组件尺寸固定，duel_flame_game 的菜单锚点按同一几何上报。
class PhaseRailComponent extends PositionComponent
    with TapCallbacks, HasWorldReference<DuelFieldWorld> {
  final VoidCallback? onTap;
  final bool Function()? enabledGetter;

  /// 当前阶段（经游戏快照读取，widget 层推送）。
  DuelPhase get _phase => world.game.snapshot.phase;

  /// 轨道四周为辉光/底色预留的边距。
  static const _haloMargin = 10.0;

  static const _accent = Color(0xFF00F0FF);

  // ── 渲染缓存 ──
  static final _dockFillPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.28);
  static final _dockBorderPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.07)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _connectorPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.10)
    ..strokeWidth = 1.5;

  static final _futureFillPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35);
  static final _futureBorderPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _pastFillPaint = Paint()
    ..color = _accent.withValues(alpha: 0.14);
  static final _pastBorderPaint = Paint()
    ..color = _accent.withValues(alpha: 0.40)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _currentFillPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.55);
  static final _currentBorderPaint = Paint()
    ..color = _accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  /// 当前胶囊的呼吸辉光（透明度每帧随脉动更新）。
  final Paint _currentGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  static final _futureTextPaint = TextPaint(
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.30),
      fontSize: 8.5,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 1.0,
    ),
  );
  static final _pastTextPaint = TextPaint(
    style: TextStyle(
      color: _accent.withValues(alpha: 0.80),
      fontSize: 8.5,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 1.0,
    ),
  );
  static final _currentTextPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 1.0,
    ),
  );

  bool _enabled = false;
  double _time = 0;

  /// 上次投影位置标量：未变则不重新赋值（同 PhaseLamp 时代的优化）。
  double _lastAnchorX = double.nan;
  double _lastAnchorY = double.nan;

  PhaseRailComponent({this.onTap, this.enabledGetter})
    : super(
        anchor: Anchor.center,
        size: Vector2(
          PhaseRailLayout.turnBadgeWidth + _haloMargin * 2,
          PhaseRailLayout.heightWithBadgeAndButton + _haloMargin * 2,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncPosition();
    _refreshEnabled();
  }

  /// 快照变更后由 [DuelFieldWorld.refreshPhaseRail] 调用：刷新可点击态
  /// （阶段文本固定六个短码，无需重测字号）。
  void notifyStateChanged() {
    if (!isLoaded) return;
    _refreshEnabled();
  }

  void _refreshEnabled() {
    _enabled = enabledGetter?.call() ?? false;
  }

  void _syncPosition() {
    // 组件含末端按钮，几何中心相对胶囊区中心（centerY）下移
    // actionButtonShift，胶囊区因此仍居中于棋盘中线。
    final anchor = world.project3D(
      PhaseRailLayout.centerX,
      PhaseRailLayout.centerY + PhaseRailLayout.actionButtonShift,
    );
    if (anchor.x == _lastAnchorX && anchor.y == _lastAnchorY) return;
    _lastAnchorX = anchor.x;
    _lastAnchorY = anchor.y;
    position = anchor;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _syncPosition();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    // 上半段（胶囊区）仍按 centerY 居中绘制：组件中心被按钮下移，
    // 这里反向平移回去。
    canvas.translate(
      size.x / 2,
      size.y / 2 - PhaseRailLayout.actionButtonShift,
    );

    final count = PhaseRailLayout.phases.length;
    final currentIndex = PhaseRailLayout.orderIndex(_phase);

    // 1. 整条轨道的底板（含顶部徽章与末端按钮区，提升在棋盘上的可读性）。
    final dockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, PhaseRailLayout.actionButtonShift),
        width: PhaseRailLayout.turnBadgeWidth + 8,
        height: PhaseRailLayout.heightWithBadgeAndButton + 8,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(dockRect, _dockFillPaint);
    canvas.drawRRect(dockRect, _dockBorderPaint);

    // 2. 首尾节点间的连接线。
    canvas.drawLine(
      Offset(0, PhaseRailLayout.pillCenterY(0)),
      Offset(0, PhaseRailLayout.pillCenterY(count - 1)),
      _connectorPaint,
    );

    // 3. 逐节点绘制阶段胶囊。
    for (var i = 0; i < count; i++) {
      final centerY = PhaseRailLayout.pillCenterY(i);
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, centerY),
          width: PhaseRailLayout.pillWidth,
          height: PhaseRailLayout.pillHeight,
        ),
        const Radius.circular(PhaseRailLayout.pillHeight / 2),
      );
      if (i == currentIndex) {
        _renderCurrentPill(canvas, pill);
      } else if (currentIndex >= 0 && i < currentIndex) {
        _renderStyledPill(
          canvas,
          pill,
          _pastFillPaint,
          _pastBorderPaint,
          _pastTextPaint,
          i,
        );
      } else {
        _renderStyledPill(
          canvas,
          pill,
          _futureFillPaint,
          _futureBorderPaint,
          _futureTextPaint,
          i,
        );
      }
    }

    // 4. 顶部回合徽章（T{n} · 我方/对方）。
    _renderTurnBadge(canvas);

    // 5. 末端阶段操作菜单按钮（≡）。
    _renderActionButton(canvas);

    canvas.restore();
  }

  static final _turnTextSelfPaint = TextPaint(
    style: const TextStyle(
      color: _accent,
      fontSize: 9,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 0.6,
    ),
  );
  static final _turnTextOppPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF9FBB),
      fontSize: 9,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 0.6,
    ),
  );

  /// 顶部回合徽章：第几回合 + 当前行动方。我方回合青色描边/文字，
  /// 对方回合粉红；turnCount 未下发（0）时徽章整体降级为暗色。
  void _renderTurnBadge(Canvas canvas) {
    final snapshot = world.game.snapshot;
    final isMyTurn = snapshot.currentPlayer == snapshot.myController;
    final active = snapshot.turnCount > 0;
    final accent = isMyTurn ? _accent : const Color(0xFFFF4B82);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, PhaseRailLayout.turnBadgeCenterY),
        width: PhaseRailLayout.turnBadgeWidth,
        height: PhaseRailLayout.turnBadgeHeight,
      ),
      const Radius.circular(PhaseRailLayout.turnBadgeHeight / 2),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: active ? 0.55 : 0.35),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = active ? accent : Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.4 : 1.0,
    );
    final label = active
        ? 'T${snapshot.turnCount} · ${isMyTurn ? '我方' : '对方'}'
        : '--';
    (isMyTurn ? _turnTextSelfPaint : _turnTextOppPaint).render(
      canvas,
      label,
      Vector2(0, PhaseRailLayout.turnBadgeCenterY),
      anchor: Anchor.center,
    );
  }

  /// 阶段操作菜单按钮：可点击时呼吸发光（同当前阶段胶囊语义），
  /// 不可点击时暗色降级。图标为手绘三线，避免引入字体图标依赖。
  void _renderActionButton(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, PhaseRailLayout.actionButtonCenterY),
        width: PhaseRailLayout.actionButtonWidth,
        height: PhaseRailLayout.actionButtonHeight,
      ),
      const Radius.circular(PhaseRailLayout.actionButtonHeight / 2),
    );
    if (_enabled) {
      final pulse = 0.30 + 0.20 * sin(_time * 3.2);
      canvas.drawRRect(
        rect,
        _currentGlowPaint..color = _accent.withValues(alpha: pulse),
      );
      canvas.drawRRect(rect, _currentFillPaint);
      canvas.drawRRect(rect, _currentBorderPaint);
    } else {
      canvas.drawRRect(rect, _futureFillPaint);
      canvas.drawRRect(rect, _futureBorderPaint);
    }
    final iconColor = _enabled
        ? _accent
        : Colors.white.withValues(alpha: 0.30);
    final iconPaint = Paint()
      ..color = iconColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const iconHalfWidth = 6.0;
    const iconSpacing = 4.0;
    final cy = PhaseRailLayout.actionButtonCenterY;
    for (var i = -1; i <= 1; i++) {
      final y = cy + i * iconSpacing;
      canvas.drawLine(
        Offset(-iconHalfWidth, y),
        Offset(iconHalfWidth, y),
        iconPaint,
      );
    }
  }

  void _renderStyledPill(
    Canvas canvas,
    RRect pill,
    Paint fill,
    Paint border,
    TextPaint textPaint,
    int index,
  ) {
    canvas.drawRRect(pill, fill);
    canvas.drawRRect(pill, border);
    textPaint.render(
      canvas,
      PhaseRailLayout.shortLabels[index],
      Vector2(pill.center.dx, pill.center.dy),
      anchor: Anchor.center,
    );
  }

  /// 当前阶段胶囊：高亮描边 + 白字 + 恒定辉光（胶囊不可点，
  /// 呼吸脉动只保留在末端菜单按钮上）。
  void _renderCurrentPill(Canvas canvas, RRect pill) {
    const pulse = 0.22;
    canvas.drawRRect(
      pill,
      _currentGlowPaint..color = _accent.withValues(alpha: pulse),
    );
    canvas.drawRRect(pill, _currentFillPaint);
    canvas.drawRRect(pill, _currentBorderPaint);
    _currentTextPaint.render(
      canvas,
      PhaseRailLayout.shortLabels[PhaseRailLayout.orderIndex(_phase)],
      Vector2(pill.center.dx, pill.center.dy),
      anchor: Anchor.center,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 仅末端「阶段菜单」按钮响应点击：阶段胶囊纯展示，不弹菜单。
    if (!_enabled) return;
    final buttonCenter = Vector2(
      size.x / 2,
      size.y / 2 -
          PhaseRailLayout.actionButtonShift +
          PhaseRailLayout.actionButtonCenterY,
    );
    final p = event.localPosition;
    final inButton =
        (p.x - buttonCenter.x).abs() <=
            PhaseRailLayout.actionButtonWidth / 2 &&
        (p.y - buttonCenter.y).abs() <=
            PhaseRailLayout.actionButtonHeight / 2;
    if (inButton) onTap?.call();
  }
}
