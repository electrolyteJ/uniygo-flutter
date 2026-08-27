/// 立牌快照 diff（纯 Dart，可单测）。
///
/// 输入为「卡槽 key → 卡视图」映射的前后两帧快照，输出增/删/改集合。
/// 立牌身份 = 卡槽 key：跨槽移动表现为 remove+add（显式演出如破坏/送墓
/// 由效果系统按事件另行驱动）。
library;

/// 一张立牌的视图数据（由 biz FieldCard 映射而来，场景层不依赖 biz）。
class StandeeCardView {
  const StandeeCardView({
    required this.zoneKey,
    required this.code,
    required this.position,
    this.overlayCount = 0,
  });

  final String zoneKey;
  final int code;
  final int position;
  final int overlayCount;

  bool sameContent(StandeeCardView other) =>
      code == other.code &&
      position == other.position &&
      overlayCount == other.overlayCount;
}

class StandeeDiff {
  const StandeeDiff({
    required this.added,
    required this.removed,
    required this.updated,
  });

  /// 新增卡槽（key → 视图）。
  final Map<String, StandeeCardView> added;

  /// 消失的卡槽 key。
  final List<String> removed;

  /// 内容变化的卡槽（key → 新视图）。
  final Map<String, StandeeCardView> updated;

  bool get isEmpty => added.isEmpty && removed.isEmpty && updated.isEmpty;
}

StandeeDiff diffStandeeCards(
  Map<String, StandeeCardView> prev,
  Map<String, StandeeCardView> next,
) {
  final added = <String, StandeeCardView>{};
  final updated = <String, StandeeCardView>{};
  for (final entry in next.entries) {
    final old = prev[entry.key];
    if (old == null) {
      added[entry.key] = entry.value;
    } else if (!old.sameContent(entry.value)) {
      updated[entry.key] = entry.value;
    }
  }
  final removed = [
    for (final key in prev.keys)
      if (!next.containsKey(key)) key,
  ];
  return StandeeDiff(added: added, removed: removed, updated: updated);
}
