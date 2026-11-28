import 'package:biz/duel/field/message_pump.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// 节奏泵的「暂停消费」能力。
///
/// 用途：入场演出（Seamless Loading Screen）期间，服务器已经在推
/// `MSG_SUMMON` / `MSG_CHAINING`。若不压住，玩家会在加载页就听到对面
/// 召唤怪兽、发动卡片——画面和声音对不上。
///
/// 关键约束：**暂停 ≠ 丢弃**。攒在队列里，恢复后按序消费，否则场地页
/// 落地时初始状态是错的（少了几只怪兽）。
void main() {
  group('MessagePump 暂停', () {
    test('暂停期间入队不消费，恢复后按序补齐', () {
      final consumed = <String>[];
      final pump = MessagePump<String>(
        consume: (m, {required silent}) => consumed.add(m),
      );

      pump.paused = true;
      pump.enqueue('召唤 A');
      pump.enqueue('召唤 B');
      pump.enqueue('发动 C');

      // 一条都不该被消费。
      expect(consumed, isEmpty);
      expect(pump.pendingCount, 3);

      pump.paused = false;
      pump.resume();
      // resume 排的是零延时定时器，需要让出事件循环。
      return Future<void>.delayed(Duration.zero, () {
        // 只排了第一条，其余由 _drainOne 的节奏定时器续排。
        expect(consumed, ['召唤 A']);
        expect(pump.pendingCount, 2);
      });
    });

    test('未暂停时首条同步直通（0ms 延迟不受影响）', () {
      final consumed = <String>[];
      final pump = MessagePump<String>(
        consume: (m, {required silent}) => consumed.add(m),
      );
      pump.enqueue('第一条');
      expect(consumed, ['第一条']);
    });

    test('flushSilent 在暂停期间不再抢跑', () {
      final consumed = <String>[];
      final pump = MessagePump<String>(
        consume: (m, {required silent}) => consumed.add(m),
      );
      pump.paused = true;
      pump.enqueue('A');
      pump.enqueue('B');
      pump.flushSilent();
      // 演出还在放，不能因为「断连收尾」之类的路径把消息提前吐出来。
      expect(consumed, isEmpty);
      expect(pump.pendingCount, 2);
    });

    test('恢复时队列为空不报错、不排调度', () {
      final pump = MessagePump<String>(
        consume: (m, {required silent}) {},
      );
      pump.paused = true;
      pump.paused = false;
      pump.resume();
      expect(pump.pendingCount, 0);
    });

    test('暂停期间 dispose：队列清空且后续入队被忽略', () {
      final consumed = <String>[];
      final pump = MessagePump<String>(
        consume: (m, {required silent}) => consumed.add(m),
      );
      pump.paused = true;
      pump.enqueue('A');
      pump.dispose();
      expect(pump.pendingCount, 0);
      pump.enqueue('B');
      expect(consumed, isEmpty);
    });

    // ── 回归：「进入场地页，对面完全不动」 ──
    //
    // 线上症状：加载页播完入场演出、切到场地页后，对方再也不动。
    // 成因是暂停期间排空链被吃掉了 —— 定时器到点后 `if (paused) return`
    // 让 `_timer` 停在 null，之后没有任何东西推进队列。修复后暂停只是
    // 让链空转，链一直在手上。
    test('暂停期间长时间挂起后恢复：积压一条不少地放出来', () {
      fakeAsync((async) {
        final consumed = <String>[];
        final pump = MessagePump<String>(
          consume: (m, {required silent}) => consumed.add(m),
        );

        pump.paused = true;
        for (var i = 0; i < 5; i++) {
          pump.enqueue('msg $i');
        }
        // 入场演出约 2.7s；暂停挂这么久，排空链必须还活着。
        async.elapse(const Duration(seconds: 3));
        expect(consumed, isEmpty, reason: '暂停期间一条都不许消费');

        pump.paused = false;
        pump.resume();
        // 恢复应立即开始放（不必等满一拍）。
        async.elapse(Duration.zero);
        expect(consumed.length, 1, reason: 'resume 后立刻放第一条');

        async.elapse(const Duration(seconds: 2));
        expect(consumed.length, 5, reason: '积压 5 条必须全部放出来，不能丢');
        pump.dispose();
      });
    });

    test('暂停但不调用 resume：解除暂停后仍能自行恢复消费', () {
      fakeAsync((async) {
        final consumed = <String>[];
        final pump = MessagePump<String>(
          consume: (m, {required silent}) => consumed.add(m),
        );

        pump.paused = true;
        pump.enqueue('A');
        pump.enqueue('B');
        async.elapse(const Duration(milliseconds: 500));
        expect(consumed, isEmpty);

        // 只置标志、**故意不调 resume**：排空链自续，不应永久卡死。
        pump.paused = false;
        async.elapse(const Duration(seconds: 2));
        expect(consumed, ['A', 'B'], reason: '解除暂停后链应自行继续');
        pump.dispose();
      });
    });

    test('暂停时从空闲态进入：入队消息在解除暂停后照常消费', () {
      fakeAsync((async) {
        final consumed = <String>[];
        final pump = MessagePump<String>(
          consume: (m, {required silent}) => consumed.add(m),
        );

        pump.paused = true; // 空闲 → 暂停
        pump.enqueue('A');
        async.elapse(const Duration(milliseconds: 300));
        expect(consumed, isEmpty);

        pump.paused = false;
        pump.resume();
        async.elapse(const Duration(seconds: 1));
        expect(consumed, ['A']);
        pump.dispose();
      });
    });

    test('暂停期间反复 pause（幂等）：不叠加定时器、恢复后不重复消费', () {
      fakeAsync((async) {
        final consumed = <String>[];
        final pump = MessagePump<String>(
          consume: (m, {required silent}) => consumed.add(m),
        );

        pump.paused = true;
        pump.paused = true;
        pump.paused = true;
        pump.enqueue('A');
        async.elapse(const Duration(milliseconds: 500));

        pump.paused = false;
        pump.resume();
        pump.resume();
        async.elapse(const Duration(seconds: 1));
        expect(consumed, ['A'], reason: '只消费一次，不因重复 resume 翻倍');
        pump.dispose();
      });
    });
  });
}
