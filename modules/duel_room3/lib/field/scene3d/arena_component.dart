import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import '../../theme/cyber_skin.dart';
import 'fx/ring_mesh.dart';

/// 赛博决斗竞技场：矩形悬浮平台 + 双层霓虹边框 + 法阵环 + 四角光柱
/// + 无限延伸地面网格 + 城市天际线穹顶。
///
/// 穹顶沿用 scale.x = -1 的反转球体（法线朝内）。地面网格用一张大
/// PlaneMesh 贴程序化纹理：flame_3d 无 LineMesh，也没有后处理 bloom，
/// 所以霓虹感靠「高饱和自发光色 + 多层叠加 + 每帧脉动」近似。
class ArenaComponent extends Component3D {
  ArenaComponent();

  /// 发光环/光带/立柱的脉动相位（由 update 驱动）。
  double _pulse = 0;
  late final UnlitMaterial _edgeGlowMaterial;
  late final UnlitMaterial _innerRingMaterial;
  late final UnlitMaterial _outerRingMaterial;
  late final UnlitMaterial _pillarGlowMaterial;
  late final UnlitMaterial _groundMaterial;
  late final UnlitMaterial _skyMaterial;

  /// 平台尺寸（覆盖 32 槽：x ±4.37、z ±3.71，四周留边）。
  static const double _platformW = 10.8;
  static const double _platformD = 8.8;

  @override
  Future<void> onLoad() async {
    _edgeGlowMaterial = UnlitMaterial(albedoColor: CyberPalette.magenta);
    _innerRingMaterial = UnlitMaterial(albedoColor: CyberPalette.cyan);
    _outerRingMaterial = UnlitMaterial(albedoColor: CyberPalette.violet);
    _pillarGlowMaterial = UnlitMaterial(albedoColor: CyberPalette.cyan);

    final gridTexture = await ImageTexture.create(_buildGridTexture());
    final skyTexture = await ImageTexture.create(_buildSkylineTexture());
    _groundMaterial = UnlitMaterial(albedoTexture: gridTexture);
    _skyMaterial = UnlitMaterial(albedoTexture: skyTexture);

    await addAll([
      // 无限延伸地面网格：放在平台底面（-0.4）之下，避免 z-fighting。
      MeshComponent(
        mesh: PlaneMesh(size: Vector2(160, 160), material: _groundMaterial),
        position: Vector3(0, -0.62, 0),
      ),
      // 城市天际线穹顶（反转球体）
      MeshComponent(
        mesh: SphereMesh(radius: 80, material: _skyMaterial),
        scale: Vector3(-1, 1, 1),
      ),
      // 主平台：矩形悬浮台（原 CylinderMesh 圆形平台改为方台）
      MeshComponent(
        mesh: CuboidMesh(
          size: Vector3(_platformW, 0.4, _platformD),
          material: SpatialMaterial(
            albedoColor: const ui.Color(0xFF0C1024),
            metallic: 0.55,
            roughness: 0.45,
          ),
        ),
        position: Vector3(0, -0.2, 0),
      ),
      // 矩形霓虹边框（4 条细 cuboid，共用一个脉动材质）
      ..._buildFrame(),
      // 内圈法阵光带（方台 + 圆环 = 方圆对比）
      MeshComponent(
        mesh: RingMesh(
          innerRadius: 4.88,
          outerRadius: 4.98,
          segments: 64,
          material: _innerRingMaterial,
        ),
        position: Vector3(0, 0.012, 0),
      ),
      // 外圈细环（紫色，反向脉动）
      MeshComponent(
        mesh: RingMesh(
          innerRadius: 5.18,
          outerRadius: 5.23,
          segments: 64,
          material: _outerRingMaterial,
        ),
        position: Vector3(0, 0.010, 0),
      ),
      // 四角霓虹光柱：给俯视构图加纵深与「决斗结界」感
      for (final x in [-5.18, 5.18])
        for (final z in [-4.18, 4.18])
          MeshComponent(
            mesh: CuboidMesh(
              size: Vector3(0.10, 2.3, 0.10),
              material: _pillarGlowMaterial,
            ),
            position: Vector3(x, 1.15, z),
          ),
    ]);
  }

