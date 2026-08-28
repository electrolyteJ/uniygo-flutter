/// 连锁序号 → 槽位 key 映射测试（连锁徽章直接画在卡片组件上，不走 overlay）。
library;

import 'package:biz/duel/models/chain_link.dart';
import 'package:duel_room1/field/util/chain_order_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildChainOrderMaps', () {
    test('空连锁返回空映射', () {
      final m = buildChainOrderMaps(const [], 0);
      expect(m.field, isEmpty);
      expect(m.selfHand, isEmpty);
      expect(m.oppHand, isEmpty);
    });

    test('怪兽/魔陷区按 zoneKeyOf 落到场上槽位，序号从 1 开始', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 1000, controller: 0, zone: 0x04, sequence: 2),
        ChainLink(code: 2000, controller: 1, zone: 0x08, sequence: 0),
      ], 0);
      expect(m.field['0_4_2'], 1);
      expect(m.field['1_8_0'], 2);
    });

    test('FZONE（0x100）归一化到场地魔法槽位 key', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 3000, controller: 1, zone: 0x100, sequence: 0),
      ], 0);
      expect(m.field['1_8_5'], 1);
    });

    test('手牌按 controller 拆到双方手牌序号映射', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 4000, controller: 0, zone: 0x02, sequence: 1),
        ChainLink(code: 5000, controller: 1, zone: 0x02, sequence: 3),
      ], 0);
      expect(m.selfHand, {1: 1});
      expect(m.oppHand, {3: 2});
    });

    test('墓地/除外/额外/卡组按归属落到区域堆槽位 key', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 6000, controller: 0, zone: 0x10, sequence: 2), // 我方墓地
        ChainLink(code: 7000, controller: 1, zone: 0x20, sequence: 0), // 对方除外
        ChainLink(code: 8000, controller: 0, zone: 0x40, sequence: 0), // 我方额外
        ChainLink(code: 9000, controller: 1, zone: 0x01, sequence: 0), // 对方卡组
      ], 0);
      expect(m.field['self_grave'], 1);
      expect(m.field['opp_removed'], 2);
      expect(m.field['self_extra'], 3);
      expect(m.field['opp_deck'], 4);
    });

    test('myController=1 时归属镜像', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 6000, controller: 1, zone: 0x10, sequence: 0),
      ], 1);
      expect(m.field['self_grave'], 1);
    });

    test('同一槽位多环连锁保留最大序号', () {
      final m = buildChainOrderMaps(const [
        ChainLink(code: 6000, controller: 0, zone: 0x10, sequence: 0),
        ChainLink(code: 6001, controller: 0, zone: 0x10, sequence: 1),
      ], 0);
      expect(m.field['self_grave'], 2);
    });
  });
}
