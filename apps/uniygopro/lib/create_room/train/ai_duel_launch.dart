/// 人机对决：按规则面板生成 AI 对局参数并直接开局。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/route.dart';
import '../../config/servers.dart';
import 'package:ygo_settings/ai_settings.dart';
import '../models/banlist_options.dart';
import '../models/mode_models.dart';
import '../widgets/room_rule_panel.dart';

/// 按面板配置生成 AI 对局参数。
RoomOptions buildAiOptions(RoomRuleConfig config, {int agent = 0}) {
  return RoomOptions(
    lfTableHash: BanlistCatalog.hashAt(config.banlist),
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
    agent: agent,
  );
}

/// 人机对决：按设置页的 AI 偏好开局（本地引擎 / 233 服 AI）。
Future<void> startAiDuel(BuildContext context, RoomRuleConfig config) async {
  final ai = await loadAiSettings();
  // 233 服 AI 的推理模型由服务端决定，agent 固定 -1。
  final options = buildAiOptions(
    config,
    agent: ai.useServer233 ? -1 : ai.agent,
  );
  final env = ai.useServer233 ? DuelEnvironment.mercury233 : DuelEnvironment.ai;
  final base = Uri.tryParse('${env.schema}://${env.host}:${env.port}');
  final banlistToken = ai.useServer233
      ? BanlistCatalog.mercury233TokenForHash(options.lfTableHash)
      : '';
  if (!context.mounted) return;
  final api = context.read<MyCardAccountApi>();
  final username = api.account?.username.isNotEmpty == true
      ? api.account?.username
      : "Guest";
  context.go(
    Routes.duelRoom,
    extra: <String, Object?>{
      'uri': base?.replace(queryParameters: options.toAiQuery()),
      'serverPassword': RoomTokens.encodeAiPassword(
        options,
        banlistToken: banlistToken,
      ),
      'username': username,
      'roomName': 'AI 人机对战',
    },
  );
}