  List<MeshComponent> _buildFrame() {
    const thickness = 0.075;
    const y = 0.025;
    return [
      for (final z in [-_platformD / 2, _platformD / 2])
        MeshComponent(
          mesh: CuboidMesh(
            size: Vector3(_platformW + thickness, 0.03, thickness),
            material: _edgeGlowMaterial,
          ),
          position: Vector3(0, y, z),
        ),
      for (final x in [-_platformW / 2, _platformW / 2])
        MeshComponent(
          mesh: CuboidMesh(
            size: Vector3(thickness, 0.03, _platformD + thickness),
            material: _edgeGlowMaterial,
          ),
          position: Vector3(x, y, 0),
        ),
    ];
  }

  @override
  void update(double dt) {
    _pulse += dt;
    final cyber = CyberSkin.isOn;
    final speed = cyber ? 2.8 : 2.2;
    final glow = 0.72 + 0.28 * math.sin(_pulse * speed);
    final inner = 0.6 + 0.4 * math.sin(_pulse * speed + 1.3);
    final outer = 0.45 + 0.55 * math.sin(_pulse * speed * 1.7 + 0.7);
    final pillar = 0.55 + 0.45 * math.sin(_pulse * 1.6 + 2.1);

    _edgeGlowMaterial.albedoColor = _scaled(
      cyber ? CyberPalette.magenta : CyberPalette.classicCyan,
      glow * (cyber ? 1.0 : 0.72),
    );
    _innerRingMaterial.albedoColor = _scaled(
      cyber ? CyberPalette.cyan : CyberPalette.classicCyanDim,
      inner,
    );
    _outerRingMaterial.albedoColor = _scaled(
      cyber ? CyberPalette.violet : CyberPalette.classicCyanDim,
      outer,
    );
    _pillarGlowMaterial.albedoColor = _scaled(
      cyber ? CyberPalette.violet : CyberPalette.classicCyan,
      pillar * (cyber ? 1.0 : 0.35),
    );
    // 关闭演出增强层时把背景纹理整体压暗，回到接近经典的深空观感。
    _groundMaterial.albedoColor = cyber
        ? const ui.Color(0xFFFFFFFF)
        : const ui.Color(0xFF3A4666);
    _skyMaterial.albedoColor = cyber
        ? const ui.Color(0xFFFFFFFF)
        : const ui.Color(0xFF52608C);
  }

  static ui.Color _scaled(ui.Color color, double k) => ui.Color.fromRGBO(
    (color.r * 255 * k).round().clamp(0, 255),
    (color.g * 255 * k).round().clamp(0, 255),
    (color.b * 255 * k).round().clamp(0, 255),
    1,
  );

