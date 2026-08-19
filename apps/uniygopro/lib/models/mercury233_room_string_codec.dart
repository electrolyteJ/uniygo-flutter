import 'package:duelink/duelink.dart';
import 'mercury233_room_spec.dart';

class Mercury233RoomStringResult {
  final String value;
  final String? error;

  const Mercury233RoomStringResult(this.value, this.error);
}

class Mercury233RoomStringCodec {
  static const int maxLength = 20;

  static Mercury233RoomStringResult build(Mercury233RoomSpec spec) {
    final value = spec.manualRoomStringEnabled
        ? spec.manualRoomString
        : _buildStructured(spec);
    final isBlank = spec.manualRoomStringEnabled
        ? value.trim().isEmpty
        : spec.roomName.trim().isEmpty;
    return Mercury233RoomStringResult(
      value,
      _validate(value, isBlank: isBlank),
    );
  }

  /// 233 服协议参数 token 序列（模式/MR/卡池/TM/LP/ST/DR/禁限/NC/NS，
  /// 按服务器解析顺序，已过滤默认项）。
  ///
  /// 房间串与 AI 主机密码共享的唯一 token 拼装点——两侧都不得再各自
  /// 手拼 token。房间串在其后追加 `#房间名`；AI 密码在其前置 `AI`
  /// 标记且不带房间名。
  static List<String> buildTokens(Mercury233RoomSpec spec) {
    final codes = <String>[
      switch (spec.mode) {
        RoomMode.single => '',
        RoomMode.match => 'M',
        RoomMode.tag => 'T',
      },
      switch (spec.duelRule) {
        DuelRule.mr3 => 'MR3',
        DuelRule.mr4 => 'MR4',
        DuelRule.mr2020 => 'MR5',
      },
      switch (spec.cardPoolMode) {
        Mercury233CardPoolMode.ocg => '',
        Mercury233CardPoolMode.tcgAndOcg => 'OT',
        Mercury233CardPoolMode.tcgOnly => 'TO',
        Mercury233CardPoolMode.noUnique => 'NU',
      },
      if (spec.timeLimit != 180) 'TM${spec.timeLimit}',
      if (spec.startLp != 8000) 'LP${spec.startLp}',
      if (spec.startHand != 5) 'ST${spec.startHand}',
      if (spec.drawCount != 1) 'DR${spec.drawCount}',
      if (spec.banlist.token != 'LF1') spec.banlist.token,
      if (spec.noCheckDeck) 'NC',
      if (spec.noShuffleDeck) 'NS',
    ]..removeWhere((code) => code.isEmpty);
    return codes;
  }

  static String _buildStructured(Mercury233RoomSpec spec) {
    final codes = buildTokens(spec);
    final prefix = codes.isEmpty ? '' : '${codes.join(',')}#';
    return '$prefix${spec.roomName.trim()}';
  }

  static String? _validate(String value, {required bool isBlank}) {
    if (isBlank) return '房间串不能为空';
    if (value.length > maxLength) {
      return '房间串不能超过 $maxLength 个字符';
    }
    return null;
  }
}
