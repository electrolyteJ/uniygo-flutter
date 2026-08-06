import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../../../models/FieldCard.dart';
import '../../../pages/duel_room/duel/duel_field_store.dart';
import 'board_mesh_component.dart';
import 'card_slot_3d.dart';
import 'duel_flame_game.dart';

/// 棋盘布局常量（世界/逻辑坐标，原点为棋盘中心）。
class DuelFieldLayout {
  DuelFieldLayout._();

  /// 7 列布局的 x 坐标。
  static const colX = [-252.0, -168.0, -84.0, 0.0, 84.0, 168.0, 252.0];
  static const monsterY = 55.0;
  static const stY = 155.0;
  static const slotWidth = 68.0;
  static const slotHeight = 96.0;
}

/// 决斗场地世界：持有棋盘网格与全部卡槽组件，并统一负责
/// Stylized 3D 投影（世界坐标 = 投影后、以棋盘中心为原点的坐标，
/// 视口居中/偏移由 [CameraComponent] 负责）。
class DuelFieldWorld extends World with HasGameReference<DuelFlameGame> {
  final DuelFieldStore duelStore;
  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;

  final List<CardSlot3DComponent> _slots = [];
  Vector2? _lastParallaxMouse;

  DuelFieldWorld({
    required this.duelStore,
    this.onCardSelect,
    this.onZoneInspect,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(BoardMeshComponent());
    rebuildField();
  }

  // 100% 还原效果图的 Stylized 3D 投影算法
  // 效果图特征：宽顶窄底的梯形，这是一种为了艺术效果而反转的透视感
  Vector2 project3D(double x, double y, {double lift = 0}) {
    final tilt = _parallaxTilt;

    // 俯视角参数
    final double alpha = (45 * pi / 180) + tilt.x;
    final double cosA = cos(alpha);
    final double sinA = sin(alpha);

    // 为了实现效果图中的“上宽下窄”梯形：
    // 我们反转 z 轴的影响，或者调整 factor 计算方式。
    // y > 0 是底部（近端），y < 0 是顶部（远端）。
    // 在效果图中，顶端反而显得更开阔。
    final double yRot = (y * cosA) + (lift * sinA);
    // 关键修正：让 y 为负（顶部）时 factor 更大
    // 我们使用一个线性偏移来模拟这种特殊的广角形变
    final double factor = 1.0 - (y * 0.0008);

    return Vector2(
      (x * factor) + (tilt.y * 100 * factor),
      yRot * 0.85, // 稍微压缩 y 轴，使其更扁平
    );
  }

  /// lift（Z 轴提升）换算成世界坐标 y 方向位移。
  double projectLiftY(double lift) {
    final double alpha = (45 * pi / 180) + _parallaxTilt.x;
    return lift * sin(alpha) * 0.85;
  }

  /// 动态视差（x: 俯仰微调, y: 横移微调）；首帧 layout 前为 0。
  Vector2 get _parallaxTilt {
    final viewport = game.canvasSize;
    if (viewport.x <= 0 || viewport.y <= 0) return Vector2.zero();
    final mouse = game.mousePos;
    return Vector2(
      (mouse.y / viewport.y - 0.5) * 0.04,
      (mouse.x / viewport.x - 0.5) * -0.02,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncParallax();
  }

  /// 鼠标移动时重新投影卡槽位置（BoardMesh 每帧自行投影，无需同步）。
  void _syncParallax() {
    final mouse = game.mousePos;
    final last = _lastParallaxMouse;
    if (last != null && last.x == mouse.x && last.y == mouse.y) return;
    _lastParallaxMouse = mouse.clone();
    for (final slot in _slots) {
      slot.position = project3D(slot.boardX, slot.boardY);
    }
  }

  void rebuildField() {
    if (!isLoaded) return;
    for (final slot in _slots) {
      slot.removeFromParent();
    }
    _slots.clear();
    _buildAllSlots();
  }

  void _buildAllSlots() {
    final selfController = duelStore.myController;
    final opponentController = 1 - selfController;

    const colX = DuelFieldLayout.colX;
    const monsterY = DuelFieldLayout.monsterY;
    const stY = DuelFieldLayout.stY;

    FieldCard? getCard(int c, int z, int s) =>
        duelStore.fieldCards['${c}_${z}_$s'];

    // 对手区 (Top)
    _addSlot(
      null,
      'EX',
      colX[0],
      -stY,
      onTapOverride: () => onZoneInspect?.call('opp_extra'),
    );
    for (int i = 0; i < 5; i++) {
      _addSlot(
        getCard(opponentController, 8, 4 - i),
        'S/T ${5 - i}',
        colX[1 + i],
        -stY,
      );
      _addSlot(
        getCard(opponentController, 4, 4 - i),
        'M ${5 - i}',
        colX[1 + i],
        -monsterY,
        isMonster: true,
      );
    }
    _addSlot(getCard(opponentController, 8, 5), 'Field', colX[6], -stY);
    _addSlot(
      null,
      'Banish',
      colX[0],
      -monsterY,
      onTapOverride: () => onZoneInspect?.call('opp_removed'),
    );
    _addSlot(
      null,
      'Grave',
      colX[6],
      -monsterY,
      onTapOverride: () => onZoneInspect?.call('opp_grave'),
    );

    // EMZ
    final emz1 =
        duelStore.fieldCards['${opponentController}_4_5'] ??
        duelStore.fieldCards['${selfController}_4_5'];
    _addSlot(emz1, 'EMZ 1', -84.0, 0, isMonster: true, isEMZ: true);
    final emz2 =
        duelStore.fieldCards['${opponentController}_4_6'] ??
        duelStore.fieldCards['${selfController}_4_6'];
    _addSlot(emz2, 'EMZ 2', 84.0, 0, isMonster: true, isEMZ: true);

    // 己方区 (Bottom)
    for (int i = 0; i < 5; i++) {
      _addSlot(
        getCard(selfController, 4, i),
        'M ${i + 1}',
        colX[1 + i],
        monsterY,
        isMonster: true,
      );
      _addSlot(getCard(selfController, 8, i), 'S/T ${i + 1}', colX[1 + i], stY);
    }
    _addSlot(
      null,
      'Grave',
      colX[0],
      monsterY,
      onTapOverride: () => onZoneInspect?.call('self_grave'),
    );
    _addSlot(
      null,
      'Banish',
      colX[6],
      monsterY,
      onTapOverride: () => onZoneInspect?.call('self_removed'),
    );
    _addSlot(getCard(selfController, 8, 5), 'Field', colX[0], stY);
    _addSlot(
      null,
      'EX',
      colX[6],
      stY,
      onTapOverride: () => onZoneInspect?.call('self_extra'),
    );
  }

  void _addSlot(
    FieldCard? card,
    String label,
    double x,
    double y, {
    bool isMonster = false,
    bool isEMZ = false,
    VoidCallback? onTapOverride,
  }) {
    final slot = CardSlot3DComponent(
      card: card,
      label: label,
      boardX: x,
      boardY: y,
      isMonster: isMonster,
      isEMZ: isEMZ,
      onTap: onTapOverride ?? () => onCardSelect?.call(card, card?.code),
    )..position = project3D(x, y);
    _slots.add(slot);
    add(slot);
  }
}