  /// 程序化地面网格纹理：深色底 + 三级网格线 + 中心青色辉光。
  /// 贴到 160×160 的水平 PlaneMesh 上，透视由 3D 相机自然产生。
  static ui.Image _buildGridTexture({int size = 1024}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final s = size.toDouble();
    final bg = ui.Paint()
      ..shader = ui.Gradient.radial(
        ui.Offset(s / 2, s / 2),
        s * 0.62,
        [
          const ui.Color(0xFF0A1A2C),
          const ui.Color(0xFF060A18),
          CyberPalette.voidBlack,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, s, s), bg);

    // 细网格（32px）→ 中线（128px）→ 品红主干（256px）
    for (var i = 0; i <= size; i += 32) {
      final major = i % 256 == 0;
      final mid = i % 128 == 0;
      final paint = ui.Paint()
        ..color = major
            ? CyberPalette.gridAccent.withValues(alpha: 0.55)
            : (mid
                  ? CyberPalette.gridLine.withValues(alpha: 0.42)
                  : CyberPalette.gridLine.withValues(alpha: 0.16))
        ..strokeWidth = major ? 2.2 : (mid ? 1.4 : 0.7);
      final p = i.toDouble();
      canvas.drawLine(ui.Offset(p, 0), ui.Offset(p, s), paint);
      canvas.drawLine(ui.Offset(0, p), ui.Offset(s, p), paint);
    }

    // 中心场地区域的青色辉光
    final halo = ui.Paint()
      ..shader = ui.Gradient.radial(ui.Offset(s / 2, s / 2), s * 0.22, [
        CyberPalette.cyan.withValues(alpha: 0.14),
        const ui.Color(0x00000000),
      ]);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, s, s), halo);
    return recorder.endRecording().toImageSync(size, size);
  }

  /// 程序化城市天际线穹顶纹理：紫黑渐变 + 霓虹光晕 + 星点 +
  /// 剪影楼群（顶部霓虹描边 + 窗格点阵）+ 地平线亮带。
  static ui.Image _buildSkylineTexture({int size = 1024}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final s = size.toDouble();
    final bg = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(0, s),
        const [
          ui.Color(0xFF03060E),
          ui.Color(0xFF140B2C),
          ui.Color(0xFF2A0B33),
          ui.Color(0xFF070A18),
        ],
        [0.0, 0.52, 0.76, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, s, s), bg);

    final rng = math.Random(2077);
    // 大范围霓虹辉光
    for (var i = 0; i < 18; i++) {
      final warm = rng.nextBool();
      final paint = ui.Paint()
        ..color = (warm ? CyberPalette.magenta : CyberPalette.cyan).withValues(
          alpha: 0.05 + rng.nextDouble() * 0.07,
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 70);
      canvas.drawCircle(
        ui.Offset(rng.nextDouble() * s, s * (0.35 + rng.nextDouble() * 0.4)),
        60 + rng.nextDouble() * 150,
        paint,
      );
    }
    // 星点（上半部）
    for (var i = 0; i < 420; i++) {
      final paint = ui.Paint()
        ..color = ui.Color.fromRGBO(
          220,
          240,
          255,
          0.2 + rng.nextDouble() * 0.6,
        );
      canvas.drawCircle(
        ui.Offset(rng.nextDouble() * s, rng.nextDouble() * s * 0.55),
        rng.nextDouble() < 0.06 ? 1.8 : 0.8,
        paint,
      );
    }

    // 远景楼群（较矮、较暗）
    _drawSkylineBand(
      canvas,
      rng,
      s,
      baseline: s * 0.78,
      minH: 40,
      maxH: 130,
      bodyAlpha: 0.55,
      windowAlpha: 0.20,
    );
    // 近景楼群（较高、剪影更实）
    _drawSkylineBand(
      canvas,
      rng,
      s,
      baseline: s * 0.88,
      minH: 80,
      maxH: 230,
      bodyAlpha: 0.92,
      windowAlpha: 0.55,
    );

    // 地平线亮带
    final horizon = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, s * 0.74),
        ui.Offset(0, s * 0.80),
        [
          const ui.Color(0x00000000),
          CyberPalette.magenta.withValues(alpha: 0.5),
          const ui.Color(0x00000000),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, s * 0.74, s, s * 0.06), horizon);
    return recorder.endRecording().toImageSync(size, size);
  }

  static void _drawSkylineBand(
    ui.Canvas canvas,
    math.Random rng,
    double s, {
    required double baseline,
    required double minH,
    required double maxH,
    required double bodyAlpha,
    required double windowAlpha,
  }) {
    var x = -20.0;
    while (x < s + 20) {
      final w = 26 + rng.nextDouble() * 72;
      final h = minH + rng.nextDouble() * (maxH - minH);
      final top = baseline - h;
      final rect = ui.Rect.fromLTWH(x, top, w, h);
      final body = ui.Paint()
        ..color = CyberPalette.voidBlack.withValues(alpha: bodyAlpha);
      canvas.drawRect(rect, body);

      // 楼顶霓虹描边（青 / 品红交替）
      final neon = rng.nextBool() ? CyberPalette.cyan : CyberPalette.magenta;
      canvas.drawRect(
        ui.Rect.fromLTWH(x, top, w, 2.4),
        ui.Paint()..color = neon.withValues(alpha: windowAlpha),
      );
      // 窗格点阵
      for (var wy = top + 10; wy < baseline - 8; wy += 11) {
        for (var wx = x + 5; wx < x + w - 4; wx += 9) {
          if (rng.nextDouble() > 0.62) continue;
          canvas.drawRect(
            ui.Rect.fromLTWH(wx, wy, 2.6, 3.4),
            ui.Paint()
              ..color = (rng.nextBool() ? CyberPalette.cyan : neon).withValues(
                alpha: windowAlpha * (0.4 + rng.nextDouble() * 0.6),
              ),
          );
        }
      }
      x += w + 4 + rng.nextDouble() * 10;
    }
  }
}
