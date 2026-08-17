import 'package:duel_room2/pages/duel/models/draw_animation_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造测试事件：id 唯一标识一次抽卡（同 id 更新 = patch，不入队）。
DrawAnimationEvent evt(int id, {int player = 0, bool reveal = false}) =>
    DrawAnimationEvent(
      id: id,
      player: player,
      codes: const [0],
      turnCount: 1,
      revealCard: reveal,
    );

void main() {
  group('DrawAnimationQueue', () {
    test('空闲时提交立即成为 active', () {
      final q = DrawAnimationQueue();
      expect(q.submit(evt(1)), DrawQueueSubmitResult.started);
      expect(q.isPlaying, isTrue);
      expect(q.active!.id, 1);
      expect(q.pending, isEmpty);
    });

    test('播放中到达的新事件按 FIFO 入队，不打断当前动画', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      expect(q.submit(evt(2)), DrawQueueSubmitResult.enqueued);
      expect(q.submit(evt(3)), DrawQueueSubmitResult.enqueued);
      // active 保持为第一个事件：当前动画不被打断（天使的施舍连抽场景）。
      expect(q.active!.id, 1);
      expect(q.pending.map((e) => e.id), [2, 3]);
    });

    test('同 id 更新就地 patch active：不重启、不入队', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      final patched = evt(1, reveal: true);
      expect(q.submit(patched), DrawQueueSubmitResult.patchedActive);
      expect(identical(q.active, patched), isTrue);
      expect(q.pending, isEmpty);
    });

    test('同 id 更新就地替换排队条目，顺序不变', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      q.submit(evt(2));
      q.submit(evt(3));
      final patched = evt(2, reveal: true);
      expect(q.submit(patched), DrawQueueSubmitResult.patchedQueued);
      expect(q.pending.map((e) => e.id), [2, 3]);
      expect(q.pending.first.revealCard, isTrue);
      // active 不受影响
      expect(q.active!.id, 1);
    });

    test('drain 按 FIFO 顺序取出排队事件，取空后返回 null', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      q.submit(evt(2));
      q.submit(evt(3));
      expect(q.drain()!.id, 2);
      expect(q.active!.id, 2);
      expect(q.drain()!.id, 3);
      expect(q.drain(), isNull);
      expect(q.isPlaying, isFalse);
      expect(q.pending, isEmpty);
    });

    test('空队列 drain 返回 null', () {
      final q = DrawAnimationQueue();
      expect(q.drain(), isNull);
      expect(q.isPlaying, isFalse);
    });

    test('被 patch 过的排队事件在 drain 时以新数据播出', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      q.submit(evt(2));
      final patched = evt(2, reveal: true);
      q.submit(patched);
      final next = q.drain();
      expect(identical(next, patched), isTrue);
      expect(next!.revealCard, isTrue);
    });

    test('队列排空后再提交重新开始', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      q.drain();
      expect(q.submit(evt(2)), DrawQueueSubmitResult.started);
      expect(q.active!.id, 2);
    });

    test('clear 清空 active 与排队（dispose / 新对局重置）', () {
      final q = DrawAnimationQueue();
      q.submit(evt(1));
      q.submit(evt(2));
      expect(q.isNotEmpty, isTrue);
      q.clear();
      expect(q.isPlaying, isFalse);
      expect(q.isNotEmpty, isFalse);
      expect(q.pending, isEmpty);
      expect(q.drain(), isNull);
      // 清空后新事件从头开始播放
      expect(q.submit(evt(3)), DrawQueueSubmitResult.started);
      expect(q.active!.id, 3);
    });
  });
}
