import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import 'fx/ring_mesh.dart';

/// 悬浮竞技场：主平台（PBR）+ 发光边缘环 + 内圈光带 + 星空穹顶。
///
/// 星空穹顶用 scale.x = -1 的反转球体（法线朝内），贴程序化生成的
/// 星空纹理；若运行时发现有背面剔除问题，退化为半球或不透明背景。
class ArenaComponent extends Component3D {
  ArenaComponent();

  /// 发光环/光带的脉动相位（由 update 驱动）。
  double _pulse = 0;
  late final UnlitMaterial _edgeGlowMaterial;
  late final UnlitMaterial _innerRingMaterial;

  @override
  Future<void> onLoad() async {
    _edgeGlowMaterial = UnlitMaterial(
      albedoColor: const ui.Color(0xFF37E2FF),
    );
    _innerRingMaterial = UnlitMaterial(
      albedoColor: const ui.Color(0xFF1B7FA8),
    );
    await addAll([
      // 主平台
      MeshComponent(
        mesh: CylinderMesh(
          radius: 6.4,
          height: 0.4,
          segments: 64,
          material: SpatialMaterial(
            albedoColor: const ui.Color(0xFF232B3E),
            metallic: 0.35,
            roughness: 0.65,
          ),
        ),
        position: Vector3(0, -0.2, 0),
      ),
      // 外缘发光环（真圆环网格，非圆柱——圆柱带顶盖会盖住整个平台）
      MeshComponent(
        mesh: RingMesh(
          innerRadius: 6.3,
          outerRadius: 6.55,
          segments: 64,
          material: _edgeGlowMaterial,
        ),
        position: Vector3(0, 0.02, 0),
      ),
      // 场内光带（场地外围一圈）
      MeshComponent(
        mesh: RingMesh(
          innerRadius: 4.88,
          outerRadius: 4.98,
          segments: 64,
          material: _innerRingMaterial,
        ),
        position: Vector3(0, 0.012, 0),
      ),
      // 星空穹顶（反转球体）
      MeshComponent(
        mesh: SphereMesh(
          radius: 80,
          material: UnlitMaterial(
            albedoTexture: await ImageTexture.create(_buildStarTexture()),
          ),
        ),
        scale: Vector3(-1, 1, 1),
      ),
    ]);
  }

  @override
  void update(double dt) {
    _pulse += dt;
    final glow = 0.72 + 0.28 * math.sin(_pulse * 2.2);
    _edgeGlowMaterial.albedoColor = ui.Color.fromRGBO(
      (0x37 * glow).round(),
      (0xE2 * glow).round(),
      (0xFF * glow).round(),
      1,
    );
    final inner = 0.6 + 0.4 * math.sin(_pulse * 2.2 + 1.3);
    _innerRingMaterial.albedoColor = ui.Color.fromRGBO(
      (0x1B * inner).round(),
      (0x7F * inner).round(),
      (0xA8 * inner).round(),
      1,
    );
  }

  /// 程序化星空纹理：深空渐变 + 随机星点 + 少量星云色块。
  static ui.Image _buildStarTexture({int size = 1024}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final bg = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(0, size.toDouble()),
        const [ui.Color(0xFF05070F), ui.Color(0xFF101B33)],
      );
    canvas.drawRect(rect, bg);
    final rng = math.Random(42);
    // 星云色块
    for (var i = 0; i < 14; i++) {
      final p = ui.Paint()
        ..color = ui.Color.fromRGBO(
          40 + rng.nextInt(60),
          60 + rng.nextInt(60),
          120 + rng.nextInt(80),
          0.05 + rng.nextDouble() * 0.06,
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 60);
      canvas.drawCircle(
        ui.Offset(rng.nextDouble() * size, rng.nextDouble() * size),
        60 + rng.nextDouble() * 140,
        p,
      );
    }
    // 星点
    for (var i = 0; i < 700; i++) {
      final p = ui.Paint()
        ..color = ui.Color.fromRGBO(
          255,
          255,
          255,
          0.25 + rng.nextDouble() * 0.75,
        );
      canvas.drawCircle(
        ui.Offset(rng.nextDouble() * size, rng.nextDouble() * size),
        rng.nextDouble() < 0.08 ? 1.8 : 0.9,
        p,
      );
    }
    final picture = recorder.endRecording();
    return picture.toImageSync(size, size);
  }
}
