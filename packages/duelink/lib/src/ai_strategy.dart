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
    // 这正是"选择→回包→亮牌确认"的标准流程。 服务端发 MSG_CONFIRM_CARDS 不是要你再确认一次，而是把你选择的结果展示出来（给你或给对手看），不需要任何回包。
    //
    // 完整时序
    //
    // 服务端(ocgcore)                     客户端
    // │  MSG_SELECT_CARD (15)            │   ← 交互消息，只发给被请求方
    // │ ──────────────────────────────→  │      (AiLocalServer.cs:793 定向发送)
    // │                                 │   玩家选好 → 组装响应
    // │  CTOS_RESPONSE (0x5) ←──────────│      [count(1)] + [选项索引(1×n)]
    // │                                 │      (GameBehavior.cs:1141-1146)
    // │  set_responseb() 喂回内核        │
    // │  MSG_CONFIRM_CARDS (31)          │   ← 非交互，广播给双方
    // │ ──────────────────────────────→  │      (AiLocalServer.cs:806 BroadcastRaw)
    // │  MSG_MOVE / MSG_REMOVE ...       │
    //
    // 项目代码里的对应实现
    //
    // - WindBot 回包（GameBehavior.cs:1141-1146）：响应体是 [选中数量(1字节)] + [每张在选项列表里的索引]，包进 CtosMessage.Response 发出。不是卡号，是选项索引——协议规定如此。
    // - 服务端接收（AiLocalServer.cs:409 HandleResponse）：收到后存 _pendingResponse 并 _responseEvent.Set()，决斗线程取出来喂给 ocgcore（set_responseb），内核继续跑出后续消息。
    // - CONFIRM_CARDS 是纯广播（AiLocalServer.cs:850 IsInteractiveMessage 不含 31 → 走
    // BroadcastRaw）：player(1)+skip_panel(1)+count(1)+count×7，客户端弹确认框或记日志（GameBehavior.cs:2013 / Ocgcore.cs:4308），处理完不回复。
    // 判断依据
    //
    // 1. 你的回包已被接受：如果回包格式错误，内核会发 MSG_RETRY(1) 而不是继续。收到 CONFIRM_CARDS 说明 set_responseb 解析成功、决策生效。
    // 2. CONFIRM 内容正是你选择的结果：常见场景——检索类效果（增援/星球改造：选卡组1张→回包→亮给对手确认→入手）、抹杀的使徒（选里侧怪→回包→翻开确认→除外）、看手牌选1张类效果。
    // 3. 之后服务端会继续广播后续消息（MOVE 等），不会再停下来等 CONFIRM 相关的任何东西。
    //
    // 唯一要留意的：CONFIRM_CARDS 里的 skip_panel 字节——引擎对"自己已知"的确认发 1（不弹窗），对"需要展示给对方"的确认发
    // 0（弹窗）。如果发现本该给对手看的确认没弹窗，检查的是这个字节和客户端展示逻辑，而不是回包问题。
      case MSG_CONFIRM_CARDS:
      case MSG_CONFIRM_DECKTOP:
      case MSG_CONFIRM_EXTRATOP:
        //在 ai 弹窗展示玩家拿到的牌
        return null;
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
