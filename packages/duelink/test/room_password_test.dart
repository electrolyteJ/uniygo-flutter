/// RoomPassword 编码与 MyCard 私密房 ID 派生的单元测试。
///
/// 对照基准：neos-ts src/api/mycard/room.ts（getCreateRoomPasswd /
/// getJoinRoomPasswd / getPrivateRoomID）与 YGOMobile MyCard.java
/// （createCustomRoomPassword / createPrivateRoomJoinPassword）。
library;

import 'dart:convert';

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('RoomPassword.privateRoomId（对照 neos-ts getPrivateRoomID）', () {
    test('external_id ^ 0x54321', () {
      expect(RoomPassword.privateRoomId(0), 0x54321); // 344865
      expect(RoomPassword.privateRoomId(12345), 12345 ^ 0x54321);
      expect(RoomPassword.privateRoomId(0x54321), 0); // 自逆：x ^ k ^ k == x
      // 与同一 external_id 往返一致（同一用户的私密房 ID 恒定）
      const externalId = 987654;
      expect(
        RoomPassword.privateRoomId(externalId),
        externalId ^ 0x54321,
      );
      expect(
        RoomPassword.privateRoomId(RoomPassword.privateRoomId(externalId)),
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
      // XOR 自逆：逐 2 字节还原
      final b1 = buf[1] ^ ((encryptSecret >> 8) & 0xff);
      return b1 >> 4;
    }

    test('createPrivate=2 / createPublic=1', () {
      const options = RoomOptions();
      final priv = RoomPassword.encodeCreate(
        options: options,
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      expect(actionNibble(priv, 999), 2);
      expect(priv.endsWith('344865'), isTrue); // base64 后缀拼房间 ID

      final pub = RoomPassword.encodeCreate(options: options, secret: 999);
      expect(actionNibble(pub, 999), 1);
    });

    test('joinPrivate=5 / joinPublic=3', () {
      final priv = RoomPassword.encodeJoin(
        roomId: '344865',
        secret: 999,
        isPrivate: true,
      );
      expect(actionNibble(priv, 999), 5);
      expect(priv.endsWith('344865'), isTrue);

      final pub = RoomPassword.encodeJoin(secret: 999);
      expect(actionNibble(pub, 999), 3);
    });

    test('secret 影响密文（u16Secret 时间轮换语义）', () {
      const options = RoomOptions();
      final a = RoomPassword.encodeCreate(
        options: options,
        roomId: '1',
        secret: 100,
        isPrivate: true,
      );
      final b = RoomPassword.encodeCreate(
        options: options,
        roomId: '1',
        secret: 101,
        isPrivate: true,
      );
      expect(a, isNot(b));
      // 同一 secret 结果确定（纯函数）
      expect(
        RoomPassword.encodeCreate(
          options: options,
          roomId: '1',
          secret: 100,
          isPrivate: true,
        ),
        a,
      );
    });
  });
}
