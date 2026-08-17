import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flame_3d/core.dart';
import 'package:flutter/material.dart';

import 'summon_3d_game.dart';

/// 电子龙召唤 3D 演出 overlay：透明覆盖在 Flame 场地上方（不拦截指针），
/// 把目标卡槽的屏幕坐标换算到 3D 场景的 z=0 平面，演出结束自动移除。
class Summon3DOverlay extends StatefulWidget {
  const Summon3DOverlay({
    super.key,
    required this.targetCenter,
    required this.onDone,
  });

  /// 目标卡槽中心（overlay 局部逻辑像素坐标）。
  final Offset targetCenter;

  /// 演出结束回调。
  final VoidCallback onDone;

  @override
  State<Summon3DOverlay> createState() => _Summon3DOverlayState();
}

class _Summon3DOverlayState extends State<Summon3DOverlay> {
  Summon3DGame? _game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final game = _game ??= _createGame(size);
          return GameWidget(game: game);
        },
      ),
    );
  }

  Summon3DGame _createGame(Size size) {
    return Summon3DGame(
      dragonTarget: _screenToWorld(widget.targetCenter, size),
      onDone: widget.onDone,
    );
  }

  /// 屏幕坐标 → 相机注视平面（z=0）的世界坐标。
  ///
  /// 透视相机正对原点：可见高 h = 2·dist·tan(fov/2)，宽按 aspect 展开。
  Vector3 _screenToWorld(Offset screenPos, Size size) {
    final dist = Summon3DGame.cameraDistance;
    final h = 2 * dist * math.tan(Summon3DGame.fovYDegrees * math.pi / 360);
    final w = h * (size.width / size.height);
    final worldX = (screenPos.dx / size.width - 0.5) * w;
    final worldY = (0.5 - screenPos.dy / size.height) * h - 0.1; // 对齐 camera target.y
    return Vector3(worldX, worldY, 0);
  }
}
