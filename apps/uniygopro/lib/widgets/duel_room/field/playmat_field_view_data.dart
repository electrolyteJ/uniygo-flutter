import '../../../models/FieldCard.dart';

/// 场地渲染模式：Flutter widget 原型版 / Flame 3D 版。
enum PlaymatRenderMode { prototype, flame }

class PlaymatFieldViewData {
  final Map<String, FieldCard> fieldCards;
  final int selfController;
  final int opponentController;
  final int selfDeckCount;
  final int selfExtraCount;
  final int selfGraveCount;
  final int selfRemovedCount;
  final int oppDeckCount;
  final int oppExtraCount;
  final int oppGraveCount;
  final int oppRemovedCount;

  const PlaymatFieldViewData({
    required this.fieldCards,
    required this.selfController,
    required this.opponentController,
    required this.selfDeckCount,
    required this.selfExtraCount,
    required this.selfGraveCount,
    required this.selfRemovedCount,
    required this.oppDeckCount,
    required this.oppExtraCount,
    required this.oppGraveCount,
    required this.oppRemovedCount,
  });

  FieldCard? cardAt(int controller, int zone, int sequence) {
    return fieldCards['${controller}_${zone}_$sequence'];
  }
}
