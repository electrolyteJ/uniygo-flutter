import 'package:duelink/duelink.dart';
import 'package:ygo_data/lf_table.dart';

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

  /// 公共房间参数（对战模式/大师规则/卡片允许/LP/手牌/抽卡/时间/卡组检查），
  /// 唯一数据源是 [RoomOptions]，本类只做只读转发，不再重复声明这 9 个字段。
  final RoomOptions options;

  final Mercury233BanlistOption banlist;
  final bool manualRoomStringEnabled;
  final String manualRoomString;

  const Mercury233RoomSpec({
    this.roomName = '',
    this.options = const RoomOptions(mode: RoomMode.single),
    this.banlist = const Mercury233BanlistOption(
      label: '默认禁限',
      token: 'LF1',
      lfTableHash: 0,
    ),
    this.manualRoomStringEnabled = false,
    this.manualRoomString = '',
  });

  // ── 公共参数只读转发（保持 spec.mode / spec.rule 等既有访问方式不变）──
  RoomMode get mode => options.mode;
  DuelRule get duelRule => options.duelRule;
  int get rule => options.rule;
  int get startLp => options.startLp;
  int get startHand => options.startHand;
  int get drawCount => options.drawCount;
  int get timeLimit => options.timeLimit;
  bool get noCheckDeck => options.noCheckDeck;
  bool get noShuffleDeck => options.noShuffleDeck;

  /// 禁限 token（LF1 为默认禁限，省略；其余如 LF2/NF 参与房间串/AI 密码）。
  String get banlistToken => banlist.token != 'LF1' ? banlist.token : '';

  Mercury233RoomSpec copyWith({
    String? roomName,
    RoomOptions? options,
    Mercury233BanlistOption? banlist,
    bool? manualRoomStringEnabled,
    String? manualRoomString,
  }) {
    return Mercury233RoomSpec(
      roomName: roomName ?? this.roomName,
      options: options ?? this.options,
      banlist: banlist ?? this.banlist,
      manualRoomStringEnabled:
          manualRoomStringEnabled ?? this.manualRoomStringEnabled,
      manualRoomString: manualRoomString ?? this.manualRoomString,
    );
  }

  /// 协议层 [RoomOptions]（lfTableHash 由 banlist 派生）。
  RoomOptions toRoomOptions() => options.copyWith(lflist: banlist.lfTableHash);

  /// 用 [RoomOptions] 覆盖公共参数（保留 roomName / banlist / manual 字段）。
  Mercury233RoomSpec applyRoomOptions(RoomOptions o) => copyWith(options: o);

  /// 从 JSON 读取 rule：新记录用 int rule，旧记录兼容 cardPoolMode 枚举名。
  static int _ruleFromJson(Map<String, dynamic> json) {
    final rule = json['rule'];
    if (rule is int) return rule;
    switch (json['cardPoolMode']) {
      case 'tcgAndOcg':
        return 2;
      case 'tcgOnly':
        return 1;
      case 'noUnique':
        return 4;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'roomName': roomName,
        'mode': mode.value,
        'duelRule': duelRule.value,
        'banlist': banlist.toJson(),
        'rule': rule,
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
        options: RoomOptions(
          mode: RoomMode.of((json['mode'] ?? 0) as int),
          duelRule: DuelRule.of((json['duelRule'] ?? 5) as int),
          rule: _ruleFromJson(json),
          startLp: (json['startLp'] ?? 8000) as int,
          startHand: (json['startHand'] ?? 5) as int,
          drawCount: (json['drawCount'] ?? 1) as int,
          timeLimit: (json['timeLimit'] ?? 180) as int,
          noCheckDeck: (json['noCheckDeck'] ?? false) as bool,
          noShuffleDeck: (json['noShuffleDeck'] ?? false) as bool,
        ),
        banlist: json['banlist'] is Map<String, dynamic>
            ? Mercury233BanlistOption.fromJson(
                json['banlist'] as Map<String, dynamic>)
            : const Mercury233BanlistOption(
                label: '默认禁限', token: 'LF1', lfTableHash: 0),
        manualRoomStringEnabled:
            (json['manualRoomStringEnabled'] ?? false) as bool,
        manualRoomString: (json['manualRoomString'] ?? '') as String,
      );
}
