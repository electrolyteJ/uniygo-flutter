import 'package:duel_room3/invite/duel_invite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/create_room/widgets/join_room_button.dart';

void main() {
  group('resolveJoinEnvironment', () {
    test('233 房间串（含 #）固定判为 mercury233', () {
      final env = resolveJoinEnvironment(
        const DuelInvite(roomId: 'M,MR5#BO3-123456'),
        DuelEnvironment.env408,
      );
      expect(env, DuelEnvironment.mercury233);
    });

    test('二维码带房主服务器时按 host/port 精确匹配', () {
      expect(
        resolveJoinEnvironment(
          const DuelInvite(
            roomId: '462890',
            host: 'tiramisu.moenext.com',
            port: 7912,
          ),
          DuelEnvironment.mercury233,
        ),
        DuelEnvironment.mycard,
      );
      expect(
        resolveJoinEnvironment(
          const DuelInvite(
            roomId: '123456',
            host: 'koishi.momobako.com',
            port: 1408,
          ),
          DuelEnvironment.koishi,
        ),
        DuelEnvironment.env408,
      );
    });

    test('没带服务器提示时退回当前页签环境', () {
      expect(
        resolveJoinEnvironment(
          const DuelInvite(roomId: '462890'),
          DuelEnvironment.env408,
        ),
        DuelEnvironment.env408,
      );
    });

    test('当前环境无法用邀请码加入时返回 null', () {
      expect(
        resolveJoinEnvironment(
          const DuelInvite(roomId: '462890'),
          DuelEnvironment.ai,
        ),
        isNull,
      );
    });
  });
}
