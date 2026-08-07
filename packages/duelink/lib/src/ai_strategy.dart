import 'dart:typed_data';

import '../duelink.dart';

/// AI 回合应答策略（纯函数）。
///
/// 策略尽量简单：能通召就通召（优先 4 星以下避免祭品询问），
/// 否则进战阶；战阶能打就打，否则进 M2/EP。
///
/// 这些消息属于 ocgcore `DUEL_SIMPLE_AI` 不覆盖的回合级指令，
/// 由对局引擎（ocgcore 包 DuelEngine）在 PROCESSOR_WAITING
/// 且待应答消息属于 AI 玩家时通过 [aiAutoAnswer] 闭包调用。

/// 构造 DuelEngine 的 SIMPLE_AI 自动应答闭包：
/// 输入待应答消息的 func 与原始载荷（不含 func 头字节），输出响应字节；
/// 无法自动应答时返回 null。
///
/// [levelOf] 按卡号查询等级（供通召策略判断祭品）。
Uint8List? Function(int func, Uint8List payload) aiAutoAnswer(
  int? Function(int code) levelOf,
) {
  return (func, payload) {
    switch (func) {
      case MSG_SELECT_IDLE_CMD:
        return aiIdleResponse(MsgSelectIdleCmd.decode(payload), levelOf);
      case MSG_SELECT_BATTLE_CMD:
        return aiBattleResponse(MsgSelectBattleCmd.decode(payload));
      case MSG_SELECT_TRIBUTE:
        return aiTributeResponse(MsgSelectTribute.decode(payload));
    }
    return null;
  };
}

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
