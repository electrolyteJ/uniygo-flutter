/// MatchStore 匹配单飞守卫测试。
///
/// 背景：匹配入口（匹配页/匹配弹层）重复触发会并发起两个匹配流程，
/// 双方完成后同帧两次 context.go('/duel-room') 撞车，触发
/// Navigator._debugLocked 断言崩溃。tryStartSearching 在仓库层单飞。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';

void main() {
  group('MatchStore.tryStartSearching 单飞守卫', () {
    test('首次开始返回 true，进行中再次开始返回 false', () {
      final store = MatchStore();
      expect(store.tryStartSearching('athletic'), isTrue);
      expect(store.isSearching, isTrue);
      expect(store.arena, 'athletic');

      expect(store.tryStartSearching('entertain'), isFalse);
      expect(store.arena, 'athletic', reason: '进行中的匹配不被覆盖');
    });

    test('stopSearching 后放行下一次匹配', () {
      final store = MatchStore();
      expect(store.tryStartSearching('athletic'), isTrue);
      store.stopSearching();
      expect(store.tryStartSearching('entertain'), isTrue);
      expect(store.arena, 'entertain');
    });

    test('setMatchResult（匹配成功）后放行下一次匹配', () {
      final store = MatchStore();
      expect(store.tryStartSearching('athletic'), isTrue);
      store.setMatchResult('127.0.0.1', 7911, 'pw');
      expect(store.tryStartSearching('entertain'), isTrue);
    });

    test('reset 后放行下一次匹配', () {
      final store = MatchStore();
      expect(store.tryStartSearching('athletic'), isTrue);
      store.reset();
      expect(store.tryStartSearching('athletic'), isTrue);
    });
  });
}
