/// RoomTokens（233 服 AI 主机密码 token）编解码单元测试。
///
/// 对照基准：https://ygo233.com/usage（房名代码 / AI 主机密码说明）
/// 与 apps/uniygopro Mercury233RoomStringCodec.buildTokens 的历史输出。
library;

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('RoomTokens.encodeAiPassword', () {
    test('单局 + MR2020 + OCG（默认规则）只保留 MR5', () {
      const o = RoomOptions(
        mode: RoomMode.single,
        duelRule: DuelRule.mr2020,
        rule: 0,
      );
      expect(RoomTokens.encodeAiPassword(o), 'AI,MR5');
    });

    test('非默认规则编码（与 233 房名代码一致）', () {
      const o = RoomOptions(
        mode: RoomMode.match,
        duelRule: DuelRule.mr4,
        rule: 2, // OT 混
        startLp: 4000,
        noCheckDeck: true,
      );
      expect(RoomTokens.encodeAiPassword(o), 'AI,M,MR4,OT,LP4000,NC');
    });

    test('无任何 token 时返回 AI', () {
      // mode=single 仍会产出 MR5，因此要得到纯 'AI' 需要构造性绕过；
      // 直接验证 build 对全默认项产出仅 MR5（MR5 恒在）。
      const o = RoomOptions(mode: RoomMode.single);
      expect(RoomTokens.build(o), ['MR5']);
    });
  });

  group('RoomTokens.tryParseAiPassword', () {
    test('编码 → 解析往返', () {
      const o = RoomOptions(
        mode: RoomMode.tag,
        duelRule: DuelRule.mr3,
        rule: 1, // TO
        startHand: 3,
        drawCount: 2,
        noShuffleDeck: true,
        timeLimit: 240,
      );
      final parsed = RoomTokens.tryParseAiPassword(
        RoomTokens.encodeAiPassword(o),
      );
      expect(parsed, isNotNull);
      expect(parsed!.mode, RoomMode.tag);
      expect(parsed.duelRule, DuelRule.mr3);
      expect(parsed.rule, 1);
      expect(parsed.startHand, 3);
      expect(parsed.drawCount, 2);
      expect(parsed.noShuffleDeck, isTrue);
      expect(parsed.timeLimit, 240);
      expect(parsed.startLp, 8000); // 未编码的项保持默认
    });

    test('非 AI 密码返回 null', () {
      expect(RoomTokens.tryParseAiPassword(''), isNull);
      expect(RoomTokens.tryParseAiPassword('Guest'), isNull);
      expect(RoomTokens.tryParseAiPassword(RoomPassword.encodeJoin()), isNull);
      expect(RoomTokens.tryParseAiPassword('A'), isNull);
    });

    test('token 不区分大小写，且忽略禁限/单局等未知 token', () {
      final parsed = RoomTokens.tryParseAiPassword('AI,mr4,nc,lf2,nf');
      expect(parsed, isNotNull);
      expect(parsed!.duelRule, DuelRule.mr4);
      expect(parsed.noCheckDeck, isTrue);
    });

    test('前后空格可容忍', () {
      final parsed = RoomTokens.tryParseAiPassword('  AI, MR5 , NS  ');
      expect(parsed, isNotNull);
      expect(parsed!.duelRule, DuelRule.mr2020);
      expect(parsed.noShuffleDeck, isTrue);
    });
  });
}
