import 'package:duelink/duelink.dart';
import 'package:ygo_data/lf_table.dart';

enum Mercury233CardPoolMode { ocg, tcgAndOcg, tcgOnly, noUnique }

class Mercury233BanlistOption {
  final String label;
  final String token;
  final int lfTableHash;

  const Mercury233BanlistOption({
    required this.label,
    required this.token,
    required this.lfTableHash,
  });

  @override
  bool operator ==(Object other) {
    return other is Mercury233BanlistOption &&
        other.label == label &&
        other.token == token &&
        other.lfTableHash == lfTableHash;
  }

  @override
  int get hashCode => Object.hash(label, token, lfTableHash);

  Map<String, dynamic> toJson() => {
        'label': label,
        'token': token,
        'lfTableHash': lfTableHash,
      };

  factory Mercury233BanlistOption.fromJson(Map<String, dynamic> json) =>
      Mercury233BanlistOption(
        label: (json['label'] ?? '') as String,
        token: (json['token'] ?? '') as String,
        lfTableHash: (json['lfTableHash'] ?? 0) as int,
      );
}

const mercury233BanlistOptions = <Mercury233BanlistOption>[
  Mercury233BanlistOption(label: '默认禁限', token: 'LF1', lfTableHash: 0),
  Mercury233BanlistOption(label: '无禁限', token: 'NF', lfTableHash: 0),
];

List<Mercury233BanlistOption> buildMercury233BanlistOptions(
  Iterable<LfTable> tables,
) {
  final orderedTables = tables.toList();
  if (orderedTables.isEmpty) {
    return mercury233BanlistOptions;
  }

  return [
    for (var i = 0; i < orderedTables.length; i++)
      Mercury233BanlistOption(
        label: orderedTables[i].name.isEmpty
            ? '禁限卡表 ${i + 1}'
            : orderedTables[i].name,
        token: 'LF${i + 1}',
        lfTableHash: orderedTables[i].hash,
      ),
    const Mercury233BanlistOption(label: '无禁限', token: 'NF', lfTableHash: 0),
  ];
}

class Mercury233RoomSpec {
  final String roomName;
  final RoomMode mode;
  final DuelRule duelRule;
  final Mercury233BanlistOption banlist;
  final Mercury233CardPoolMode cardPoolMode;
  final int startLp;
  final int startHand;
  final int drawCount;
  final int timeLimit;
  final bool noCheckDeck;
  final bool noShuffleDeck;
  final bool manualRoomStringEnabled;
  final String manualRoomString;

  const Mercury233RoomSpec({
    this.roomName = '',
    this.mode = RoomMode.single,
    this.duelRule = DuelRule.mr2020,
    this.banlist = const Mercury233BanlistOption(
      label: '默认禁限',
      token: 'LF1',
      lfTableHash: 0,
    ),
    this.cardPoolMode = Mercury233CardPoolMode.ocg,
    this.startLp = 8000,
    this.startHand = 5,
    this.drawCount = 1,
    this.timeLimit = 180,
    this.noCheckDeck = false,
    this.noShuffleDeck = false,
    this.manualRoomStringEnabled = false,
    this.manualRoomString = '',
  });

  Mercury233RoomSpec copyWith({
    String? roomName,
    RoomMode? mode,
    DuelRule? duelRule,
    Mercury233BanlistOption? banlist,
    Mercury233CardPoolMode? cardPoolMode,
    int? startLp,
    int? startHand,
    int? drawCount,
    int? timeLimit,
    bool? noCheckDeck,
    bool? noShuffleDeck,
    bool? manualRoomStringEnabled,
    String? manualRoomString,
  }) {
    return Mercury233RoomSpec(
      roomName: roomName ?? this.roomName,
      mode: mode ?? this.mode,
      duelRule: duelRule ?? this.duelRule,
      banlist: banlist ?? this.banlist,
      cardPoolMode: cardPoolMode ?? this.cardPoolMode,
      startLp: startLp ?? this.startLp,
      startHand: startHand ?? this.startHand,
      drawCount: drawCount ?? this.drawCount,
      timeLimit: timeLimit ?? this.timeLimit,
      noCheckDeck: noCheckDeck ?? this.noCheckDeck,
      noShuffleDeck: noShuffleDeck ?? this.noShuffleDeck,
      manualRoomStringEnabled:
          manualRoomStringEnabled ?? this.manualRoomStringEnabled,
      manualRoomString: manualRoomString ?? this.manualRoomString,
    );
  }

  RoomOptions toRoomOptions() {
    return RoomOptions(
      lfTableHash: banlist.lfTableHash,
      rule: switch (cardPoolMode) {
        Mercury233CardPoolMode.ocg => 0,
        Mercury233CardPoolMode.tcgAndOcg => 2,
        Mercury233CardPoolMode.tcgOnly => 1,
        Mercury233CardPoolMode.noUnique => 4,
      },
      mode: mode,
      duelRule: duelRule,
      noCheckDeck: noCheckDeck,
      noShuffleDeck: noShuffleDeck,
      startLp: startLp,
      startHand: startHand,
      drawCount: drawCount,
      timeLimit: timeLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomName': roomName,
        'mode': mode.value,
        'duelRule': duelRule.value,
        'banlist': banlist.toJson(),
        'cardPoolMode': cardPoolMode.name,
        'startLp': startLp,
        'startHand': startHand,
        'drawCount': drawCount,
        'timeLimit': timeLimit,
        'noCheckDeck': noCheckDeck,
        'noShuffleDeck': noShuffleDeck,
        'manualRoomStringEnabled': manualRoomStringEnabled,
        'manualRoomString': manualRoomString,
      };

  factory Mercury233RoomSpec.fromJson(Map<String, dynamic> json) =>
      Mercury233RoomSpec(
        roomName: (json['roomName'] ?? '') as String,
        mode: RoomMode.of((json['mode'] ?? 0) as int),
        duelRule: DuelRule.of((json['duelRule'] ?? 5) as int),
        banlist: json['banlist'] is Map<String, dynamic>
            ? Mercury233BanlistOption.fromJson(
                json['banlist'] as Map<String, dynamic>)
            : const Mercury233BanlistOption(
                label: '默认禁限', token: 'LF1', lfTableHash: 0),
        cardPoolMode: Mercury233CardPoolMode.values.asNameMap()[
                json['cardPoolMode']] ??
            Mercury233CardPoolMode.ocg,
        startLp: (json['startLp'] ?? 8000) as int,
        startHand: (json['startHand'] ?? 5) as int,
        drawCount: (json['drawCount'] ?? 1) as int,
        timeLimit: (json['timeLimit'] ?? 180) as int,
        noCheckDeck: (json['noCheckDeck'] ?? false) as bool,
        noShuffleDeck: (json['noShuffleDeck'] ?? false) as bool,
        manualRoomStringEnabled:
            (json['manualRoomStringEnabled'] ?? false) as bool,
        manualRoomString: (json['manualRoomString'] ?? '') as String,
      );
}
