/// LP toast 合并逻辑（LpToastFeed）测试。
///
/// 每条 LP 变动事件驱动受影响玩家状态卡旁的一条锚定 toast；
/// 同侧同类型 0.8s 内连续变动合并累加，避免连锁烧血刷屏。
library;

import 'package:biz/duel/models/lp_change_event.dart';
import 'package:duel_room1/field/components/lp/lp_toast_feed.dart';
import 'package:flutter_test/flutter_test.dart';

LpChangeEvent _damage(int value) =>
    LpChangeEvent(player: 0, delta: -value, kind: LpChangeKind.damage);

void main() {
  group('LpToastFeed', () {
    test('单条事件：current 记录 delta/kind，计时归零', () {
      final feed = LpToastFeed();
      feed.add(_damage(2000));
      expect(feed.current!.delta, -2000);
      expect(feed.current!.kind, LpChangeKind.damage);
      expect(feed.elapsed, Duration.zero);
    });

    test('0.8s 内同 kind：累加 delta 并重置计时', () {
      final feed = LpToastFeed();
      feed.add(_damage(800));
      feed.tick(const Duration(milliseconds: 500));
      feed.add(_damage(1200));
      expect(feed.current!.delta, -2000);
      expect(feed.elapsed, Duration.zero);
    });

    test('超过 0.8s 的同 kind：不累计，作为新条目替换', () {
      final feed = LpToastFeed();
      feed.add(_damage(800));
      feed.tick(const Duration(milliseconds: 900));
      feed.add(_damage(1200));
      expect(feed.current!.delta, -1200);
      expect(feed.elapsed, Duration.zero);
    });

    test('0.8s 内异 kind：替换为最新事件，不累计', () {
      final feed = LpToastFeed();
      feed.add(LpChangeEvent(player: 0, delta: -1000, kind: LpChangeKind.pay));
      feed.tick(const Duration(milliseconds: 300));
      feed.add(_damage(2000));
      expect(feed.current!.delta, -2000);
      expect(feed.current!.kind, LpChangeKind.damage);
      expect(feed.elapsed, Duration.zero);
    });

    test('toast 存活 1.4s 后清空', () {
      final feed = LpToastFeed();
      feed.add(_damage(2000));
      feed.tick(const Duration(milliseconds: 1399));
      expect(feed.current, isNotNull);
      feed.tick(const Duration(milliseconds: 2));
      expect(feed.current, isNull);
    });

    test('合并重置计时后，到期时间从重置后起算', () {
      final feed = LpToastFeed();
      feed.add(_damage(800));
      feed.tick(const Duration(milliseconds: 1200));
      feed.add(_damage(800));
      feed.tick(const Duration(milliseconds: 1300));
      expect(feed.current, isNotNull);
      feed.tick(const Duration(milliseconds: 200));
      expect(feed.current, isNull);
    });
  });
}
