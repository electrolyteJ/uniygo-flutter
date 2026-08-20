import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:duel_room1/field/duel_field_world.dart';

// 仅在世界坐标系内做自定义绘制，不涉及 size/anchor/命中测试，
// 因此直接挂在 World 下的轻量 Component 即可（camera 负责世界变换）。
class BoardMeshComponent extends Component
    with HasWorldReference<DuelFieldWorld> {
  // 棋盘地毯尺寸 (根据图示比例：宽且扁平)
  static const double _matW = 580;
  // ST 行顶部 = stY + slotHeight/2 = 200+48 = 248；matH=260 留 12px 边距。
  static const double _matH = 260;

  // ── 渲染缓存 ──
  // 颜色/几何固定的 Paint 与渐变 shader 一次性构建；动态 pulse 透明度
  // 留在热路径（复用 Paint 仅改 color）。路径/中线渐变按投影结果缓存，
  // 仅投影输入变化（视差恢复后）才重建。
  static final _bgPaint = Paint()..color = const Color(0xFF050B1F);

  /// 棋盘内底色：中心微弱青色径向光 (100% 匹配 HTML radial-gradient 氛围)
  static final _matFillPaint = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [
        const Color(0xFF00F0FF).withValues(alpha: 0.06),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCenter(center: Offset.zero, width: 1200, height: 600),
    );

  /// 精细外边框：1.2px 的青色细线 (Matches thin border in image)
  static final _matBorderPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.35)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  /// 边框微弱外发光
  static final _matGlowPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.1)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  /// 极其微弱的参考网格线
  static final _gridPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.03)
    ..strokeWidth = 0.8;

  /// 背景环境尘埃
  static final _dustPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.12);

  // 辉光光束：透明度随 pulse 呼吸，Paint 复用仅改 color。
  final _wideBloomPaint = Paint()
    ..strokeWidth = 35.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  final _secondaryBloomPaint = Paint()
    ..strokeWidth = 8.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final _dividerPaint = Paint()..strokeWidth = 2.0;

  double _time = 0;

  // 预生成极小尘埃粒子：35 个浮动点，模拟原图中的星空背景 (Normalized 0..1)。
  // 复用同一 Random（原实现闭包内每次 new Random()，最多 70 个实例）。
  static final _random = Random();
  final List<Offset> _dustParticles = List.generate(
    35,
    (_) => Offset(_random.nextDouble(), _random.nextDouble()),
  );

  // 投影结果缓存：matPath 四角与中线两端（视差未动时投影输出恒定）。
  final List<Vector2> _matCorners = List.generate(4, (_) => Vector2.zero());
  Path? _matPath;
  final List<Vector2> _dividerEnds = List.generate(2, (_) => Vector2.zero());
  Shader? _dividerShader;

  /// 地毯路径：四角投影；任一角投影结果变化时才重建 Path。
  Path _projectedMatPath() {
    const xs = [-_matW, _matW, _matW, -_matW];
    const ys = [-_matH, -_matH, _matH, _matH];
    var changed = _matPath == null;
    for (var i = 0; i < 4; i++) {
      final p = world.project3D(xs[i], ys[i]);
      final c = _matCorners[i];
      if (p.x != c.x || p.y != c.y) {
        c.setValues(p.x, p.y);
        changed = true;
      }
    }
    if (changed) {
      final c = _matCorners;
      _matPath = Path()
        ..moveTo(c[0].x, c[0].y)
        ..lineTo(c[1].x, c[1].y)
        ..lineTo(c[2].x, c[2].y)
        ..lineTo(c[3].x, c[3].y)
        ..close();
    }
    return _matPath!;
  }

  /// 中线两端点（0.9 宽度）投影；端点变化时才重建渐变 shader。
  List<Vector2> _projectedDividerEnds() {
    const xs = [-_matW * 0.9, _matW * 0.9];
    var changed = _dividerShader == null;
    for (var i = 0; i < 2; i++) {
      final p = world.project3D(xs[i], 0);
      final c = _dividerEnds[i];
      if (p.x != c.x || p.y != c.y) {
        c.setValues(p.x, p.y);
        changed = true;
      }
    }
    if (changed) {
      // 核心极细高亮线的渐变 (带有紫色微调)
      _dividerShader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00F0FF),
          const Color(0xFFB026FF).withValues(alpha: 0.8),
          const Color(0xFF00F0FF),
          Colors.transparent,
        ],
        stops: const [0.1, 0.4, 0.5, 0.6, 0.9],
      ).createShader(
        Rect.fromPoints(_dividerEnds[0].toOffset(), _dividerEnds[1].toOffset()),
      );
    }
    return _dividerEnds;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!world.game.hasLayout) return;

    // 世界坐标：原点为棋盘中心；整个可见区域由 camera 决定。
    final viewRect = world.game.camera.visibleWorldRect;

    // 1. 统一投影算法路径（投影结果不变时复用缓存 Path）
    final matPath = _projectedMatPath();

    // 1.1 底部背景：深邃蓝黑（在原 #02050A 基础上提升蓝通道）。
    canvas.drawRect(viewRect, _bgPaint);

    // 1.2 棋盘内底色：中心微弱青色径向光 (100% 匹配 HTML radial-gradient 氛围)
    canvas.drawPath(matPath, _matFillPaint);

    // 1.3 精细外边框：1.2px 的青色细线 (Matches thin border in image)
    canvas.drawPath(matPath, _matBorderPaint);

    // 边框微弱外发光
    canvas.drawPath(matPath, _matGlowPaint);

    // 2. 极其微弱的参考网格线
    for (double y = -_matH; y <= _matH; y += _matH / 2) {
      canvas.drawLine(
        world.project3D(-_matW, y).toOffset(),
        world.project3D(_matW, y).toOffset(),
        _gridPaint,
      );
    }
    for (double x = -_matW; x <= _matW; x += _matW / 3.5) {
      canvas.drawLine(
        world.project3D(x, -_matH).toOffset(),
        world.project3D(x, _matH).toOffset(),
        _gridPaint,
      );
    }

    // 3. 核心：强力水平辉光光束 (100% 还原效果图中的 Intense Horizontal Beam)
    final double pulse = 0.8 + sin(_time * 3.5) * 0.2;

    // 3.1 底层广域辉光 (Wide Bloom)
    canvas.drawLine(
      world.project3D(-_matW * 0.8, 0).toOffset(),
      world.project3D(_matW * 0.8, 0).toOffset(),
      _wideBloomPaint
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.15 * pulse),
    );

    // 3.2 中层扩散光 (Secondary Bloom)
    canvas.drawLine(
      world.project3D(-_matW * 0.9, 0).toOffset(),
      world.project3D(_matW * 0.9, 0).toOffset(),
      _secondaryBloomPaint
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.25 * pulse),
    );

    // 3.3 核心极细高亮线（渐变 shader 按投影端点缓存）
    final dividerEnds = _projectedDividerEnds();
    canvas.drawLine(
      dividerEnds[0].toOffset(),
      dividerEnds[1].toOffset(),
      _dividerPaint..shader = _dividerShader,
    );

    // 4. 背景环境尘埃 (微小、淡雅，增加 3D 深度感)
    for (var i = 0; i < _dustParticles.length; i++) {
      final p = _dustParticles[i];
      final double dx = (p.dx * 1400 - 700) + sin(_time * 0.3 + i) * 30;
      final double dy = (p.dy * 1000 - 500) + cos(_time * 0.2 + i) * 30;
      final proj = world.project3D(
        dx,
        dy,
        lift: 80 + sin(_time * 0.5 + i) * 30,
      );
      canvas.drawCircle(proj.toOffset(), 0.8, _dustPaint);
    }
  }
}
