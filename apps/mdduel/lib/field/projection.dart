import 'dart:math' as math;
import 'dart:ui';

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final l = length;
    return l > 0 ? Vec3(x / l, y / l, z / l) : this;
  }
}

class FieldCamera {
  final Vec3 basePosition;
  Vec3 position;
  final Vec3 forward;
  final double fov;
  Size viewportSize = Size.zero;

  late final Vec3 _right;
  late final Vec3 _trueUp;

  FieldCamera.fromPitch({
    required Vec3 position,
    required double pitchDegrees,
    double fovDegrees = 75,
    Vec3 up = const Vec3(0, 1, 0),
  })  : basePosition = position,
        position = position,
        forward = Vec3(
          0,
          -math.sin(pitchDegrees * math.pi / 180),
          math.cos(pitchDegrees * math.pi / 180),
        ),
        fov = fovDegrees * math.pi / 180 {
    _right = up.cross(forward).normalized;
    _trueUp = forward.cross(_right).normalized;
  }

  void pullBack(double distance) {
    final d = distance < 0 ? 0.0 : distance;
    position = basePosition - forward * d;
  }

  void fitHorizontal(double halfWidth, Vec3 referencePoint, {double maxPullBack = 12.0}) {
    pullBack(0);
    final size = viewportSize;
    if (size.isEmpty || halfWidth <= 0) return;
    final aspect = size.width / size.height;
    final halfFovH = math.atan(math.tan(fov / 2) * aspect);
    final depthNow = depthOf(referencePoint);
    final depthNeeded = halfWidth / math.tan(halfFovH);
    if (depthNeeded > depthNow) {
      pullBack(math.min(depthNeeded - depthNow, maxPullBack));
    }
  }

  Offset? project(Vec3 point) {
    final size = viewportSize;
    final rel = point - position;
    final cz = rel.dot(forward);
    if (cz <= 0.1) return null;
    final cx = rel.dot(_right);
    final cy = rel.dot(_trueUp);
    final f = 1.0 / math.tan(fov / 2);
    final aspect = size.width / size.height;
    final ndcX = cx * f / (aspect * cz);
    final ndcY = cy * f / cz;
    return Offset(
      (ndcX + 1) / 2 * size.width,
      (1 - ndcY) / 2 * size.height,
    );
  }

  double depthOf(Vec3 point) => (point - position).dot(forward);

  double scaleAtDepth(double depth, double screenHeight) {
    final f = 1.0 / math.tan(fov / 2);
    return f * screenHeight / (2 * depth);
  }
}
