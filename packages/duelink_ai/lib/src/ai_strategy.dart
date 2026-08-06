import 'dart:typed_data';

import 'package:duelink/duelink.dart';

/// AI 回合应答策略（纯函数）。
///
/// 策略尽量简单：能通召就通召（优先 4 星以下避免祭品询问），
/// 否则进战阶；战阶能打就打，否则进 M2/EP。
///
/// 这些消息属于 ocgcore `DUEL_SIMPLE_AI` 不覆盖的回合级指令
/// （见 ai_connection.dart 文件头注释），由对局引擎在 PROCESSOR_WAITING
/// 且待应答消息属于 AI 玩家时调用。

/// 主阶段指令应答：优先通召 4 星以下怪兽（5 星以上会触发祭品询问，
/// 由 [aiTributeResponse] 兜底，但简单起见优先低星）。
///
/// [levelOf] 按卡号查询等级（未知卡按 0 处理，视为可直接通召）。
Uint8List aiIdleResponse(MsgSelectIdleCmd cmd, int? Function(int code) levelOf) {
  final summon = cmd.commandGroups[0].options;
  var fallback = -1;
  for (var i = 0; i < summon.length; i++) {
    final level = levelOf(summon[i].cardInfo.code) ?? 0;
    if (fallback < 0) fallback = i;
    if (level <= 4) {
      return CtosGameMsgResponse.selectIdleCmd((i << 16) + 0).encode();
    }
  }
  if (fallback >= 0) {
    return CtosGameMsgResponse.selectIdleCmd((fallback << 16) + 0).encode();
  }
  if (cmd.enableBp) return CtosGameMsgResponse.selectIdleCmd(6).encode();
  if (cmd.enableEp) return CtosGameMsgResponse.selectIdleCmd(7).encode();
  // 兜底：选第一组非空选项
  for (var g = 0; g < cmd.commandGroups.length; g++) {
    if (cmd.commandGroups[g].options.isNotEmpty) {
      return CtosGameMsgResponse.selectIdleCmd(g).encode();
    }
  }
  return CtosGameMsgResponse.selectIdleCmd(7).encode();
}

/// 战阶指令应答：能攻击就攻击，否则进 M2/EP。
Uint8List aiBattleResponse(MsgSelectBattleCmd cmd) {
  final attack = cmd.commandGroups[1].options;
  if (attack.isNotEmpty) {
    return CtosGameMsgResponse.selectBattleCmd(1).encode(); // (0<<16)|1
  }
  if (cmd.enableM2) return CtosGameMsgResponse.selectBattleCmd(2).encode();
  return CtosGameMsgResponse.selectBattleCmd(3).encode();
}

/// 祭品选择应答：按最小数量顺序选前 N 只。
Uint8List aiTributeResponse(MsgSelectTribute cmd) {
  return CtosGameMsgResponse.selectMulti(
    List<int>.generate(cmd.min, (i) => i),
  ).encode();
}
