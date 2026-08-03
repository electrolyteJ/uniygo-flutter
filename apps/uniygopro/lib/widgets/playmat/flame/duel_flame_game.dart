import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../models/FieldCard.dart';
import '../../../pages/duel_room/field/duel_board_store.dart';
import 'board_mesh_component.dart';
import 'card_slot_3d.dart';
import 'chain_indicator.dart';

class DuelFlameGame extends FlameGame with TapCallbacks, MouseMovementDetector {
  final DuelBoardStore boardState;
  final Function(FieldCard? card, int? code)? onCardSelect;
  final void Function(String zoneKey)? onZoneInspect;

  DuelFlameGame({
    required this.boardState,
    this.onCardSelect,
    this.onZoneInspect,
  }) {
    boardState.addListener(_onDuelStateChanged);
  }

  Vector2 mousePos = Vector2.zero();

  @override
  void onMouseMove(PointerHoverInfo info) {
    mousePos = info.eventPosition.widget;
  }

  // 100% 还原效果图的 Stylized 3D 投影算法
  // 效果图特征：宽顶窄底的梯形，这是一种为了艺术效果而反转的透视感
  Offset project3D(double x, double y, {double lift = 0}) {
    final size = canvasSize;
    final centerX = size.x / 2;
    final centerY = size.y / 2 + 40;

    // 动态视差
    final double tiltX = (mousePos.y / size.y - 0.5) * 0.04;
    final double tiltY = (mousePos.x / size.x - 0.5) * -0.02;

    // 俯视角参数
    final double alpha = (45 * pi / 180) + tiltX;
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

    final double px = centerX + (x * factor) + (tiltY * 100 * factor);
    final double py = centerY + (yRot * 0.85); // 稍微压缩 y 轴，使其更扁平

    return Offset(px, py);
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(BoardMeshComponent());
    _rebuildField();
  }

  void _onDuelStateChanged() => _rebuildField();

  void _rebuildField() {
    children.whereType<CardSlot3DComponent>().forEach(
      (c) => c.removeFromParent(),
    );
    children.whereType<ChainIndicatorComponent>().forEach(
      (c) => c.removeFromParent(),
    );
    _buildAllSlots();
    _buildChains();
  }

  void _buildAllSlots() {
    // 7 列布局
    const colX = [-252.0, -168.0, -84.0, 0.0, 84.0, 168.0, 252.0];
    const double monsterY = 55.0;
    const double stY = 155.0;

    FieldCard? getCard(int c, int z, int s) => boardState.fieldCards['${c}_${z}_$s'];

    // 对手区 (Top)
    _addSlot(
      null,
      'EX',
      colX[0],
      -stY,
      onTapOverride: () => onZoneInspect?.call('opp_extra'),
    );
    for (int i = 0; i < 5; i++) {
      _addSlot(getCard(1, 8, 4 - i), 'S/T ${5 - i}', colX[1 + i], -stY);
      _addSlot(
        getCard(1, 4, 4 - i),
        'M ${5 - i}',
        colX[1 + i],
        -monsterY,
        isMonster: true,
      );
    }
    _addSlot(null, 'Field', colX[6], -stY);
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
    final emz1 = boardState.fieldCards['1_4_5'] ?? boardState.fieldCards['0_4_5'];
    _addSlot(emz1, 'EMZ 1', -84.0, 0, isMonster: true, isEMZ: true);
    final emz2 = boardState.fieldCards['1_4_6'] ?? boardState.fieldCards['0_4_6'];
    _addSlot(emz2, 'EMZ 2', 84.0, 0, isMonster: true, isEMZ: true);

    // 己方区 (Bottom)
    for (int i = 0; i < 5; i++) {
      _addSlot(
        getCard(0, 4, i),
        'M ${i + 1}',
        colX[1 + i],
        monsterY,
        isMonster: true,
      );
      _addSlot(getCard(0, 8, i), 'S/T ${i + 1}', colX[1 + i], stY);
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
    _addSlot(null, 'Field', colX[0], stY);
    _addSlot(
      null,
      'DECK',
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
    add(
      CardSlot3DComponent(
        card: card,
        label: label,
        boardX: x,
        boardY: y,
        isMonster: isMonster,
        isEMZ: isEMZ,
        onTap: onTapOverride ?? () => onCardSelect?.call(card, card?.code),
      ),
    );
  }

  void _buildChains() {
    final chains = boardState.chains;
    if (chains.isEmpty) return;
    for (int i = 0; i < chains.length; i++) {
      final link = chains[i];
      add(
        ChainIndicatorComponent(chainIndex: i + 1, label: 'Card #${link.code}')
          ..position = Vector2(
            canvasSize.x / 2,
            canvasSize.y / 2 + (i - (chains.length - 1) / 2) * 40,
          ),
      );
    }
  }

  @override
  void onRemove() {
    boardState.removeListener(_onDuelStateChanged);
    super.onRemove();
  }
}
