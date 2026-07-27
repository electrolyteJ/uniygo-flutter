import 'dart:math';
import 'dart:typed_data';

/// 程序化生成龙的网格数据 - 增强版（青眼白龙结构）
class DragonGeometry {
  static Float32List generateDragonVertices() {
    final List<double> vertices = [];
    final random = Random();

    // 1. 脊椎与长颈 (Spine & Neck)
    // 增加点数使曲线更平滑
    for (int i = 0; i < 200; i++) {
      double t = i / 200.0;
      // 这里的 Y 轴从 -3 到 3
      // X 和 Z 随 t 变化产生 S 型曲线
      vertices.addAll([
        sin(t * 10) * 0.4, // X
        t * 7 - 3.5,       // Y
        cos(t * 10) * 0.4, // Z
      ]);
    }

    // 2. 巨大的双翼 (Massive Wings)
    // 左右各 600 个点，模拟翼骨和翼膜
    for (int j = 0; j < 1200; j++) {
      double side = j % 2 == 0 ? 1 : -1;
      double r = random.nextDouble(); // 距离躯干的距离
      double upward = random.nextDouble(); // 翅膀高度
      
      // 翅膀开合角度
      double angle = (r * 0.8) + (random.nextDouble() * 0.2);
      
      vertices.addAll([
        side * (r * 5 + 0.3) * cos(angle * 0.5), // X: 宽大的翼展
        (r * 2.5 - 1) + upward * 1.5,            // Y: 向上扇动的动感
        -r * 2.0 + (random.nextDouble() - 0.5),  // Z: 向后折叠
      ]);
    }

    // 3. 头部与角 (Head & Horns)
    for (int k = 0; k < 150; k++) {
      double r = random.nextDouble();
      vertices.addAll([
        (random.nextDouble() - 0.5) * 0.7, // X
        3.5 + random.nextDouble() * 1.0,    // Y: 位于颈部顶端
        0.8 + random.nextDouble() * 0.6,    // Z: 向前突出的头部
      ]);
      
      // 增加龙角点
      if (k < 30) {
        double hSide = k % 2 == 0 ? 1 : -1;
        vertices.addAll([
          hSide * (0.3 + r * 0.5), // X
          4.2 + r * 0.8,           // Y
          0.5 - r * 0.3,           // Z
        ]);
      }
    }

    // 4. 四肢 (Limbs)
    for (int l = 0; l < 400; l++) {
      int limbType = l % 4; // 0:左前, 1:右前, 2:左后, 3:右后
      double side = (limbType % 2 == 0) ? -1 : 1;
      double isFront = (limbType < 2) ? 1 : -1;
      double r = random.nextDouble();

      vertices.addAll([
        side * (0.5 + r * 0.8),         // X
        isFront * 1.5 - r * 1.2,        // Y
        isFront * 0.5 + (random.nextDouble() - 0.5), // Z
      ]);
    }

    // 5. 尾巴 (Tail)
    for (int m = 0; m < 150; m++) {
      double t = m / 150.0;
      vertices.addAll([
        sin(t * 12 + 3.14) * 0.6, // X: 尾巴摆动与身体相反
        -3.5 - t * 3,             // Y: 向下向后延伸
        cos(t * 12 + 3.14) * 0.6, // Z
      ]);
    }

    return Float32List.fromList(vertices);
  }
}
