/// 残局：读取本地残局合集并进入残局对局。
library;

import 'package:biz/service_singleton.dart';
import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/route.dart';
import '../../config/servers.dart';
import '../match_store.dart';

/// 读取本地残局合集。
Future<List<PuzzleInfo>> loadPuzzles() =>
    ServiceSingleton.instance.puzzleService.listPuzzles();

/// 残局挑战：写 MatchStore 后进入本地残局对局。
void startPuzzle(BuildContext context, PuzzleInfo info) {
  context.read<MatchStore>().selectPuzzle(
    gameServers.firstWhere((s) => s.type == ServerType.puzzleRoom),
    info.scriptName,
  );
  context.go(Routes.duelRoom);
}
