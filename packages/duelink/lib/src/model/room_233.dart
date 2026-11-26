/// 233 服（ygo233.com）房间密码 / AI 主机密码编解码。
///
/// 233 服有两种「密码」，都由同一套 game-rule token 拼成：
///
/// * 房间密码（建房凭证，也是加入凭证）：明文房间串
///   「MR5,LP4000,NC#房间名」。服务器按串解析房间规则，同一串即同一间房，
///   好友复制粘贴即可加入。
/// * AI 主机密码：AI 前缀 + token 列表，如「AI,MR5,LP4000」。
///   AI 必须在首位，且不能带「#房间名」。
///
/// token 与「房名代码」同源（见 https://ygo233.com/usage），
/// 不区分大小写、顺序随意。
///
/// 本 codec 与协议层 RoomOptions 解耦：入参是直接的游戏规则字段
/// （均按 ygopro 协议取值），输出 token 串；解码返回 [Room233Rules]。
///
/// 本地 AI（duelink_ai）用 [tryParseAiHostPassword] 解析 CTOS_JOIN_GAME
/// 的密码，从「AI,token」恢复房间规则——与 233 服共用同一套 token 定义，
/// 避免两处手拼漂移。
library;

/// 233 token 解码出的房间规则（均为 ygopro 协议取值）。
///
/// * [mode]：0=单局 / 1=三局两胜 / 2=双打
/// * [duelRule]：3=MR3 / 4=MR4 / 5=MR2020
/// * [rule]：0=OCG / 1=TCG / 2=OT 混 / 4=专有卡禁止
/// * [lfTableIndex]：>0=LF<n> 序号 / 0=NF（无禁限） / -1=未指定
typedef Room233Rules = ({
  int mode,
  int duelRule,
  int rule,
  int timeLimit,
  int startLp,
  int startHand,
  int drawCount,
  bool noCheckDeck,
  bool noShuffleDeck,
  int lfTableIndex,
});

/// 房间串解码结果：规则 + 房间名（`#` 后的部分，可能为空）。
typedef Room233Room = ({Room233Rules rules, String roomName});

/// 233 服房间串 / AI 主机密码 codec。
class Room233Password {
  /// AI 主机密码前缀。
  static const String _aiPrefix = 'AI';

  /// 房间密码（房间串）最大长度：服务器解析上限，超出会被拒绝。
  static const int _maxRoomStringLength = 20;

  // ── 编码 ──────────────────────────────────────────────────────────

  /// 编码房间密码（房间串）。
  ///
  /// [roomName] 房间名（去首尾空格；为空时只输出 token 部分）
  /// [lfTableIndex] 禁限序号：>0 → LFn，0 → NF，-1 → 不写
  /// [mode] 0=单局 / 1=三局两胜 / 2=双打
  /// [duelRule] 3=MR3 / 4=MR4 / 5=MR2020
  /// [rule] 0=OCG / 1=TCG / 2=OT 混 / 4=专有卡禁止
  ///
  /// 返回「tokens#房间名」；没有任何规则 token 时只返回房间名。
  /// 结果会自动收敛到服务器的 20 字符上限以内：超出时**按需截断房间名**
  /// （只动房间名，不动 token——规则 token 是服务器解析房间的依据）。
  /// 若 token 本身已占满上限，无法再压缩，返回**空串**，
  /// 调用方应提示用户精简规则选项。
  static String encodeRoomPassword({
    String roomName = '',
    int lfTableIndex = -1,
    int mode = 1,
    int duelRule = 5,
    int rule = 0,
    int timeLimit = 180,
    int startLp = 8000,
    int startHand = 5,
    int drawCount = 1,
    bool noCheckDeck = false,
    bool noShuffleDeck = false,
  }) {
    final tokens = _buildTokens((
      mode: mode,
      duelRule: duelRule,
      rule: rule,
      timeLimit: timeLimit,
      startLp: startLp,
      startHand: startHand,
      drawCount: drawCount,
      noCheckDeck: noCheckDeck,
      noShuffleDeck: noShuffleDeck,
      lfTableIndex: lfTableIndex,
    ));
    final name = roomName.trim();
    if (tokens.isEmpty) {
      return _clip(name, _maxRoomStringLength);
    }
    final tokenPart = tokens.join(',');
    final prefix = tokenPart + '#';
    final available = _maxRoomStringLength - prefix.length;
    // token 已占满上限：房间名无可压缩空间，无法生成合法房间串。
    if (available <= 0) return '';
    return prefix + _clip(name, available);
  }

  /// 编码 AI 主机密码「AI,token,...」（不含房间名）。
  ///
  /// 参数语义同 [encodeRoomPassword]；无任何非默认 token 时返回 AI。
  static String encodeAiHostPassword({
    int lfTableIndex = -1,
    int mode = 1,
    int duelRule = 5,
    int rule = 0,
    int timeLimit = 180,
    int startLp = 8000,
    int startHand = 5,
    int drawCount = 1,
    bool noCheckDeck = false,
    bool noShuffleDeck = false,
  }) {
    final tokens = _buildTokens((
      mode: mode,
      duelRule: duelRule,
      rule: rule,
      timeLimit: timeLimit,
      startLp: startLp,
      startHand: startHand,
      drawCount: drawCount,
      noCheckDeck: noCheckDeck,
      noShuffleDeck: noShuffleDeck,
      lfTableIndex: lfTableIndex,
    ));
    return tokens.isEmpty ? _aiPrefix : _aiPrefix + ',' + tokens.join(',');
  }

