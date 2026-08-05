import 'package:duelink/duelink.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_spec.dart';

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

  static String _buildStructured(Mercury233RoomSpec spec) {
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
