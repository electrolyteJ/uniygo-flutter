import 'package:duel_room3/scene3d/tween_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('Vector3Tween 线性插值并在完成时回调', () {
    final values = <Vector3>[];
    var completed = false;
    final tween = Vector3Tween(
      from: Vector3.zero(),
      to: Vector3(10, 0, 0),
      duration: 1.0,
      ease: easeLinear,
      apply: values.add,
      onComplete: () => completed = true,
    );
    expect(tween.tick(0.5), isFalse);
    expect(values.last.x, closeTo(5, 1e-6));
    expect(tween.tick(0.5), isTrue);
    expect(values.last.x, closeTo(10, 1e-6));
    expect(completed, isTrue);
  });

  test('arcHeight 附加抛物线：中点最高，端点为零', () {
    final ys = <double>[];
    final tween = Vector3Tween(
      from: Vector3.zero(),
      to: Vector3(4, 0, 0),
      duration: 1.0,
      ease: easeLinear,
      arcHeight: 2.0,
      apply: (v) => ys.add(v.y),
    );
    tween.tick(0.5);
    expect(ys.last, closeTo(2.0, 1e-6));
    tween.tick(0.5);
    expect(ys.last, closeTo(0.0, 1e-6));
  });

  test('TweenEngine3D 完成自动移除', () {
    final engine = TweenEngine3D();
    engine.addScalar(ScalarTween(
      from: 0,
      to: 1,
      duration: 0.2,
      apply: (_) {},
    ));
    expect(engine.isIdle, isFalse);
    engine.tick(0.3);
    expect(engine.isIdle, isTrue);
  });
}
