/// 选择窗口分发的纯函数判定（从 duel_overlays.dart 抽出以便单测）。
///
/// 对照基准：modules/duel_room2/lib/field/widgets/overlay/
/// duel_select_overlay.dart 与 select_prompt_layer.dart。
library;

import 'package:biz/duel/models/select_state.dart';

/// modal 弹窗的种类分发（仅当选择窗口不可就地选择时才出现 modal）。
enum SelectModalKind {
  none,
  yesNo,
  option,
  position,
  announceCard,
  cardGrid,
  counter,
  sort,
}

/// 按选择类型决定 modal 弹窗种类。
///
/// card/tribute/chain/unselect/sum 在选项落在非可见区域（墓地/卡组/
/// 除外/对方手牌等）时无法就地点击，必须回退到卡网格弹窗——否则
/// 玩家没有任何可选入口，对局死锁（死苏取墓地对象是极常见场景）。
SelectModalKind selectModalKind(SelectType type) => switch (type) {
  SelectType.yesNo || SelectType.effectYn => SelectModalKind.yesNo,
  SelectType.option ||
  SelectType.announceNumber ||
  SelectType.announceAttrib ||
  SelectType.announceRace => SelectModalKind.option,
  SelectType.position => SelectModalKind.position,
  SelectType.announceCard => SelectModalKind.announceCard,
  SelectType.card ||
  SelectType.tribute ||
  SelectType.chain ||
  SelectType.unselect ||
  SelectType.sum => SelectModalKind.cardGrid,
  SelectType.counter => SelectModalKind.counter,
  SelectType.sort => SelectModalKind.sort,
  _ => SelectModalKind.none,
};

/// 就地选择栏的动作按钮种类。
enum InlineSelectAction { none, confirm, finish }

/// 就地选择需要哪个动作按钮（对照 room2 duel_select_overlay 的
/// showConfirm / inlineShowFinish 分支）：
/// - unselect 是「完成」语义（回 -1 确认当前勾选），绝不能走
///   respondInlineMulti（它只特判 tribute/sum，unselect 会发错包）；
/// - chain 点卡即答，无确认；
/// - tribute/sum 恒需确认；card 仅多选（max>1）需确认。
InlineSelectAction inlineSelectAction(SelectState select) {
  switch (select.type) {
    case SelectType.unselect:
      return select.finishable
          ? InlineSelectAction.finish
          : InlineSelectAction.none;
    case SelectType.chain:
      return InlineSelectAction.none;
    case SelectType.tribute:
    case SelectType.sum:
      return InlineSelectAction.confirm;
    case SelectType.card:
      return select.max > 1 ? InlineSelectAction.confirm : InlineSelectAction.none;
    default:
      return InlineSelectAction.none;
  }
}

/// 就地选择栏的取消按钮文案；不可取消的窗口返回 null（不显示按钮）。
/// chain 窗口的取消语义是「不连锁」。
String? inlineCancelLabel(SelectState select) => select.cancelable
    ? (select.type == SelectType.chain ? '不连锁' : '取消')
    : null;
