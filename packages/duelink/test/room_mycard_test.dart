/// MyCard 服房间密码编解码与私密房 ID 派生的单元测试。
///
/// 对照基准：neos-ts src/api/mycard/room.ts（getCreateRoomPasswd /
/// getJoinRoomPasswd / getPrivateRoomID）与 YGOMobile MyCard.java
/// （createCustomRoomPassword / createPrivateRoomJoinPassword）。
library;

import 'dart:convert';

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('MyCardRoomPassword.derivePrivateRoomId（对照 neos-ts getPrivateRoomID）', () {
    test('external_id ^ 0x54321', () {
      expect(MyCardRoomPassword.derivePrivateRoomId(0), 0x54321); // 344865
      expect(MyCardRoomPassword.derivePrivateRoomId(12345), 12345 ^ 0x54321);
      expect(MyCardRoomPassword.derivePrivateRoomId(0x54321), 0); // 自逆
      const externalId = 987654;
      expect(
        MyCardRoomPassword.derivePrivateRoomId(externalId),
        externalId ^ 0x54321,
      );
      expect(
        MyCardRoomPassword.derivePrivateRoomId(
          MyCardRoomPassword.derivePrivateRoomId(externalId),
        ),
        externalId,
      );
    });
  });

  group('encodeCreate / encodeJoin 动作位（对照 RoomAction 枚举）', () {
    // 解码 base64 前 6 字节，把 XOR 还原后检查 buf[1] 高 4 位动作位。
    int actionNibble(String encoded, int secret) {
      final buf = base64Decode(encoded.substring(0, 8)); // 6 字节 → 8 字符
      expect(buf.length, 6);
      final encryptSecret = (secret % 65535) + 1;
      final b1 = buf[1] ^ ((encryptSecret >> 8) & 0xff);
      return b1 >> 4;
    }

    test('createPrivate=2 / createPublic=1', () {
      final priv = MyCardRoomPassword.encodeCreate(
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      expect(actionNibble(priv, 999), 2);
      expect(priv.endsWith('344865'), isTrue); // base64 后缀拼房间 ID

      final pub = MyCardRoomPassword.encodeCreate(secret: 999);
      expect(actionNibble(pub, 999), 1);
    });

    test('joinPrivate=5 / joinPublic=3', () {
      final priv = MyCardRoomPassword.encodeJoin(
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      expect(actionNibble(priv, 999), 5);
      expect(priv.endsWith('344865'), isTrue);

      final pub = MyCardRoomPassword.encodeJoin(secret: 999);
      expect(actionNibble(pub, 999), 3);
    });

    test('secret 影响密文（u16Secret 时间轮换语义）', () {
      final a = MyCardRoomPassword.encodeCreate(
        roomId: '1',
        secret: 100,
        isPrivate: true,
      );
      final b = MyCardRoomPassword.encodeCreate(
        roomId: '1',
        secret: 101,
        isPrivate: true,
      );
      expect(a, isNot(b));
      // 同一 secret 结果确定（纯函数）
      expect(
        MyCardRoomPassword.encodeCreate(
          roomId: '1',
          secret: 100,
          isPrivate: true,
        ),
        a,
      );
    });

    test('规则参数写入 buffer[1]/[2]（mode/duelRule/rule/noCheck）', () {
      // 仅验证不同规则产生不同密文（位布局由 neos-ts 对照保证）。
      String encode({int mode = 1, int duelRule = 5, int rule = 0}) =>
          MyCardRoomPassword.encodeCreate(
            mode: mode,
            duelRule: duelRule,
            rule: rule,
            secret: 999,
          );
      expect(encode(mode: 0), isNot(encode(mode: 1)));
      expect(encode(duelRule: 3), isNot(encode(duelRule: 5)));
      expect(encode(rule: 2), isNot(encode(rule: 0)));
    });
  });

  group('tryParseCreatePassword / tryParseJoinPassword（解码）', () {
    test('建房密码编码 → 解码往返', () {
      final password = MyCardRoomPassword.encodeCreate(
        mode: 2,
        duelRule: 4,
        rule: 2,
        noCheckDeck: true,
        startLp: 4000,
        startHand: 4,
        drawCount: 2,
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      final parsed = MyCardRoomPassword.tryParseCreatePassword(
        password,
        secret: 999,
      );
      expect(parsed, isNotNull);
      expect(parsed!.mode, 2);
      expect(parsed.duelRule, 4);
      expect(parsed.rule, 2);
      expect(parsed.noCheckDeck, isTrue);
      expect(parsed.noShuffleDeck, isFalse);
      expect(parsed.startLp, 4000);
      expect(parsed.startHand, 4);
      expect(parsed.drawCount, 2);
      expect(parsed.roomId, '344865');
      expect(parsed.isPrivate, isTrue);
    });

    test('公开建房：isPrivate=false', () {
      final password = MyCardRoomPassword.encodeCreate(secret: 42);
      final parsed = MyCardRoomPassword.tryParseCreatePassword(
        password,
        secret: 42,
      );
      expect(parsed, isNotNull);
      expect(parsed!.isPrivate, isFalse);
      expect(parsed.roomId, isEmpty);
    });

    test('加入密码编码 → 解码往返（BOM 还原为空格）', () {
      final password = MyCardRoomPassword.encodeJoin(
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      final parsed = MyCardRoomPassword.tryParseJoinPassword(
        password,
        secret: 999,
      );
      expect(parsed, isNotNull);
      expect(parsed!.roomId, '344865');
      expect(parsed.isPrivate, isTrue);

      final pub = MyCardRoomPassword.tryParseJoinPassword(
        MyCardRoomPassword.encodeJoin(secret: 7),
        secret: 7,
      );
      expect(pub, isNotNull);
      expect(pub!.isPrivate, isFalse);
    });

    test('密钥不匹配 / 动作不符 / 非法串 → null', () {
      final create = MyCardRoomPassword.encodeCreate(
        secret: 999,
        isPrivate: true,
      );
      expect(
        MyCardRoomPassword.tryParseCreatePassword(create, secret: 1000),
        isNull,
      );
      // 加入密码不能当建房密码解，反之亦然。
      final join = MyCardRoomPassword.encodeJoin(secret: 999);
      expect(
        MyCardRoomPassword.tryParseCreatePassword(join, secret: 999),
        isNull,
      );
      expect(
        MyCardRoomPassword.tryParseJoinPassword(create, secret: 999),
        isNull,
      );
      expect(MyCardRoomPassword.tryParseJoinPassword('', secret: 1), isNull);
      expect(
        MyCardRoomPassword.tryParseJoinPassword('not-base64', secret: 1),
        isNull,
      );
    });
  });
}