  // ── 解码 ──────────────────────────────────────────────────────────

  /// 解析 AI 主机密码为 [Room233Rules]；非 AI 密码返回 null。
  ///
  /// 仅识别 game-rule token；S（单局）等本地 AI 不关心的 token 会被忽略。
  static Room233Rules? tryParseAiHostPassword(String passwd) {
    final trimmed = passwd.trim();
    if (trimmed != _aiPrefix && !trimmed.startsWith(_aiPrefix + ',')) {
      return null;
    }
    return _parseTokens(trimmed.substring(_aiPrefix.length).split(','));
  }

  /// 解码房间密码（房间串「tokens#房间名」）。
  ///
  /// 非法/空串、或误传 AI 主机密码时返回 null。
  static Room233Room? tryParseRoomPassword(String roomString) {
    final trimmed = roomString.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == _aiPrefix || trimmed.startsWith(_aiPrefix + ',')) {
      return null;
    }
    final hashIndex = trimmed.indexOf('#');
    final tokenPart =
        hashIndex >= 0 ? trimmed.substring(0, hashIndex) : trimmed;
    final roomName = hashIndex >= 0 ? trimmed.substring(hashIndex + 1) : '';
    return (rules: _parseTokens(tokenPart.split(',')), roomName: roomName);
  }

  /// 解析 token 列表为 [Room233Rules]（缺省值即单局 + MR2020 + OCG）。
  static Room233Rules _parseTokens(Iterable<String> rawTokens) {
    final tokens = rawTokens
        .map((t) => t.trim().toUpperCase())
        .where((t) => t.isNotEmpty);

    var mode = 0;
    var duelRule = 5;
    var rule = 0;
    var timeLimit = 180;
    var startLp = 8000;
    var startHand = 5;
    var drawCount = 1;
    var noCheckDeck = false;
    var noShuffleDeck = false;
    var lfTableIndex = -1;

    for (final token in tokens) {
      if (token == 'M') {
        mode = 1;
      } else if (token == 'T') {
        mode = 2;
      } else if (token == 'MR3') {
        duelRule = 3;
      } else if (token == 'MR4') {
        duelRule = 4;
      } else if (token == 'MR5') {
        duelRule = 5;
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
      } else if (token == 'NF') {
        lfTableIndex = 0;
      } else if (token.startsWith('LF')) {
        lfTableIndex = _int(token.substring(2), lfTableIndex);
      } else if (token == 'NC') {
        noCheckDeck = true;
      } else if (token == 'NS') {
        noShuffleDeck = true;
      }
      // 其余 token 静默忽略。
    }

    return (
      mode: mode,
      duelRule: duelRule,
      rule: rule,
      timeLimit: timeLimit,
      startLp: startLp,
      startHand: startHand,
      drawCount: drawCount,
      noCheckDeck: noCheckDeck,
      noShuffleDeck: noShuffleDeck,
      lfTableIndex: lfTableIndex,
    );
  }

  // ── 内部实现 ──────────────────────────────────────────────────────

  /// 生成 game-rule token 列表（按 233 解析顺序，已过滤默认项）。
  ///
  /// 禁限 token 位置固定在 DR 之后、NC/NS 之前。
  static List<String> _buildTokens(Room233Rules r) {
    return <String>[
      switch (r.mode) {
        1 => 'M',
        2 => 'T',
        _ => '',
      },
      switch (r.duelRule) {
        3 => 'MR3',
        4 => 'MR4',
        _ => 'MR5',
      },
      switch (r.rule) {
        2 => 'OT',
        1 => 'TO',
        4 => 'NU',
        _ => '',
      },
      if (r.timeLimit != 180) 'TM${r.timeLimit}',
      if (r.startLp != 8000) 'LP${r.startLp}',
      if (r.startHand != 5) 'ST${r.startHand}',
      if (r.drawCount != 1) 'DR${r.drawCount}',
      // 禁限：>0 → LFn（服务端序号），0 → NF（无禁限），-1 → 不写。
      if (r.lfTableIndex > 0) 'LF${r.lfTableIndex}',
      if (r.lfTableIndex == 0) 'NF',
      if (r.noCheckDeck) 'NC',
      if (r.noShuffleDeck) 'NS',
    ]..removeWhere((c) => c.isEmpty);
  }

  /// 按 UTF-16 长度截断，且不切断代理对（emoji 等）。
  static String _clip(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    var end = maxLength;
    if (end > 0 && _isHighSurrogate(value.codeUnitAt(end - 1))) end--;
    return value.substring(0, end);
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  static int _int(String s, int fallback) => int.tryParse(s) ?? fallback;
}
