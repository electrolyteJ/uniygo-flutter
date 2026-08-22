import 'room_options.dart';

/// 233 服（ygo233.com）房间串 / AI 主机密码 token 编解码。
///
/// 233 服的「AI 主机密码」格式：AI,<token>,<token>,...
/// （AI 必须在首位，不能带 #房间名；token 与「房名代码」同源，
/// 见 https://ygo233.com/usage）。token 不区分大小写、顺序随意。
///
/// 本 codec 只负责 game-rule token 的双向映射；禁限 token（LF<n>/NF）
/// 属 app 层（RoomOptions 只有 lfTableHash 数值，无 token 字符串），
/// 由 [build] 的 banlistToken 参数原位追加。
///
/// 本地 AI（duelink_ai）用它解析 CTOS_JOIN_GAME 的密码，从 AI,...
/// 恢复房间规则——与 233 服共用同一套 token 定义，避免两处手拼漂移。
class RoomTokens {
  static const String aiPrefix = 'AI';

  /// 编码为 AI 主机密码 AI,<tokens>（不含房间名）。
  ///
  /// [banlistToken] 可选禁限 token（如 LF2/NF），非空时并入 token 列表。
  /// 无任何非默认 token 时返回 AI。
  static String encodeAiPassword(RoomOptions o, {String banlistToken = ''}) {
    final tokens = build(o, banlistToken: banlistToken);
    return tokens.isEmpty ? aiPrefix : aiPrefix + ',' + tokens.join(',');
  }

  /// 生成 game-rule token 列表（按 233 解析顺序，已过滤默认项）。
  ///
  /// [banlistToken] 可选禁限 token（如 LF2/NF），非空时插在 DR
  /// 之后、NC/NS 之前，与历史输出顺序一致。
  static List<String> build(RoomOptions o, {String banlistToken = ''}) {
    return <String>[
      switch (o.mode) {
        RoomMode.single => '',
        RoomMode.match => 'M',
        RoomMode.tag => 'T',
      },
      switch (o.duelRule) {
        DuelRule.mr3 => 'MR3',
        DuelRule.mr4 => 'MR4',
        DuelRule.mr2020 => 'MR5',
      },
      switch (o.rule) {
        2 => 'OT',
        1 => 'TO',
        4 => 'NU',
        _ => '',
      },
      if (o.timeLimit != 180) 'TM' + o.timeLimit.toString(),
      if (o.startLp != 8000) 'LP' + o.startLp.toString(),
      if (o.startHand != 5) 'ST' + o.startHand.toString(),
      if (o.drawCount != 1) 'DR' + o.drawCount.toString(),
      if (banlistToken.isNotEmpty) banlistToken,
      if (o.noCheckDeck) 'NC',
      if (o.noShuffleDeck) 'NS',
    ]..removeWhere((c) => c.isEmpty);
  }

  /// 解析 AI,<tokens> 密码为房间规则；非 AI 密码返回 null。
  ///
  /// 仅识别 game-rule token；LF<n>/NF（禁限）、S（单局）等
  /// 本地 AI 不关心的 token 会被忽略。解析结果不含
  /// [RoomOptions.agent]/[RoomOptions.agentServer]（模型装配参数），
  /// 调用方应沿用 connect() 里解析得到的这些字段。
  static RoomOptions? tryParseAiPassword(String passwd) {
    final trimmed = passwd.trim();
    if (trimmed != aiPrefix && !trimmed.startsWith(aiPrefix + ',')) return null;

    final rest = trimmed.substring(aiPrefix.length);
    final tokens = rest
        .split(',')
        .map((t) => t.trim().toUpperCase())
        .where((t) => t.isNotEmpty);

    var mode = RoomMode.single;
    var duelRule = DuelRule.mr2020;
    var rule = 0;
    var timeLimit = 180;
    var startLp = 8000;
    var startHand = 5;
    var drawCount = 1;
    var noCheckDeck = false;
    var noShuffleDeck = false;

    for (final token in tokens) {
      if (token == 'M') {
        mode = RoomMode.match;
      } else if (token == 'T') {
        mode = RoomMode.tag;
      } else if (token == 'MR3') {
        duelRule = DuelRule.mr3;
      } else if (token == 'MR4') {
        duelRule = DuelRule.mr4;
      } else if (token == 'MR5') {
        duelRule = DuelRule.mr2020;
      } else if (token == 'OT') {
        rule = 2;
      } else if (token == 'TO') {
        rule = 1;
      } else if (token == 'NU') {
        rule = 4;
      } else if (token.startsWith('TM')) {
        timeLimit = _int(token.substring(2), timeLimit);
      } else if (token.startsWith('LP')) {
        startLp = _int(token.substring(2), startLp);
      } else if (token.startsWith('ST')) {
        startHand = _int(token.substring(2), startHand);
      } else if (token.startsWith('DR')) {
        drawCount = _int(token.substring(2), drawCount);
      } else if (token == 'NC') {
        noCheckDeck = true;
      } else if (token == 'NS') {
        noShuffleDeck = true;
      }
      // 其余 token（LF<n>/NF/S 等）本地 AI 不处理，静默忽略。
    }

    return RoomOptions(
      mode: mode,
      duelRule: duelRule,
      rule: rule,
      noCheckDeck: noCheckDeck,
      noShuffleDeck: noShuffleDeck,
      startLp: startLp,
      startHand: startHand,
      drawCount: drawCount,
      timeLimit: timeLimit,
    );
  }

  static int _int(String s, int fallback) => int.tryParse(s) ?? fallback;
}
