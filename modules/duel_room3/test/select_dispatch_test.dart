/// 选择窗口分发纯函数测试（select_dispatch.dart）。
///
/// 覆盖 code review 发现的三处分发缺陷：
/// - modal 分发：card/tribute/chain/unselect/sum 必须回退卡网格弹窗
///   （否则选项在墓地/卡组等区域时无任何入口 → 软锁）；counter/sort
///   也必须有 UI；
/// - 就地图标：unselect 是「完成」语义（回 -1），绝不能走确认多选；
/// - 取消按钮：chain 显示「不连锁」，其余可取消窗口显示「取消」。
library;

import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room3/hud/select_dispatch.dart';
import 'package:flutter_test/flutter_test.dart';

SelectState _select({
  SelectType type = SelectType.card,
  int min = 1,
  int max = 1,
  bool cancelable = false,
  bool finishable = false,
}) => SelectState(
  type: type,
  player: 0,
  min: min,
  max: max,
  cancelable: cancelable,
  finishable: finishable,
  options: const [SelectOption(code: 89631139)],
);

void main() {
  group('selectModalKind', () {
    test('是否/效果确认 → yesNo', () {
      expect(selectModalKind(SelectType.yesNo), SelectModalKind.yesNo);
      expect(selectModalKind(SelectType.effectYn), SelectModalKind.yesNo);
    });

    test('选项与数值/属性/种族宣言 → option', () {
      expect(selectModalKind(SelectType.option), SelectModalKind.option);
      expect(
        selectModalKind(SelectType.announceNumber),
        SelectModalKind.option,
      );
      expect(
        selectModalKind(SelectType.announceAttrib),
        SelectModalKind.option,
      );
      expect(selectModalKind(SelectType.announceRace), SelectModalKind.option);
    });

    test('position / announceCard', () {
      expect(selectModalKind(SelectType.position), SelectModalKind.position);
      expect(
        selectModalKind(SelectType.announceCard),
        SelectModalKind.announceCard,
      );
    });

    test('就地类型必须有 modal 卡网格回退（墓地取对象等场景）', () {
      for (final t in [
        SelectType.card,
        SelectType.tribute,
        SelectType.chain,
        SelectType.unselect,
        SelectType.sum,
      ]) {
        expect(selectModalKind(t), SelectModalKind.cardGrid, reason: '$t');
      }
    });

    test('counter / sort 有专门弹窗，不再落入 shrink 死锁', () {
      expect(selectModalKind(SelectType.counter), SelectModalKind.counter);
      expect(selectModalKind(SelectType.sort), SelectModalKind.sort);
    });

    test('阶段指令/放置等不出 modal', () {
      expect(selectModalKind(SelectType.idleCmd), SelectModalKind.none);
      expect(selectModalKind(SelectType.battleCmd), SelectModalKind.none);
      expect(selectModalKind(SelectType.place), SelectModalKind.none);
    });
  });

  group('inlineSelectAction', () {
    test('unselect 是「完成」语义（finishable 时），不走确认', () {
      expect(
        inlineSelectAction(
          _select(type: SelectType.unselect, finishable: true),
        ),
        InlineSelectAction.finish,
      );
      expect(
        inlineSelectAction(
          _select(type: SelectType.unselect),
        ),
        InlineSelectAction.none,
      );
    });

    test('chain 点卡即答，无确认按钮', () {
      expect(
        inlineSelectAction(_select(type: SelectType.chain, cancelable: true)),
        InlineSelectAction.none,
      );
    });

    test('tribute/sum 恒需确认；card 仅多选需确认', () {
      expect(
        inlineSelectAction(_select(type: SelectType.tribute)),
        InlineSelectAction.confirm,
      );
      expect(
        inlineSelectAction(_select(type: SelectType.sum, max: 0)),
        InlineSelectAction.confirm,
      );
      expect(
        inlineSelectAction(_select(max: 2)),
        InlineSelectAction.confirm,
      );
      expect(inlineSelectAction(_select()), InlineSelectAction.none);
    });

    test('counter 不是确认分支（死分支已移除）', () {
      expect(
        inlineSelectAction(_select(type: SelectType.counter)),
        InlineSelectAction.none,
      );
    });
  });

  group('inlineCancelLabel', () {
    test('可取消 chain → 「不连锁」；其余 → 「取消」', () {
      expect(
        inlineCancelLabel(_select(type: SelectType.chain, cancelable: true)),
        '不连锁',
      );
      expect(inlineCancelLabel(_select(cancelable: true)), '取消');
    });

    test('不可取消 → null（不显示按钮）', () {
      expect(inlineCancelLabel(_select(type: SelectType.chain)), isNull);
      expect(inlineCancelLabel(_select()), isNull);
    });
  });
}
