/// 233 服密码编解码单元测试（房间串 + AI 主机密码 token）。
///
/// 对照基准：https://ygo233.com/usage（房名代码 / AI 主机密码说明）
/// 与历史建房表单的输出（房间串见 [Room233Password.encodeRoomPassword]）。
library;

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('Room233Password.encodeAiHostPassword', () {
    test('单局 + MR2020 + OCG（默认规则）只保留 MR5', () {
      expect(
        Room233Password.encodeAiHostPassword(mode: 0),
        'AI,MR5',
      );
    });

    test('非默认规则编码（与 233 房名代码一致）', () {
      expect(
        Room233Password.encodeAiHostPassword(
          mode: 1,
          duelRule: 4,
          rule: 2, // OT 混
          startLp: 4000,
          noCheckDeck: true,
        ),
        'AI,M,MR4,OT,LP4000,NC',
      );
    });

    test('默认参数（match）恒带 M + MR5', () {
      expect(Room233Password.encodeAiHostPassword(), 'AI,M,MR5');
    });
  });

  group('Room233Password.tryParseAiHostPassword', () {
    test('编码 → 解析往返', () {
      final encoded = Room233Password.encodeAiHostPassword(
        mode: 2, // 双打
        duelRule: 3,
        rule: 1, // TO
        startHand: 3,
        drawCount: 2,
        noShuffleDeck: true,
        timeLimit: 240,
      );
      final parsed = Room233Password.tryParseAiHostPassword(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.mode, 2);
      expect(parsed.duelRule, 3);
      expect(parsed.rule, 1);
      expect(parsed.startHand, 3);
      expect(parsed.drawCount, 2);
      expect(parsed.noShuffleDeck, isTrue);
      expect(parsed.timeLimit, 240);
      expect(parsed.startLp, 8000); // 未编码的项保持默认
      expect(parsed.lfTableIndex, -1); // 未带禁限 token
    });

    test('非 AI 密码返回 null', () {
      expect(Room233Password.tryParseAiHostPassword(''), isNull);
      expect(Room233Password.tryParseAiHostPassword('Guest'), isNull);
      expect(
        Room233Password.tryParseAiHostPassword(MyCardRoomPassword.encodeJoin()),
        isNull,
      );
      expect(Room233Password.tryParseAiHostPassword('A'), isNull);
    });

    test('token 不区分大小写，忽略未知 token，并解析禁限', () {
      final parsed = Room233Password.tryParseAiHostPassword(
        'AI,mr4,nc,lf2,nf',
      );
      expect(parsed, isNotNull);
      expect(parsed!.duelRule, 4);
      expect(parsed.noCheckDeck, isTrue);
      // 后出现的 NF 覆盖 LF2。
      expect(parsed.lfTableIndex, 0);
    });

    test('LF<n> 解析为卡表序号', () {
      final parsed = Room233Password.tryParseAiHostPassword('AI,M,MR5,LF3');
      expect(parsed?.lfTableIndex, 3);
    });

    test('前后空格可容忍', () {
      final parsed = Room233Password.tryParseAiHostPassword('  AI, MR5 , NS  ');
      expect(parsed, isNotNull);
      expect(parsed!.duelRule, 5);
      expect(parsed.noShuffleDeck, isTrue);
    });
  });

  group('Room233Password.encodeRoomPassword（233 服明文房间串）', () {
    test('单局 + 默认规则：只有 MR5 + 房间名', () {
      expect(
        Room233Password.encodeRoomPassword(mode: 0, roomName: '测试房'),
        'MR5#测试房',
      );
    });

    test('非默认参数按服务器解析顺序拼 token，禁限插在 DR 之后', () {
      expect(
        Room233Password.encodeRoomPassword(
          roomName: '房',
          lfTableIndex: 0, // 无禁限 → NF
          mode: 1,
          duelRule: 4,
          rule: 2,
          drawCount: 2,
        ),
        'M,MR4,OT,DR2,NF#房',
      );
    });

    test('房间名超长时自动截断，结果不超过上限', () {
      final value = Room233Password.encodeRoomPassword(
        mode: 0,
        roomName: '一二三四五六七八九十甲乙丙丁戊己庚辛', // 20 字
      );
      // token 部分 'MR5#' 占 4 字符，房间名可用 16 字符
      expect(value.length, 20);
      expect(value, 'MR5#一二三四五六七八九十甲乙丙丁戊己');
    });

    test('token 本身占满上限时只返回空串', () {
      final value = Room233Password.encodeRoomPassword(
        roomName: '房',
        lfTableIndex: 0,
        mode: 1,
        duelRule: 4,
        rule: 2,
        timeLimit: 120,
        startLp: 4000,
        startHand: 4,
        drawCount: 2,
        noCheckDeck: true,
        noShuffleDeck: true,
      );
      expect(value, isEmpty);
    });

    test('房间名去首尾空格；默认参数是 match（M）', () {
      expect(
        Room233Password.encodeRoomPassword(mode: 0, roomName: '  房  '),
        'MR5#房',
      );
      expect(Room233Password.encodeRoomPassword(roomName: '房'), 'M,MR5#房');
    });

    test('与 AI 主机密码的区别：房间串带 #房间名，AI 密码带 AI 前缀', () {
      const roomName = 'room';
      final roomString = Room233Password.encodeRoomPassword(
        roomName: roomName,
      );
      final aiPassword = Room233Password.encodeAiHostPassword();
      expect(roomString, contains('#'));
      expect(roomString, startsWith('M,MR5'));
      expect(aiPassword, startsWith('AI,'));
      expect(aiPassword, isNot(contains('#')));
    });

    test('房间名为空时只保留 token 部分', () {
      expect(
        Room233Password.encodeRoomPassword(mode: 0),
        'MR5#',
      );
    });
  });

  group('Room233Password 禁限 token（由 lfTableIndex 决定）', () {
    test('lfTableIndex > 0 → LFn', () {
      expect(
        Room233Password.encodeRoomPassword(
          mode: 0,
          lfTableIndex: 2,
          roomName: '房',
        ),
        'MR5,LF2#房',
      );
      expect(
        Room233Password.encodeAiHostPassword(mode: 0, lfTableIndex: 2),
        'AI,MR5,LF2',
      );
    });

    test('lfTableIndex == 0 → NF（不使用禁限卡表）', () {
      expect(
        Room233Password.encodeRoomPassword(
          mode: 0,
          lfTableIndex: 0,
          roomName: '房',
        ),
        'MR5,NF#房',
      );
      expect(
        Room233Password.encodeAiHostPassword(mode: 0, lfTableIndex: 0),
        'AI,MR5,NF',
      );
    });

    test('lfTableIndex == -1（默认）→ 不写禁限 token', () {
      expect(
        Room233Password.encodeRoomPassword(mode: 0, roomName: '房'),
        'MR5#房',
      );
      expect(
        Room233Password.encodeAiHostPassword(mode: 0),
        'AI,MR5',
      );
    });
  });

  group('Room233Password.tryParseRoomPassword（房间串解码）', () {
    test('编码 → 解码往返（规则 + 房间名）', () {
      // 房间串上限 20 字符：往返用例只用能放下的 token。
      final roomString = Room233Password.encodeRoomPassword(
        roomName: 'R',
        lfTableIndex: 2,
        mode: 2, // 双打
        duelRule: 4,
      );
      expect(roomString, 'T,MR4,LF2#R');
      final parsed = Room233Password.tryParseRoomPassword(roomString);
      expect(parsed, isNotNull);
      expect(parsed!.roomName, 'R');
      expect(parsed.rules.mode, 2);
      expect(parsed.rules.duelRule, 4);
      expect(parsed.rules.lfTableIndex, 2);
    });

    test('全字段 token 串解码（不走编码的长度限制）', () {
      final parsed = Room233Password.tryParseRoomPassword(
        'T,MR4,OT,TM120,LP4000,ST4,DR2,LF2,NC,NS#房',
      );
      expect(parsed, isNotNull);
      final rules = parsed!.rules;
      expect(rules.mode, 2);
      expect(rules.duelRule, 4);
      expect(rules.rule, 2);
      expect(rules.timeLimit, 120);
      expect(rules.startLp, 4000);
      expect(rules.startHand, 4);
      expect(rules.drawCount, 2);
      expect(rules.noCheckDeck, isTrue);
      expect(rules.noShuffleDeck, isTrue);
      expect(rules.lfTableIndex, 2);
      expect(parsed.roomName, '房');
    });

    test('无 # 的串：整体按 token 解析，房间名为空', () {
      final parsed = Room233Password.tryParseRoomPassword('测试房');
      expect(parsed, isNotNull);
      expect(parsed!.roomName, '');
      expect(parsed.rules.mode, 0); // 单局（缺省）
      expect(parsed.rules.duelRule, 5); // MR2020
      expect(parsed.rules.lfTableIndex, -1);
    });

    test('NF / LF<n> 解码为 lfTableIndex', () {
      expect(
        Room233Password.tryParseRoomPassword('M,MR5,NF#房')?.rules.lfTableIndex,
        0,
      );
      expect(
        Room233Password.tryParseRoomPassword('M,MR5,LF3#房')?.rules.lfTableIndex,
        3,
      );
    });

    test('空串 / AI 主机密码返回 null', () {
      expect(Room233Password.tryParseRoomPassword(''), isNull);
      expect(Room233Password.tryParseRoomPassword('  '), isNull);
      expect(Room233Password.tryParseRoomPassword('AI,MR5'), isNull);
      expect(Room233Password.tryParseRoomPassword('AI'), isNull);
    });
  });
}
