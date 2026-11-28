import 'package:flutter/foundation.dart';

/// 房间规则值（建房/好友对战/人机/自由房间各页签共用）。
///
/// 纯数据模型：字段都是 UI 下拉的索引或开关；与协议层 RoomOptions 解耦，
/// 由各 launch 逻辑按需转换成协议字段。
@immutable
class RoomRuleConfig {
  const RoomRuleConfig({
    this.collapsed = false,
    this.mode = 0,
    this.env = 0,
    this.rule = 0,
    this.master = 0,
    this.lp = 8000,
    this.hand = 5,
    this.draw = 1,
    this.time = 180,
    this.banlist = 0,
    this.noCheck = false,
    this.noShuffle = false,
    this.autoDeath = false,
  });

  final bool collapsed;

  /// 赛制：0=单局 / 1=三局两胜 / 2=双打 2v2（与协议 RoomMode 顺序一致）。
  final int mode;

  /// 自由房间环境序号（0=Koishi / 1=mycard / 2=mercury233）。
  final int env;

  final int rule;
  final int master;
  final int lp;
  final int hand;
  final int draw;
  final int time;
  final int banlist;

  final bool noCheck;
  final bool noShuffle;
  final bool autoDeath;

  // ── 协议数值（编解码用）────────────────────────────────────────

  /// 大师规则：1=MR4，其它=MR2020。
  int get duelRuleValue => master == 1 ? 4 : 5;

  /// 初始 LP（直接存数值）。
  int get startLpValue => lp;

  /// 初始手牌。
  int get startHandValue => hand;

  /// 每回合抽卡数。
  int get drawCountValue => draw;

  /// 每回合时限（秒）；0 表示无限制。
  int get timeLimitValue => time;

  RoomRuleConfig copyWith({
    bool? collapsed,
    int? mode,
    int? env,
    int? rule,
    int? master,
    int? lp,
    int? hand,
    int? draw,
    int? time,
    int? banlist,
    bool? noCheck,
    bool? noShuffle,
    bool? autoDeath,
  }) {
    return RoomRuleConfig(
      collapsed: collapsed ?? this.collapsed,
      mode: mode ?? this.mode,
      env: env ?? this.env,
      rule: rule ?? this.rule,
      master: master ?? this.master,
      lp: lp ?? this.lp,
      hand: hand ?? this.hand,
      draw: draw ?? this.draw,
      time: time ?? this.time,
      banlist: banlist ?? this.banlist,
      noCheck: noCheck ?? this.noCheck,
      noShuffle: noShuffle ?? this.noShuffle,
      autoDeath: autoDeath ?? this.autoDeath,
    );
  }

  /// 持久化用（不含 [collapsed] 这类纯 UI 状态）。
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'env': env,
        'rule': rule,
        'master': master,
        'lp': lp,
        'hand': hand,
        'draw': draw,
        'time': time,
        'banlist': banlist,
        'noCheck': noCheck,
        'noShuffle': noShuffle,
        'autoDeath': autoDeath,
      };

  factory RoomRuleConfig.fromJson(Map<String, dynamic> json) => RoomRuleConfig(
        mode: (json['mode'] ?? 0) as int,
        env: (json['env'] ?? 0) as int,
        rule: (json['rule'] ?? 0) as int,
        master: (json['master'] ?? 0) as int,
        lp: (json['lp'] ?? 1) as int,
        hand: (json['hand'] ?? 1) as int,
        draw: (json['draw'] ?? 0) as int,
        time: (json['time'] ?? 2) as int,
        banlist: (json['banlist'] ?? 0) as int,
        noCheck: (json['noCheck'] ?? false) as bool,
        noShuffle: (json['noShuffle'] ?? false) as bool,
        autoDeath: (json['autoDeath'] ?? false) as bool,
      );
}
