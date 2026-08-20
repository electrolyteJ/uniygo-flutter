/// 主卡组/额外卡组洗切信号按双方拆分的测试。
///
/// 背景：deckShuffleTick 原本是全局共享序号 + 最后洗牌玩家，双方洗牌消息
/// 在同一帧到达时，表现层（Flame 每帧采一次快照）只能看到最后一方，
/// 先洗牌一方的动画被吞掉（开局双方洗牌必现）。拆成每侧独立 tick 后，
/// 双方各自的洗牌动画都能触发。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuelFieldState 洗牌 tick 按侧拆分', () {
    test('双方同帧各洗一次主卡组：两侧 tick 各自 +1', () {
      const state = DuelFieldState(myController: 0);
      final afterBoth = state.withDeckShuffle(0).withDeckShuffle(1);

      expect(afterBoth.selfDeckShuffleTick, 1);
      expect(afterBoth.oppDeckShuffleTick, 1);
    });

    test('同一方连续洗牌只累加自己一侧', () {
      const state = DuelFieldState(myController: 0);
      final s = state.withDeckShuffle(0).withDeckShuffle(0);

      expect(s.selfDeckShuffleTick, 2);
      expect(s.oppDeckShuffleTick, 0);
    });

    test('myController=1 时 self/opp 归属镜像', () {
      const state = DuelFieldState(myController: 1);
      final s = state.withDeckShuffle(0);

      expect(s.selfDeckShuffleTick, 0);
      expect(s.oppDeckShuffleTick, 1);
    });

    test('兼容字段保留：全局 tick 与最后洗牌方仍更新', () {
      const state = DuelFieldState(myController: 0);
      final s = state.withDeckShuffle(1);

      expect(s.deckShuffleTick, 1);
      expect(s.deckShufflePlayer, 1);
    });

    test('额外卡组洗牌同样按侧拆分', () {
      const state = DuelFieldState(myController: 0);
      final s = state.withExtraShuffle(0).withExtraShuffle(1);

      expect(s.selfExtraShuffleTick, 1);
      expect(s.oppExtraShuffleTick, 1);
      expect(s.extraShuffleTick, 2);
      expect(s.extraShufflePlayer, 1);
    });

    test('洗额外不影响洗主卡组的 tick', () {
      const state = DuelFieldState(myController: 0);
      final s = state.withExtraShuffle(0);

      expect(s.selfDeckShuffleTick, 0);
      expect(s.selfExtraShuffleTick, 1);
    });
  });
}
