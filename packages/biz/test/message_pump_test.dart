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
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

        pump.enqueue(1);

        expect(consumed, [1], reason: '队列空时入队应立即同步消费');
        expect(pump.pendingCount, 0);
        pump.dispose();
      });
    });

    test('小爆发（≤20 积压）：每 120ms 消费一条', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

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
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

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
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

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
      final pump =
          MessagePump<int>(consume: (m, {required bool silent}) {});
      expect(pump.intervalForBacklog(1), const Duration(milliseconds: 120));
      expect(pump.intervalForBacklog(20), const Duration(milliseconds: 120));
      expect(pump.intervalForBacklog(21), const Duration(milliseconds: 40));
      expect(pump.intervalForBacklog(100), const Duration(milliseconds: 40));
      expect(pump.intervalForBacklog(101), const Duration(milliseconds: 12));
      expect(pump.intervalForBacklog(500), const Duration(milliseconds: 12));
      pump.dispose();
    });

    test('clear 丢弃全部待消费消息，之后可重新入队', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

        for (var i = 0; i < 50; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        pump.clear();
        expect(pump.pendingCount, 0);

        async.elapse(const Duration(seconds: 10));
        expect(consumed, [0], reason: 'clear 后队列中的消息不得再被消费');

        pump.enqueue(100);
        expect(consumed, [0, 100], reason: 'clear 后泵应恢复正常工作');
        pump.dispose();
      });
    });

    test('jumpToCurrent：积压超阈值同步静音清场，尾部不足阈值仍按节奏', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final silents = <bool>[];
        final pump = MessagePump<int>(consume: (m, {required bool silent}) {
          consumed.add(m);
          silents.add(silent);
        });
        pump.jumpToCurrent = true;

        pump.enqueue(0); // 空闲直通（非静音）
        expect(consumed, [0]);
        expect(silents, [false]);

        // 积压到 21（>20）时触发清场：1..21 同步静音消费。
        for (var i = 1; i <= 30; i++) {
          pump.enqueue(i);
        }
        expect(consumed.length, 22);
        expect(silents.sublist(1).every((s) => s), isTrue,
            reason: '清场期间全部 silent');
        // 剩余 22..30 不足阈值，仍按节奏排队。
        expect(pump.pendingCount, 9);

        async.elapse(const Duration(seconds: 10));
        expect(consumed.length, 31);
        expect(silents.sublist(22).every((s) => !s), isTrue,
            reason: '尾部按节奏消费，不静音');
        pump.dispose();
      });
    });

    test('回放速度倍率：2x 时消费间隔减半', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(
            consume: (m, {required bool silent}) => consumed.add(m));
        pump.speedFactor = 2.0;
        expect(pump.intervalForBacklog(1), const Duration(milliseconds: 60));
        expect(pump.intervalForBacklog(101), const Duration(milliseconds: 6));

        pump.enqueue(0);
        pump.enqueue(1);
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 59));
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);
        pump.dispose();
      });
    });

    test('dispose 停止泵：定时器取消，后续入队被忽略', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: (m, {required bool silent}) => consumed.add(m));

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

    test('flushSilent 同步静音排空积压，且不残留定时器', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final silents = <bool>[];
        final pump = MessagePump<int>(
          consume: (m, {required bool silent}) {
            consumed.add(m);
            silents.add(silent);
          },
        );

        pump.enqueue(0); // 直通（有声）
        for (var i = 1; i < 50; i++) {
          pump.enqueue(i); // 冷却窗口内 → 排队
        }
        expect(consumed, [0]);

        pump.flushSilent();
        expect(consumed.length, 50, reason: '全部积压应同步消费完');
        expect(silents.sublist(1).every((s) => s), isTrue,
            reason: 'flush 消费一律静音');
        expect(pump.pendingCount, 0);

        // 无残留定时器：elapse 不应再消费，fakeAsync 收尾也不报 pending Timer。
        async.elapse(const Duration(seconds: 10));
        expect(consumed.length, 50);

        // 排空后泵仍可用：新消息照常直通。
        pump.enqueue(100);
        expect(consumed.last, 100);
        expect(silents.last, isFalse);
        pump.dispose();
      });
    });
  });
}
