/// 自由房间的开房 / 进房动作（面板参数 + 圆盘一个动作）。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:account_mycard/account_mycard.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../login/mycard_gate.dart';
import '../../config/route.dart';
import '../../config/servers.dart';
import '../../util/snack_bar_util.dart';
import '../util/banlist_util.dart';
import '../widgets/room_rule_panel.dart';


/// 6 位随机邀码：服务端不提供房间号时用于本地邀请展示。
String randomRoomCode() {
  final rnd = math.Random();
  return List.generate(6, (_) => rnd.nextInt(10)).join();
}

/// 圆盘动作：按环境建房（Koishi 不能建房，退化为加入公共房）。
Future<void> createFreeRoom(
  BuildContext context, {
  required DuelEnvironment env,
  required RoomRuleConfig config,
}) async {
  if (env == DuelEnvironment.mycard) {
    final account = await requireMyCardAccount(
      context,
      reason: '创建 MyCard 私密房间',
    );
    if (account == null) return;
    if (!context.mounted) return;
    final u16 = await context.read<MyCardAccountApi>().fetchU16Secret();
    final externalId = account.externalId != 0
        ? account.externalId
        : account.id;
    final roomId = '${MyCardRoomPassword.derivePrivateRoomId(externalId)}';
    final roomName = 'MyCard 私密房 $roomId';
    final password = MyCardRoomPassword.encodeCreate(
      mode: config.mode, // 0=单局 / 1=三局两胜 / 2=双打
      duelRule: config.duelRuleValue,
      rule: config.rule,
      noCheckDeck: config.noCheck,
      noShuffleDeck: config.noShuffle,
      autoDeath: config.autoDeath,
      startLp: config.startLpValue,
      startHand: config.startHandValue,
      drawCount: config.drawCountValue,
      roomId: roomId,
      secret: u16,
      isPrivate: true,
    );
    _enter(context, env, roomName, password, account.username, roomId: roomId);
    return;
  }

  if (env == DuelEnvironment.mercury233) {
    // 233 的进房凭证是「token#房间名」明文房间串：房间列表不公开、同串即同房，
    // 因此房间名必须随机，避免两间规则相同的房撞成同一间。
    final modeLabel = switch (config.mode) {
      0 => '单局',
      1 => 'BO3',
      _ => '2v2',
    };
    // 房间串总长上限 20：房间名用「模式-6位随机」，唯一且够短。
    final roomString = Room233Password.encodeRoomPassword(
      roomName: '$modeLabel-${randomRoomCode()}',
      // 233 卡表序号（>0 → LFn，0 → NF，-1 → 不写）。
      lfTableIndex: BanlistUtil.mercury233IndexAt(config.banlist),
      mode: config.mode, // 0=单局 / 1=三局两胜 / 2=双打
      duelRule: config.duelRuleValue,
      rule: config.rule,
      timeLimit: config.timeLimitValue,
      startLp: config.startLpValue,
      startHand: config.startHandValue,
      drawCount: config.drawCountValue,
      noCheckDeck: config.noCheck,
      noShuffleDeck: config.noShuffle,
    );
    // encodeRoomPassword 会自动截断房间名以满足 20 字符上限；
    // 返回空串说明 token 本身已占满上限，只能提示精简规则。
    if (roomString.isEmpty) {
      if (context.mounted) {
        showSnackBar(context, '当前规则选项过多，无法生成 233 房间串');
      }
      return;
    }
    // 以房间串里实际生效的名字为准（历史记录/展示与密码一致）。
    final hashIndex = roomString.indexOf('#');
    final effectiveName = hashIndex >= 0
        ? roomString.substring(hashIndex + 1)
        : roomString;
    final api = context.read<MyCardAccountApi>();
    final username = api.account?.username.isNotEmpty == true
        ? api.account?.username
        : "Guest";
    // 房间串就是进房凭证：邀码直接用它，好友复制后粘贴到「加入房间」即可。
    _enter(context, env, effectiveName, roomString, username, roomId: roomString);
    return;
  }

  if (env == DuelEnvironment.env408) {
    final api = context.read<MyCardAccountApi>();
    final username = api.account?.username.isNotEmpty == true
        ? api.account?.username
        : "Guest";
    final code = randomRoomCode();
    _enter(context, env, '408 房间 $code', code, username, roomId: code);
    return;
  }

  // Koishi 只能加入公共房，建房动作退化为加入。
  if (context.mounted) showSnackBar(context, 'Koishi 通用环境只能加入公共房');
}

/// 加入房间：Koishi 直接用密码；MyCard 用房间号 + u16Secret 编码；233 用房间串。
Future<void> joinFreeRoom(
  BuildContext context, {
  required DuelEnvironment env,
  String roomId = '',
  String password = '',
}) async {
  var pass = password;
  String? username;

  if (env == DuelEnvironment.mycard) {
    final account = await requireMyCardAccount(
      context,
      reason: '加入 MyCard 私密房间',
    );
    if (account == null) return;
    if (!context.mounted) return;
    final u16 = await context.read<MyCardAccountApi>().fetchU16Secret();
    username = account.username;
    pass = MyCardRoomPassword.encodeJoin(
      roomId: roomId,
      secret: u16,
      isPrivate: true,
    );
  }

  if (pass.isEmpty) {
    if (context.mounted) showSnackBar(context, '请填写房间密码');
    return;
  }
  _enter(
    context,
    env,
    '',
    pass,
    username,
    // MyCard 私密房用用户输入的房间号；公开房（含 408）随机生成一个用于邀请展示。
    roomId: roomId.isNotEmpty ? roomId : randomRoomCode(),
  );
}

void _enter(
  BuildContext context,
  DuelEnvironment env,
  String roomName,
  String password,
  String? username, {
  String? roomId,
}) {
  if (!context.mounted) return;
  router.go(Routes.duelRoom, extra: <String, Object?>{
    'uri': Uri.tryParse('${env.schema}://${env.host}:${env.port}'),
    'serverPassword': password,
    'username': username,
    'roomName': roomName,
    'roomId': roomId,
  });
}
