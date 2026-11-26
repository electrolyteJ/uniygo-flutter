import 'dart:convert';

import 'package:duelink/duelink.dart';

import '../../config/servers.dart';
import '../models/banlist_options.dart';
import '../models/mode_models.dart';
import '../models/room_rule_config.dart';

/// 创建房间历史记录。
///
/// 统一形态：规则参数存 [config]（UI 层 [RoomRuleConfig]），进房凭证存 [password]——
/// - mycard 私密房：[password] 是私密房 ID（房主 external_id 派生，恒定），
///   仅用于展示/分享，回填时不参与编码（u16Secret 每次都要重新取）；
/// - mercury233：房间串（token#房名）本身就是进房凭证，整串存 [password]；
/// - koishi / 408：普通房间密码或随机邀码。
///
/// 旧版本把规则存成 RoomOptions 的 options 对象；读取旧 JSON 时会自动
/// 折算成 [RoomRuleConfig]（见 [_configFromLegacyOptions]）。
class CreatedRoomRecord {
  final DuelEnvironment env;
  final String roomName;
  final String password;
  final RoomRuleConfig? config;
  final DateTime createdAt;

  CreatedRoomRecord({
    required this.env,
    required this.roomName,
    this.password = '',
    this.config,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 列表展示标题。
  String get title {
    if (roomName.isNotEmpty) return roomName;
    return password.isNotEmpty ? password : '未命名房间';
  }

  /// 列表展示摘要（规则参数）。
  String get summary {
    final c = config;
    if (c == null) return env.displayName;
    final mode = switch (c.mode) {
      0 => '单局',
      1 => 'Match',
      2 => '双打',
      _ => '',
    };
    final lp = _option(RoomRuleOptions.lps, c.lp, '8000');
    final hand = _option(RoomRuleOptions.hands, c.hand, '5');
    return mode + ' · LP' + lp + ' · 手牌' + hand;
  }

  /// 去重/删除用的稳定标识（不含创建时间）。
  String get identity => jsonEncode(toJson()..remove('createdAt'));

  /// 复制一份并将创建时间更新为现在（重新进入房间时置顶用）。
  CreatedRoomRecord touch() => CreatedRoomRecord(
        env: env,
        roomName: roomName,
        password: password,
        config: config,
      );

  Map<String, dynamic> toJson() => {
        'env': env.name,
        'roomName': roomName,
        'password': password,
        if (config != null) 'config': config!.toJson(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory CreatedRoomRecord.fromJson(Map<String, dynamic> json) {
    final configJson = json['config'];
    final legacyOptions = json['options'];
    return CreatedRoomRecord(
      env: DuelEnvironment.values.asNameMap()[json['env']] ??
          DuelEnvironment.koishi,
      roomName: (json['roomName'] ?? '') as String,
      password: (json['password'] ?? '') as String,
      config: configJson is Map<String, dynamic>
          ? RoomRuleConfig.fromJson(configJson)
          : legacyOptions is Map<String, dynamic>
              ? _configFromLegacyOptions(legacyOptions)
              : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] ?? 0) as int,
      ),
    );
  }

  static String _option(List<String> values, int index, String fallback) =>
      index >= 0 && index < values.length ? values[index] : fallback;

  static int _indexOf(List<String> values, String value, int fallback) {
    final i = values.indexOf(value);
    return i >= 0 ? i : fallback;
  }

  static int _timeIndexOf(int seconds) {
    final text = seconds.toString();
    final i = RoomRuleOptions.times
        .indexWhere((t) => t.replaceAll(' 秒', '') == text);
    return i >= 0 ? i : 2;
  }

  static int _banlistIndexOf(int hash) {
    final i = BanlistCatalog.options.indexWhere((o) => o.hash == hash);
    return i >= 0 ? i : 0;
  }

  /// 旧版 options（RoomOptions 字段）→ [RoomRuleConfig]。
  static RoomRuleConfig _configFromLegacyOptions(Map<String, dynamic> o) {
    // 旧 RoomMode 与 RoomRuleConfig.mode 同序：0=单局 / 1=三局两胜 / 2=双打。
    final mode = (o['mode'] ?? 1) as int;
    final duelRule = (o['duelRule'] ?? 5) as int;
    final lfTableHash = (o['lfTableHash'] ?? 0) as int;
    return RoomRuleConfig(
      mode: mode,
      rule: (o['rule'] ?? 0) as int,
      master: duelRule == 4 ? 1 : 0,
      lp: _indexOf(
        RoomRuleOptions.lps,
        ((o['startLp'] ?? 8000) as int).toString(),
        1,
      ),
      hand: _indexOf(
        RoomRuleOptions.hands,
        ((o['startHand'] ?? 5) as int).toString(),
        1,
      ),
      draw: _indexOf(
        RoomRuleOptions.draws,
        ((o['drawCount'] ?? 1) as int).toString(),
        0,
      ),
      time: _timeIndexOf((o['timeLimit'] ?? 180) as int),
      banlist: _banlistIndexOf(lfTableHash),
      noCheck: (o['noCheckDeck'] ?? false) as bool,
      noShuffle: (o['noShuffleDeck'] ?? false) as bool,
    );
  }
}
