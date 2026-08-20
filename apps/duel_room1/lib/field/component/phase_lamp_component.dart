import 'package:duelink/duelink.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:duel_room1/field/duel_field_world.dart';

/// Flame 版阶段指示灯：渲染在 [DuelFieldWorld] 中，紧贴 self_grave（墓地）
/// 卡槽的右上角。
///
/// 尺寸固定为 [DuelFieldLayout.phaseLampSize]：duel_flame_game 的锚点上报
/// 按该尺寸计算，随文本自适应会让 Flame 组件与 Flutter 侧锚点错位。
/// 阶段名超出可用宽度时按比例缩小字号（onLoad 对全部阶段名测量一次，
/// 各阶段字号一致）；不超宽时保持原字号，视觉不变。
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
  // （垂直方向无 padding 常量：固定高度下文本块在 render 中垂直居中）
  static const _padLeft = 14.0;
  static const _padRight = 14.0;
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

  /// 固定尺寸下文本的可用宽度（扣除左边距/圆点/间距与右边距）。
  static double get _textMaxWidth =>
      DuelFieldLayout.phaseLampWidth - _textStartX - _padRight;

  // 固定尺寸下相对锚点卡槽中心的偏移（几何推导见 DuelFieldLayout.phaseLampOffset）。
  static final _offsetVector = Vector2(
    DuelFieldLayout.phaseLampOffset.dx,
    DuelFieldLayout.phaseLampOffset.dy,
  );

  /// 超宽时使用的缩放画笔（null = 原字号即可放下，保持逐像素一致）。
  TextPaint? _scaledNamePaint;
  TextPaint? _scaledSubtitlePaint;

  TextPaint get _namePaint => _scaledNamePaint ?? _phaseNamePaint;
  TextPaint get _subPaint => _scaledSubtitlePaint ?? _subtitlePaint;

  bool _enabled = false;

  /// 上次投影锚点标量：update 中先比标量，未变则不分配/赋值
  /// （原实现每帧 _projectedPosition 分配 3-4 个 Vector2 只为发现位置没变；
  /// 位置只依赖固定 size 与投影锚点）。
  double _lastAnchorX = double.nan;
  double _lastAnchorY = double.nan;

  PhaseLampComponent({this.onTap, this.enabledGetter})
    : super(
        anchor: Anchor.center,
        size: Vector2(
          DuelFieldLayout.phaseLampWidth,
          DuelFieldLayout.phaseLampHeight,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _fitTextScale();
    _syncPosition();
    _refreshEnabled();
  }

  /// 快照变更后由 [DuelFieldWorld.refreshPhaseLamp] 调用：
  /// 重测字号缩放（覆盖字体晚解析的场景，等同旧实现的重测时机）
  /// 并刷新可点击态（替代旧实现的 store addListener）。
  /// 尺寸固定且字号缩放对所有阶段名预算过，阶段切换无需重排。
  void notifyStateChanged() {
    if (!isLoaded) return;
    _fitTextScale();
    _refreshEnabled();
  }

  void _refreshEnabled() {
    _enabled = enabledGetter?.call() ?? false;
  }

  /// 固定 132pt 宽内放下最长的阶段名：对全部阶段名与副标题测量一次，
  /// 超宽则按同一因子缩小字号（各阶段字号一致，不跳动）。
  void _fitTextScale() {
    var textWidth = _subtitlePaint.getLineMetrics('CURRENT PHASE').width;
    for (final phase in DuelPhase.values) {
      final w = _phaseNamePaint.getLineMetrics(_phaseName(phase)).width;
      if (w > textWidth) textWidth = w;
    }
    if (textWidth <= _textMaxWidth) return;
    final scale = _textMaxWidth / textWidth;
    _scaledNamePaint = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: 11 * scale,
        fontWeight: FontWeight.w900,
        fontFamily: 'Orbitron',
        letterSpacing: 0.6 * scale,
      ),
    );
    _scaledSubtitlePaint = TextPaint(
      style: TextStyle(
        color: const Color(0xFF8B9BB4),
        fontSize: 10 * scale,
        fontWeight: FontWeight.w800,
        fontFamily: 'Orbitron',
      ),
    );
  }

  /// 投影锚点 + 固定偏移得到灯中心位置；锚点标量未变时不分配/赋值。
  void _syncPosition() {
    final anchor = world.project3D(_refBoardX, _refBoardY);
    if (anchor.x == _lastAnchorX && anchor.y == _lastAnchorY) return;
    _lastAnchorX = anchor.x;
    _lastAnchorY = anchor.y;
    position = anchor + _offsetVector;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncPosition();
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
    final nameMetrics = _namePaint.getLineMetrics(name);
    final subMetrics = _subPaint.getLineMetrics('CURRENT PHASE');
    final blockHeight = nameMetrics.height + subMetrics.height;
    final textTop = -blockHeight / 2;

    _namePaint.render(
      canvas,
      name,
      Vector2(-w / 2 + _textStartX, textTop),
      anchor: Anchor.topLeft,
    );
    _subPaint.render(
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
