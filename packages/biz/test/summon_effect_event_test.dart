/// [resolveSummonEffectType] 纯函数测试：完成消息标签 → 基础类型，
/// extra 类型按卡数据标志细分（含多类别卡优先级）。
library;

import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ygo_data/card_info.dart';

// 与 card_info.dart 位掩码一致
const _tMonster = 0x1;
const _tFusion = 0x40;
const _tRitual = 0x80;
const _tSynchro = 0x2000;
const _tXyz = 0x800000;
const _tLink = 0x4000000;

CardInfo _monster(int extraType) => CardInfo(
      code: 1,
      type: _tMonster | extraType,
      name: '测试怪',
    );

void main() {
  group('resolveSummonEffectType', () {
    test('通常召唤 → normal（不受卡数据影响）', () {
      expect(resolveSummonEffectType('召唤', _monster(_tFusion)),
          SummonEffectType.normal);
      expect(resolveSummonEffectType('召唤', null), SummonEffectType.normal);
    });

    test('反转召唤 → flip', () {
      expect(resolveSummonEffectType('反转召唤', null), SummonEffectType.flip);
    });

    test('特殊召唤：卡数据未就绪 → special', () {
      expect(resolveSummonEffectType('特殊召唤', null),
          SummonEffectType.special);
    });

    test('extra 差异化：仪式/融合/同调/超量/链接', () {
      expect(resolveSummonEffectType('特殊召唤', _monster(_tRitual)),
          SummonEffectType.ritual);
      expect(resolveSummonEffectType('特殊召唤', _monster(_tFusion)),
          SummonEffectType.fusion);
      expect(resolveSummonEffectType('特殊召唤', _monster(_tSynchro)),
          SummonEffectType.synchro);
      expect(resolveSummonEffectType('特殊召唤', _monster(_tXyz)),
          SummonEffectType.xyz);
      expect(resolveSummonEffectType('特殊召唤', _monster(_tLink)),
          SummonEffectType.link);
    });

    test('多类别卡取优先级：link > xyz > synchro > fusion > ritual', () {
      expect(
          resolveSummonEffectType(
              '特殊召唤', _monster(_tFusion | _tLink)),
          SummonEffectType.link);
      expect(
          resolveSummonEffectType(
              '特殊召唤', _monster(_tRitual | _tXyz)),
          SummonEffectType.xyz);
      expect(
          resolveSummonEffectType(
              '特殊召唤', _monster(_tRitual | _tSynchro)),
          SummonEffectType.synchro);
    });

    test('主卡组效果怪兽特殊召唤 → special（不误判）', () {
      expect(resolveSummonEffectType('特殊召唤', _monster(0x20)),
          SummonEffectType.special);
    });
  });

  group('SummonEffectEvent', () {
    test('字段构造', () {
      const e = SummonEffectEvent(
        id: 3,
        code: 89631139,
        slotId: '0_4_2',
        type: SummonEffectType.normal,
      );
      expect(e.id, 3);
      expect(e.code, 89631139);
      expect(e.slotId, '0_4_2');
      expect(e.type, SummonEffectType.normal);
    });
  });
}
