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
import '../models/banlist_options.dart';
import '../models/mode_models.dart';
import '../widgets/room_rule_panel.dart';
import 'created_room_record.dart';
import 'room_history_store.dart';

/// 面板配置 → 房间参数（自由房间只暴露赛制/大师规则/LP/手牌/抽卡/时限）。
RoomOptions roomOptionsOf(RoomRuleConfig config) {
  return RoomOptions(
    lfTableHash: BanlistCatalog.hashAt(config.banlist),
    // RoomRuleConfig.mode：0=双打 2v2 / 1=三局两胜 / 2=单局。
    mode: switch (config.mode) {
      0 => RoomMode.tag,
      1 => RoomMode.match,
      _ => RoomMode.single,
    },
    rule: config.rule,
    duelRule: config.master == 1 ? DuelRule.mr4 : DuelRule.mr2020,
    noCheckDeck: config.noCheck,
    noShuffleDeck: config.noShuffle,
    startLp: int.tryParse(RoomRuleOptions.lps[config.lp]) ?? 8000,
    startHand: int.tryParse(RoomRuleOptions.hands[config.hand]) ?? 5,
    drawCount: int.tryParse(RoomRuleOptions.draws[config.draw]) ?? 1,
    timeLimit:
        int.tryParse(RoomRuleOptions.times[config.time].replaceAll(' 秒', '')) ??
        0,
  );
}

/// 6 位随机邀码：服务端不提供房间号时用于本地邀请展示。
String randomRoomCode() {
  final rnd = math.Random();
  return List.generate(6, (_) => rnd.nextInt(10)).join();
}

GameServer get _server =>
    gameServers.firstWhere((s) => s.type == ServerType.freeRoom);

/// 按环境匹配服务器（408 有独立域名/端口）。
GameServer _serverFor(DuelEnvironment env) {
  for (final s in gameServers) {
    if (s.host == env.host && s.port == env.port) return s;
  }
  return _server;
}

/// 圆盘动作：按环境建房（Koishi 不能建房，退化为加入公共房）。
Future<void> createFreeRoom(
  BuildContext context, {
  required DuelEnvironment env,
  required RoomRuleConfig config,
  String? roomName,
}) async {
  final options = roomOptionsOf(config);

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
    final roomId = '${RoomPassword.privateRoomId(externalId)}';
    final password = RoomPassword.encodeCreate(
      options: options,
      roomId: roomId,
      secret: u16,
      isPrivate: true,
    );
    final name = 'MyCard 私密房 $roomId';
    unawaited(
      RoomHistoryStore.add(
        CreatedRoomRecord(
          env: env,
          roomName: name,
          password: roomId,
          options: options,
        ),
      ),
    );
    _enter(
      context,
      env,
      options,
      name,
      password,
      account.username,
      roomId: roomId,
    );
    return;
  }

  if (env == DuelEnvironment.mercury233) {
    // 233 的进房凭证是「token#房间名」明文房间串：房间列表不公开、同串即同房，
    // 因此房间名必须随机，避免两间规则相同的房撞成同一间。
    final modeLabel = switch (options.mode) {
      RoomMode.tag => '2v2',
      RoomMode.match => 'BO3',
      _ => '单局',
    };
    // 房间串总长上限 20：房间名用「模式-6位随机」，唯一且够短。
    final effectiveName = '$modeLabel-${randomRoomCode()}';
    final roomString = RoomPassword.encodeMercury233(
      options: options,
      roomName: effectiveName,
      // 233 服只认 LF<n>/NF token；用选中卡表的 hash 反查服务端编号。
      banlistToken: BanlistCatalog.mercury233TokenForHash(options.lfTableHash),
    );
    if (roomString.length > RoomPassword.mercury233MaxLength) {
      if (context.mounted) {
        showSnackBar(
          context,
          '房间串不能超过 ${RoomPassword.mercury233MaxLength} 个字符',
        );
      }
      return;
    }
    unawaited(
      RoomHistoryStore.add(
        CreatedRoomRecord(
          env: env,
          roomName: effectiveName,
          password: roomString,
          options: options,
        ),
      ),
    );
    final api = context.read<MyCardAccountApi>();
    final username = api.account?.username.isNotEmpty == true
        ? api.account?.username
        : "Guest";
    // 房间串就是进房凭证：邀码直接用它，好友复制后粘贴到「加入房间」即可。
    _enter(
      context,
      env,
      options,
      effectiveName,
      roomString,
      username,
      roomId: roomString,
    );
    return;
  }

  if (env == DuelEnvironment.env408) {
    final api = context.read<MyCardAccountApi>();
    final username = api.account?.username.isNotEmpty == true
        ? api.account?.username
        : "Guest";
    final code = randomRoomCode();
    _enter(
      context,
      env,
      options,
      '408 房间 $code',
      code,
      username,
      roomId: code,
      server: _serverFor(env),
    );
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
    pass = RoomPassword.encodeJoin(
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
    null,
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
  RoomOptions? options,
  String roomName,
  String password,
  String? username, {
  String? roomId,
  GameServer? server,
}) {
  Uri? uri = Uri.tryParse('${env.schema}://${env.host}:${env.port}');
  if (context.mounted) {
    router.go(
      Routes.duelRoom,
      extra: {
        'uri': uri,
        'serverPassword': '',
        'username': username,
        'roomName': roomName,
      },
    );
  }
}
