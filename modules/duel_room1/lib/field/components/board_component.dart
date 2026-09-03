import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:duel_room1/field/duel_field_world.dart';

/// 决斗场地装饰组件（纯 2D）：棋盘地毯 + 参考网格线 + 中央辉光光束 + 背景尘埃。
///
/// 3D 投影已彻底移除（duel_room1 不走伪 3D），因此这里直接用世界/像素坐标
/// 绘制，也不再缓存投影结果：
/// 地毯是固定轴对齐矩形，中线端点固定，尘埃是纯 2D 漂移。
///
/// 仅在世界坐标系内做自定义绘制，不涉及 size/anchor/命中测试，因此直接挂在
/// World 下的轻量 Component 即可（camera 负责世界变换）。
class BoardComponent extends Component
    with HasWorldReference<DuelFieldWorld> {
  // 棋盘地毯尺寸（根据图示比例：宽且扁平）
  static const double _matW = 580;
  // ST 行顶部 = stY + slotHeight/2 = 200+48 = 248；matH=260 留 12px 边距。
  static const double _matH = 260;

  /// 地毯矩形：中心为原点。
  static final Rect _matRect = Rect.fromCenter(
    center: Offset.zero,
    width: _matW * 2,
    height: _matH * 2,
  );

  /// 中央高亮线端点（0.9 宽度，水平）。
  static final Offset _dividerStart = Offset(-_matW * 0.9, 0);
  static final Offset _dividerEnd = Offset(_matW * 0.9, 0);

  // ── 渲染缓存（颜色/几何固定的 Paint 与渐变 shader 一次性构建）──

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

  /// 核心极细高亮线：端点固定，渐变 shader 一次构建。
  final _dividerPaint = Paint()
    ..strokeWidth = 2.0
    ..shader = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFF00F0FF),
        const Color(0xFFB026FF).withValues(alpha: 0.8),
        const Color(0xFF00F0FF),
        Colors.transparent,
      ],
      stops: const [0.1, 0.4, 0.5, 0.6, 0.9],
    ).createShader(
      Rect.fromPoints(_dividerStart, _dividerEnd),
    );

  double _time = 0;

  // 预生成极小尘埃粒子：35 个浮动点，模拟原图中的星空背景 (Normalized 0..1)。
  // 复用同一 Random（原实现闭包内每次 new Random()，最多 70 个实例）。
  static final _random = Random();
  final List<Offset> _dustParticles = List.generate(
    35,
    (_) => Offset(_random.nextDouble(), _random.nextDouble()),
  );

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

    // 1. 底部背景：深邃蓝黑（在原 #02050A 基础上提升蓝通道）。
    canvas.drawRect(viewRect, _bgPaint);

    // 2. 棋盘地毯：中心微弱青色径向光 + 1.2px 细边框 + 外发光。
    canvas.drawRect(_matRect, _matFillPaint);
    canvas.drawRect(_matRect, _matBorderPaint);
    canvas.drawRect(_matRect, _matGlowPaint);

    // 3. 极其微弱的参考网格线
    for (double y = -_matH; y <= _matH; y += _matH / 2) {
      canvas.drawLine(Offset(-_matW, y), Offset(_matW, y), _gridPaint);
    }
    for (double x = -_matW; x <= _matW; x += _matW / 3.5) {
      canvas.drawLine(Offset(x, -_matH), Offset(x, _matH), _gridPaint);
    }

    // 4. 核心：强力水平辉光光束 (100% 还原效果图中的 Intense Horizontal Beam)
    final double pulse = 0.8 + sin(_time * 3.5) * 0.2;

    // 4.1 底层广域辉光 (Wide Bloom)
    canvas.drawLine(
      Offset(-_matW * 0.8, 0),
      Offset(_matW * 0.8, 0),
      _wideBloomPaint
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.15 * pulse),
    );

    // 4.2 中层扩散光 (Secondary Bloom)
    canvas.drawLine(
      Offset(-_matW * 0.9, 0),
      Offset(_matW * 0.9, 0),
      _secondaryBloomPaint
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.25 * pulse),
    );

    // 4.3 核心极细高亮线（固定渐变 shader）
    canvas.drawLine(_dividerStart, _dividerEnd, _dividerPaint);

    // 5. 背景环境尘埃 (微小、淡雅，增加视觉深度)
    for (var i = 0; i < _dustParticles.length; i++) {
      final p = _dustParticles[i];
      final double dx = (p.dx * 1400 - 700) + sin(_time * 0.3 + i) * 30;
      final double dy = (p.dy * 1000 - 500) + cos(_time * 0.2 + i) * 30;
      canvas.drawCircle(Offset(dx, dy), 0.8, _dustPaint);
    }
  }
}
