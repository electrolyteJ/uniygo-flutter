/// 人机对决：按规则面板生成 AI 对局参数并直接开局。
library;

import 'package:account_mycard/account_mycard.dart';
import 'package:duelink/duelink.dart' show Room233Password;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/route.dart';
import '../../config/servers.dart';
import 'package:ygo_settings/ai_settings.dart';
import '../models/banlist_options.dart';
import '../models/room_rule_config.dart';

/// 本地 AI 引擎的连接查询参数（规则经 URI 传给本地引擎）。
Map<String, String> aiQueryOf(RoomRuleConfig config, {int agent = 0}) => {
      'lp': config.startLpValue.toString(),
      'hand': config.startHandValue.toString(),
      'draw': config.drawCountValue.toString(),
      'rule': config.rule.toString(),
      'mode': config.mode.toString(),
      'mr': config.duelRuleValue.toString(),
      'nc': config.noCheck ? '1' : '0',
      'ns': config.noShuffle ? '1' : '0',
      'tl': config.timeLimitValue.toString(),
      'agent': agent.toString(),
    };

/// 人机对决：按设置页的 AI 偏好开局（本地引擎 / 233 服 AI）。
Future<void> startAiDuel(BuildContext context, RoomRuleConfig config) async {
  final ai = await loadAiSettings();
  // 233 服 AI 的推理模型由服务端决定，agent 固定 -1。
  final agent = ai.useServer233 ? -1 : ai.agent;
  final env = ai.useServer233 ? DuelEnvironment.mercury233 : DuelEnvironment.ai;
  final base = Uri.tryParse(env.schema + '://' + env.host + ':' + env.port.toString());
  if (!context.mounted) return;
  final api = context.read<MyCardAccountApi>();
  final username = api.account?.username.isNotEmpty == true
      ? api.account?.username
      : "Guest";
  context.go(
    Routes.duelRoom,
    extra: <String, Object?>{
      'uri': base?.replace(queryParameters: aiQueryOf(config, agent: agent)),
      'serverPassword': Room233Password.encodeAiHostPassword(
        // 233 卡表序号（>0 → LFn，0 → NF，-1 → 不写）。
        lfTableIndex: BanlistCatalog.mercury233IndexAt(config.banlist),
        mode: config.mode, // 0=单局 / 1=三局两胜 / 2=双打
        duelRule: config.duelRuleValue,
        rule: config.rule,
        timeLimit: config.timeLimitValue,
        startLp: config.startLpValue,
        startHand: config.startHandValue,
        drawCount: config.drawCountValue,
        noCheckDeck: config.noCheck,
        noShuffleDeck: config.noShuffle,
      ),
      'username': username,
      'roomName': 'AI 人机对战',
    },
  );
}
