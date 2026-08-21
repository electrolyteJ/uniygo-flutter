import 'dart:convert';

import 'package:duelink/duelink.dart';

import '../config/servers.dart';
import 'mercury233_room_spec.dart';

/// 创建房间历史记录。
///
/// 标准环境记录 [password] + [options]；mercury233 房间串 DSL 环境记录
/// [mercurySpec]（密码为空）。
///
/// 注意：mycard 私密房的 [password] 字段语义为**私密房 ID**（由房主
/// external_id 派生，同一用户恒定），用于展示/分享给朋友；历史回填时
/// 不参与编码（u16Secret 时间轮换，须重新获取），房间名称仅作本地标记。
class CreatedRoomRecord {
  final DuelEnvironment env;
  final String roomName;
  final String password;
  final RoomOptions? options;
  final Mercury233RoomSpec? mercurySpec;
  final DateTime createdAt;

  CreatedRoomRecord({
    required this.env,
    required this.roomName,
    this.password = '',
    this.options,
    this.mercurySpec,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 列表展示标题。
  String get title {
    if (roomName.isNotEmpty) return roomName;
    if (mercurySpec != null && mercurySpec!.roomName.isNotEmpty) {
      return mercurySpec!.roomName;
    }
    return password.isNotEmpty ? password : '未命名房间';
  }

  /// 列表展示摘要（规则参数）。
  String get summary {
    final o = options ?? mercurySpec?.toRoomOptions();
    if (o == null) return env.displayName;
    final mode = switch (o.mode) {
      RoomMode.single => '单局',
      RoomMode.match => 'Match',
      RoomMode.tag => '双打',
    };
    return '$mode · LP${o.startLp} · 手牌${o.startHand}';
  }

  /// 去重/删除用的稳定标识（不含创建时间）。
  String get identity => jsonEncode(toJson()..remove('createdAt'));

  /// 复制一份并将创建时间更新为现在（重新进入房间时置顶用）。
  CreatedRoomRecord touch() => CreatedRoomRecord(
        env: env,
        roomName: roomName,
        password: password,
        options: options,
        mercurySpec: mercurySpec,
      );

  Map<String, dynamic> toJson() => {
        'env': env.name,
        'roomName': roomName,
        'password': password,
        if (options != null) 'options': _optionsToJson(options!),
        if (mercurySpec != null) 'mercurySpec': mercurySpec!.toJson(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory CreatedRoomRecord.fromJson(Map<String, dynamic> json) {
    return CreatedRoomRecord(
      env: DuelEnvironment.values.asNameMap()[json['env']] ??
          DuelEnvironment.koishi,
      roomName: (json['roomName'] ?? '') as String,
      password: (json['password'] ?? '') as String,
      options: json['options'] is Map<String, dynamic>
          ? _optionsFromJson(json['options'] as Map<String, dynamic>)
          : null,
      mercurySpec: json['mercurySpec'] is Map<String, dynamic>
          ? Mercury233RoomSpec.fromJson(
              json['mercurySpec'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] ?? 0) as int),
    );
  }

  static Map<String, dynamic> _optionsToJson(RoomOptions o) => {
        'lfTableHash': o.lfTableHash,
        'rule': o.rule,
        'mode': o.mode.value,
        'duelRule': o.duelRule.value,
        'noCheckDeck': o.noCheckDeck,
        'noShuffleDeck': o.noShuffleDeck,
        'startLp': o.startLp,
        'startHand': o.startHand,
        'drawCount': o.drawCount,
        'timeLimit': o.timeLimit,
      };

  static RoomOptions _optionsFromJson(Map<String, dynamic> json) => RoomOptions(
        lfTableHash: (json['lfTableHash'] ?? 0) as int,
        rule: (json['rule'] ?? 0) as int,
        mode: RoomMode.of((json['mode'] ?? 0) as int),
        duelRule: DuelRule.of((json['duelRule'] ?? 5) as int),
        noCheckDeck: (json['noCheckDeck'] ?? false) as bool,
        noShuffleDeck: (json['noShuffleDeck'] ?? false) as bool,
        startLp: (json['startLp'] ?? 8000) as int,
        startHand: (json['startHand'] ?? 5) as int,
        drawCount: (json['drawCount'] ?? 1) as int,
        timeLimit: (json['timeLimit'] ?? 180) as int,
      );
}
