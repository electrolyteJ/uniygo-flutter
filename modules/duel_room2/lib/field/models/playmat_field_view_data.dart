
import 'package:biz/duel/models/field_card.dart';
import 'package:flutter/foundation.dart';

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
  final int selfExtraTopCode;
  final int selfGraveTopCode;
  final int selfRemovedTopCode;
  final int oppExtraTopCode;
  final int oppGraveTopCode;
  final int oppRemovedTopCode;

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
    this.selfExtraTopCode = 0,
    this.selfGraveTopCode = 0,
    this.selfRemovedTopCode = 0,
    this.oppExtraTopCode = 0,
    this.oppGraveTopCode = 0,
    this.oppRemovedTopCode = 0,
  });

  FieldCard? cardAt(int controller, int zone, int sequence) {
    return fieldCards['${controller}_${zone}_$sequence'];
  }

  /// 按字段判等：页面每次 build 都会新建 [PlaymatFieldViewData] 实例
  /// （含 fieldCards 的浅拷贝），若沿用引用比较，
  /// PrototypePlaymatField.didUpdateWidget 会在每次重建时误判数据变化，
  /// 从而反复调度 anchor 上报。字段级判等让内容不变时比较为真。
  ///
  /// [FieldCard] 自身无值判等，未变更的卡在状态层保持实例稳定
  /// （map spread 复用旧实例），故 [mapEquals] 的逐值 `==`
  /// 在内容不变时等价于实例稳定比较。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaymatFieldViewData &&
        mapEquals(other.fieldCards, fieldCards) &&
        other.selfController == selfController &&
        other.opponentController == opponentController &&
        other.selfDeckCount == selfDeckCount &&
        other.selfExtraCount == selfExtraCount &&
        other.selfGraveCount == selfGraveCount &&
        other.selfRemovedCount == selfRemovedCount &&
        other.oppDeckCount == oppDeckCount &&
        other.oppExtraCount == oppExtraCount &&
        other.oppGraveCount == oppGraveCount &&
        other.oppRemovedCount == oppRemovedCount &&
        other.selfExtraTopCode == selfExtraTopCode &&
        other.selfGraveTopCode == selfGraveTopCode &&
        other.selfRemovedTopCode == selfRemovedTopCode &&
        other.oppExtraTopCode == oppExtraTopCode &&
        other.oppGraveTopCode == oppGraveTopCode &&
        other.oppRemovedTopCode == oppRemovedTopCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAllUnordered(
        fieldCards.entries.map((entry) => Object.hash(entry.key, entry.value)),
      ),
      selfController,
      opponentController,
      selfDeckCount,
      selfExtraCount,
      selfGraveCount,
      selfRemovedCount,
      oppDeckCount,
      oppExtraCount,
      oppGraveCount,
      oppRemovedCount,
      selfExtraTopCode,
      selfGraveTopCode,
      selfRemovedTopCode,
      oppExtraTopCode,
      oppGraveTopCode,
      oppRemovedTopCode,
    );
  }
}
