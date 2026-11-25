import 'package:duel_room3/invite/duel_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuelInvite.buildLink', () {
    test('无服务器提示时只有 room', () {
      expect(DuelInvite.buildLink('462890'), 'uniygo://duel?room=462890');
    });

    test('带 host/port 写入 h/p', () {
      final uri = Uri.parse(
        DuelInvite.buildLink('M,MR5#房', host: 's1.ygo233.com', port: 233),
      );
      expect(uri.scheme, 'uniygo');
      expect(uri.host, 'duel');
      expect(uri.queryParameters['room'], 'M,MR5#房');
      expect(uri.queryParameters['h'], 's1.ygo233.com');
      expect(uri.queryParameters['p'], '233');
    });
  });

  group('DuelInvite.tryParse', () {
    test('深链：room + 服务器提示', () {
      final invite = DuelInvite.tryParse(
        'uniygo://duel?room=462890&h=s1.ygo233.com&p=233',
      )!;
      expect(invite.roomId, '462890');
      expect(invite.host, 's1.ygo233.com');
      expect(invite.port, 233);
      expect(invite.hasServerHint, isTrue);
    });

    test('旧二维码：只有 room', () {
      final invite = DuelInvite.tryParse('uniygo://duel?room=462890')!;
      expect(invite.roomId, '462890');
      expect(invite.host, isNull);
      expect(invite.hasServerHint, isFalse);
    });

    test('裸邀码与 233 房间串', () {
      expect(DuelInvite.tryParse('462890')!.roomId, '462890');
      expect(
        DuelInvite.tryParse('M,MR5#BO3-123456')!.roomId,
        'M,MR5#BO3-123456',
      );
      expect(DuelInvite.tryParse('  462890  ')!.roomId, '462890');
    });

    test('无法识别的输入返回 null', () {
      expect(DuelInvite.tryParse(''), isNull);
      expect(DuelInvite.tryParse('   '), isNull);
      expect(DuelInvite.tryParse('uniygo://duel'), isNull);
      expect(DuelInvite.tryParse('x' * 65), isNull);
    });

    test('buildLink / tryParse 往返（含特殊字符）', () {
      final link = DuelInvite.buildLink('A B#x', host: 'h', port: 1);
      final parsed = DuelInvite.tryParse(link)!;
      expect(parsed.roomId, 'A B#x');
      expect(parsed.host, 'h');
      expect(parsed.port, 1);
    });
  });
}
