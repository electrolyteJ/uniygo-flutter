import 'package:duelink/duelink.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:duel_room1/field/duel_field_world.dart';

/// Flame 版阶段指示灯：渲染在 [DuelFieldWorld] 中，紧贴 self_removed（Banish / 除外）
/// 卡槽的右上角。
///
/// 宽高不写死，根据阶段名文本实际测量值自适应。
/// 视觉与 Flutter 侧 [PhaseLamp] widget 保持一致（深色玻璃底、青色指示点、
/// 阶段名 + CURRENT PHASE 副标题）。点击触发 [onTap]（通常为切换阶段菜单）。
class PhaseLampComponent extends PositionComponent
    with TapCallbacks, HasWorldReference<DuelFieldWorld> {
  final VoidCallback? onTap;
  final bool Function()? enabledGetter;

  /// 当前阶段（经游戏快照读取，widget 层推送）。
  DuelPhase get _phase => world.game.snapshot.phase;

  // 锚点卡槽 (self_grave / 墓地) 的棋盘坐标，取自布局常量。
  // 己方墓地位于 Monster 行 colX[6]=252 / monsterY=100，PhaseLamp 左下边 = 墓地卡槽右上边 + (gap, -gap)。
  static final _refBoardX = DuelFieldLayout.phaseLampRefBoardX; // 252 (colX[6])
  static final _refBoardY =
      DuelFieldLayout.phaseLampRefBoardY; // 100 (monsterY)

  // ── 内边距与布局常量 ──
  static const _padLeft = 14.0;
  static const _padRight = 14.0;
  static const _padTop = 8.0;
  static const _padBottom = 8.0;
  static const _dotRadius = 7.0; // 外发光半径
  static const _dotSolidRadius = 5.0; // 实心点半径
  static const _dotTextGap = 6.0; // 圆点右沿到文本起始的间距
  static const _cornerRadius = 18.0;

  // 派生：圆点中心 x = 左边距 + 半径；文本起始 x = 圆点右沿 + 间距
  static double get _dotCenterX => _padLeft + _dotRadius; // 21
  static double get _textStartX => _dotCenterX + _dotRadius + _dotTextGap; // 34

  static const _accent = Color(0xFF00F0FF);

  static final _phaseNamePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 0.6,
    ),
  );
  static final _subtitlePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFF8B9BB4),
      fontSize: 10,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  bool _enabled = false;

  PhaseLampComponent({this.onTap, this.enabledGetter})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _updateSize();
    position = _projectedPosition();
    _refreshEnabled();
  }

  /// 快照变更后由 [DuelFieldWorld.refreshPhaseLamp] 调用：
  /// 重测阶段名尺寸并刷新可点击态（替代旧实现的 store addListener）。
  void notifyStateChanged() {
    if (!isLoaded) return;
    _updateSize();
    _refreshEnabled();
  }

  void _refreshEnabled() {
    _enabled = enabledGetter?.call() ?? false;
  }

  /// 根据当前阶段名文本的实际测量值更新组件尺寸。
  void _updateSize() {
    final name = _phaseName(_phase);
    final nameMetrics = _phaseNamePaint.getLineMetrics(name);
    final subMetrics = _subtitlePaint.getLineMetrics('CURRENT PHASE');

    final textWidth = nameMetrics.width > subMetrics.width
        ? nameMetrics.width
        : subMetrics.width;
    final textHeight = nameMetrics.height + subMetrics.height;

    size = Vector2(
      _textStartX + textWidth + _padRight,
      _padTop + textHeight + _padBottom,
    );
  }

  /// 根据实际尺寸动态计算偏移，使灯的左下角始终落在锚点卡槽右上角
  /// 外侧 [DuelFieldLayout.phaseLampGap] 像素处。
  Vector2 _projectedPosition() {
    final w = size.x;
    final h = size.y;
    final dx =
        (DuelFieldLayout.slotWidth + w) / 2 + DuelFieldLayout.phaseLampGap;
    final dy =
        -((DuelFieldLayout.slotHeight + h) / 2 + DuelFieldLayout.phaseLampGap);
    return world.project3D(_refBoardX, _refBoardY) + Vector2(dx, dy);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final newPos = _projectedPosition();
    if ((position - newPos).length > 0.01) {
      position = newPos;
    }
  }

  @override
  void render(Canvas canvas) {
    final border = _enabled ? _accent : Colors.white.withValues(alpha: 0.14);
    final w = size.x;
    final h = size.y;

    canvas.save();
    canvas.translate(w / 2, h / 2);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(_cornerRadius),
    );

    // 可点击时的外发光（先画，被背景压住形成光晕）
    if (_enabled) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _accent.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // 深色玻璃背景
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 青色指示点（外发光 + 实心）
    final dotCenter = Offset(-w / 2 + _dotCenterX, 0);
    canvas.drawCircle(
      dotCenter,
      _dotRadius,
      Paint()
        ..color = _accent.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(dotCenter, _dotSolidRadius, Paint()..color = _accent);

    // 阶段名 + 副标题（文本块垂直居中）
    final name = _phaseName(_phase);
    final nameMetrics = _phaseNamePaint.getLineMetrics(name);
    final subMetrics = _subtitlePaint.getLineMetrics('CURRENT PHASE');
    final blockHeight = nameMetrics.height + subMetrics.height;
    final textTop = -blockHeight / 2;

    _phaseNamePaint.render(
      canvas,
      name,
      Vector2(-w / 2 + _textStartX, textTop),
      anchor: Anchor.topLeft,
    );
    _subtitlePaint.render(
      canvas,
      'CURRENT PHASE',
      Vector2(-w / 2 + _textStartX, textTop + nameMetrics.height),
      anchor: Anchor.topLeft,
    );

    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_enabled) onTap?.call();
  }

  String _phaseName(DuelPhase phase) {
    switch (phase) {
      case DuelPhase.dp:
        return 'DRAW PHASE';
      case DuelPhase.sp:
        return 'STANDBY PHASE';
      case DuelPhase.m1:
        return 'MAIN PHASE 1';
      case DuelPhase.bp:
        return 'BATTLE PHASE';
      case DuelPhase.m2:
        return 'MAIN PHASE 2';
      case DuelPhase.ep:
        return 'END PHASE';
      default:
        return 'PHASE';
    }
  }
}
