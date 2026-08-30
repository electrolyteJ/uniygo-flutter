/// 对局消息节奏泵（MessagePump）单元测试。
///
/// 背景：竞技观战中途加入时，服务器把开局以来的整段对局消息一次性推来
/// （数百条），收到即分发让 UI 瞬间刷新几百次。泵把消息入队后按积压量
/// 自适应降档消费：积压越深节奏越快，追平后恢复 0ms 直通。
library;

import 'package:biz/duel/field/message_pump.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePump 节奏', () {
    test('空闲时首条消息同步直通（0ms）', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        pump.enqueue(1);

        expect(consumed, [1], reason: '队列空时入队应立即同步消费');
        expect(pump.pendingCount, 0);
        pump.dispose();
      });
    });

    test('小爆发（≤20 积压）：每 120ms 消费一条', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 5; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0], reason: '首条直通，其余排队');

        async.elapse(const Duration(milliseconds: 119));
        expect(consumed, [0], reason: '120ms 未到不应消费第二条');
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);

        async.elapse(const Duration(seconds: 1));
        expect(consumed, [0, 1, 2, 3, 4]);
        pump.dispose();
      });
    });

    test('中爆发（21~100 积压）：每 40ms 消费一条', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 30; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        // 首跳是最小冷却档 120ms（消费首条时积压尚为 0）。
        async.elapse(const Duration(milliseconds: 119));
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);

        // 之后进入积压档：剩余 28 条按 40ms/条消费。
        async.elapse(const Duration(milliseconds: 40));
        expect(consumed, [0, 1, 2]);

        async.elapse(const Duration(seconds: 5));
        expect(consumed.length, 30);
        pump.dispose();
      });
    });

    test('大爆发（>100 积压，观战追赶）：每 12ms 消费一条，追平后恢复直通', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 300; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        // 首跳是最小冷却档 120ms：t=120ms 时消费第 2 条。
        async.elapse(const Duration(milliseconds: 120));
        expect(consumed.length, 2);

        // 之后进入追赶档（积压 >100 → 12ms/条）：再 120ms 消费 10 条。
        async.elapse(const Duration(milliseconds: 120));
        expect(consumed.length, 12);

        // 积压随消费下降自动降档；给足时间全部消化。
        async.elapse(const Duration(seconds: 30));
        expect(consumed.length, 300);
        expect(pump.pendingCount, 0);

        // 追平后新消息恢复 0ms 直通。
        pump.enqueue(999);
        expect(consumed.last, 999);
        pump.dispose();
      });
    });

    test('intervalForBacklog 档位边界', () {
      expect(MessagePump.intervalForBacklog(1),
          const Duration(milliseconds: 120));
      expect(MessagePump.intervalForBacklog(20),
          const Duration(milliseconds: 120));
      expect(MessagePump.intervalForBacklog(21),
          const Duration(milliseconds: 40));
      expect(MessagePump.intervalForBacklog(100),
          const Duration(milliseconds: 40));
      expect(MessagePump.intervalForBacklog(101),
          const Duration(milliseconds: 12));
      expect(MessagePump.intervalForBacklog(500),
          const Duration(milliseconds: 12));
    });

    test('dispose 停止泵：定时器取消，后续入队被忽略', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 50; i++) {
          pump.enqueue(i);
        }
        pump.dispose();

        async.elapse(const Duration(seconds: 10));
        expect(consumed, [0], reason: 'dispose 后不得再消费');

        pump.enqueue(1);
        expect(consumed, [0], reason: 'dispose 后入队应被忽略');
      });
    });
  });
}
