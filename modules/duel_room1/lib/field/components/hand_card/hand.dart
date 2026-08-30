import 'package:biz/duel/models/battle_presentation.dart';
import 'package:biz/duel/models/card_move_event.dart';
import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/lp_change_event.dart';
import 'package:collection/collection.dart';
import 'package:duelink/duelink.dart' show DuelPhase;

/// 一侧手牌的不可变快照（己方底部 / 对方顶部手牌栏共用）。
///
/// 对手手牌隐私：[codes] 为 0 占位（长度即张数），配合 faceUp=false
/// 只渲染卡背，与 biz 层的隐私纪律一致。
class HandSnapshot {
  const HandSnapshot({
    required this.codes,
    required this.faceUp,
    required this.selectedIndex,
    required this.highlightedIndices,
    required this.checkedIndices,
    required this.chainOrderByIndex,
    required this.shuffleTick,
  });

  const HandSnapshot.empty()
      : codes = const [],
        faceUp = false,
        selectedIndex = null,
        highlightedIndices = const {},
        checkedIndices = const {},
        chainOrderByIndex = const {},
        shuffleTick = 0;

  /// 手牌卡码（对手为 0 占位，长度即张数）。
  final List<int> codes;

  /// 是否显示卡面（false 渲染卡背：对手手牌、观战视角）。
  final bool faceUp;

  /// 当前选中的手牌下标（操作菜单锚定），null = 无选中。
  final int? selectedIndex;

  /// 就地选择/确认模式中高亮的手牌下标。
  final Set<int> highlightedIndices;

  /// 就地选择多选中已勾选的手牌下标（比高亮更强的选中态）。
  final Set<int> checkedIndices;

  /// 连锁序号映射：手牌下标 → 连锁序号（1 起）。
  final Map<int, int> chainOrderByIndex;

  /// 手牌洗切信号（按侧独立单调 tick，变化时播放一次洗牌动画）。
  final int shuffleTick;

  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HandSnapshot &&
        other.faceUp == faceUp &&
        other.selectedIndex == selectedIndex &&
        other.shuffleTick == shuffleTick &&
        _deep.equals(other.codes, codes) &&
        _deep.equals(other.highlightedIndices, highlightedIndices) &&
        _deep.equals(other.checkedIndices, checkedIndices) &&
        _deep.equals(other.chainOrderByIndex, chainOrderByIndex);
  }

  @override
  int get hashCode => Object.hash(
    faceUp,
    selectedIndex,
    shuffleTick,
    _deep.hash(codes),
    _deep.hash(highlightedIndices),
    _deep.hash(checkedIndices),
    _deep.hash(chainOrderByIndex),
  );
}
