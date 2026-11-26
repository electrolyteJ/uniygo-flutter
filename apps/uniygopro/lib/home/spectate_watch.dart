/// 观战进房：由观战列表（旧观战面板 / 主页「比赛观看」）共用的准备逻辑。
///
/// 只负责认证、u16Secret、房间密码与 MatchStore 选择，不负责关闭弹层/跳转；
/// 调用方在拿到 [SpectateWatchRequest] 后自行 pop/go，并 reset 匹配状态。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:duelink/duelink.dart' show MyCardRoomPassword;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/servers.dart';
import '../login/mycard_gate.dart';
import 'services/spectate_service.dart';

/// 准备进入观战；用户取消登录或失败返回 null（错误已提示）。
Future<Map<String, Object?>?> prepareSpectateWatch(
  BuildContext context, {
  required GameServer server,
  required SpectateRoom room,
}) async {
  final account = await requireMyCardAccount(context, reason: '进入观战');
  if (account == null || !context.mounted) return null;

  try {
    final u16Secret = await context.read<MyCardAccountApi>().fetchU16Secret();
    if (!context.mounted) return null;
    final password = MyCardRoomPassword.encodeJoin(
      roomId: room.id,
      secret: u16Secret,
      isPrivate: false,
    );
    return {
      'uri': Uri.tryParse('wss://${server.duelHost}:${server.duelPort}'),
      'serverPassword': password,
      'username': account.username,
      'roomName': room.playersLabel,
    };
  } on MyCardAuthException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('进入观战失败：$e')));
    }
    return null;
  }
}
