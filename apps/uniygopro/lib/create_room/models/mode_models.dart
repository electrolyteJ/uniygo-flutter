/// 建房（03a 匹配 / 03b 好友对战 / 03c 练习 / 03f 自由房间）的数据模型。
///
/// 设计稿：Ardot 744179416852082 页面「03 主页大厅」。
/// 列表行与右侧预览面板的文案一一对应；动作仍接到既有 create_room 面板。
library;

import 'package:flutter/foundation.dart';

import '../../config/servers.dart';

/// 一个模式要执行的动作。
enum DuelModeAction {
  matchAthletic,
  matchEntertain,
  friendRoom,
  aiDuel,
  puzzle,
  tutorial,
  freeRoom,
}

/// 预览面板里的一行键值。
class ModeDetailRow {
  const ModeDetailRow(this.label, this.value);

  final String label;
  final String value;
}

/// 列表中的一个模式。
class DuelModeEntry {
  const DuelModeEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.rightText,
    required this.action,
    required this.detailTitle,
    required this.detailSubtitle,
    required this.rows,
    required this.note,
    this.badge,
    this.enabled = true,
    this.environment,
    this.barSubtitle,
    this.configSubtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 行尾的注释（在线人数 / BO3 / 默认 / 可建房…）。
  final String rightText;

  /// 行尾的小徽标（需登录）。
  final String? badge;

  final DuelModeAction action;

  final String detailTitle;
  final String detailSubtitle;
  final List<ModeDetailRow> rows;
  final String note;

  /// 是否可用；false 时仍展示，但点击给「暂未开放」提示。
  final bool enabled;

  /// 自由房间环境（仅 freeRoom 动作使用）。
  final DuelEnvironment? environment;

  /// 主页匹配条副行（缺省用 [subtitle]）。
  final String? barSubtitle;

  String get barText => barSubtitle ?? subtitle;

  /// 配置面板副题。
  final String? configSubtitle;

  String get formSubtitle => configSubtitle ?? detailSubtitle;

  String get actionLabel => action == DuelModeAction.freeRoom ? '进入房间' : '开始匹配';
}

/// 一个页签及其模式列表。
class DuelModeTab {
  const DuelModeTab({
    required this.id,
    required this.label,
    required this.entries,
    this.defaultIndex = 0,
  });

  final String id;
  final String label;
  final List<DuelModeEntry> entries;
  final int defaultIndex;

  DuelModeEntry get defaultEntry => entries[defaultIndex];
}

/// 建房页模式目录（文案取自设计稿）。
abstract final class DuelModes {
  static const List<DuelModeEntry> matchEntries = [
    DuelModeEntry(
      id: 'athletic',
      title: '竞技匹配',
      subtitle: '三局两胜 · 均 12s',
      barSubtitle: '三局两胜 · 12s',
      rightText: '3,214 在线',
      action: DuelModeAction.matchAthletic,
      detailTitle: '竞技匹配',
      detailSubtitle: '自动撮合 · 天梯排名 · 三局两胜 BO3',
      configSubtitle: '自动撮合 · 天梯排名',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:8912'),
        ModeDetailRow('赛制', '三局两胜（BO3）'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '匹配成功后进入决斗，胜场计入天梯排名与 DP',
    ),
    DuelModeEntry(
      id: 'casual',
      title: '娱乐匹配',
      subtitle: '单局 · 无排名',
      rightText: '1,102 在线',
      action: DuelModeAction.matchEntertain,
      detailTitle: '娱乐匹配',
      detailSubtitle: '自动撮合 · 休闲不计排名 · 单局',
      configSubtitle: '自动撮合 · 无排名',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:7912'),
        ModeDetailRow('赛制', '单局'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '不计 DP；适合练牌与试卡组',
    ),
  ];

  static const List<DuelModeEntry> friendEntries = [
    DuelModeEntry(
      id: 'friend-tag',
      title: '双打 2v2',
      subtitle: '双人组队 · 4 人一桌',
      rightText: '4 人',
      badge: '需登录',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.mercury233,
      detailTitle: '双打 2v2',
      detailSubtitle: '好友房 · 邀请码加入 · 2v2',
      configSubtitle: '邀请码加入 · 房主设规则',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:7912'),
        ModeDetailRow('赛制', 'RoomMode.tag（2v2）'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '4 人一桌，队友与对手由房主邀请；不计 DP',
    ),
    DuelModeEntry(
      id: 'friend-match',
      title: '三局两胜',
      subtitle: 'BO3 · 房主设规则',
      rightText: 'BO3',
      badge: '需登录',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.mercury233,
      detailTitle: '三局两胜',
      detailSubtitle: '好友房 · 邀请码加入 · BO3',
      configSubtitle: '邀请码加入 · 房主设规则',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:7912'),
        ModeDetailRow('赛制', 'RoomMode.match（BO3）'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '房主可设初始 LP / 手牌 / 回合时限；不计 DP',
    ),
    DuelModeEntry(
      id: 'friend-single',
      title: '单局',
      subtitle: '一局定胜负',
      rightText: '1 局',
      badge: '需登录',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.mercury233,
      detailTitle: '单局',
      detailSubtitle: '好友房 · 邀请码加入 · 单局',
      configSubtitle: '邀请码加入 · 房主设规则',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:7912'),
        ModeDetailRow('赛制', 'RoomMode.single（单局）'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '房主可设初始 LP / 手牌 / 回合时限；不计 DP',
    ),
    DuelModeEntry(
      id: 'friend-408',
      title: '408 环境',
      subtitle: '特殊规则 · 创建房间',
      rightText: '特殊',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.env408,
      detailTitle: '408 环境',
      detailSubtitle: '408 特殊规则 · 创建房间',
      configSubtitle: '邀请码加入 · 房主设规则',
      rows: [
        ModeDetailRow('服务器', 'koishi.momobako.com:1408'),
        ModeDetailRow('建房', '只允许加入'),
        ModeDetailRow('登录', '游客可加入'),
      ],
      note: '408 特殊规则环境，仅可加入公共房',
    ),
  ];

  static const List<DuelModeEntry> practiceEntries = [
    DuelModeEntry(
      id: 'practice-ai',
      title: '人机对决',
      subtitle: '本地人机 · 无需联网',
      rightText: '游客可用',
      action: DuelModeAction.aiDuel,
      detailTitle: '人机对决',
      detailSubtitle: '本地 ocgcore 引擎 · 无需联网',
      configSubtitle: '与本地 AI 进行单局对战，无需联网',
      rows: [
        ModeDetailRow('运行环境', 'localhost（本地引擎）'),
        ModeDetailRow('对手', '规则 AI / 端侧模型 / 远端'),
        ModeDetailRow('登录', '游客可用'),
      ],
      note: '对局不计 DP；残局无需卡组，直接加载预设局面',
    ),
    DuelModeEntry(
      id: 'practice-puzzle',
      title: '残局挑战',
      subtitle: '固定局面 · 一回合',
      rightText: '42 道题库',
      action: DuelModeAction.puzzle,
      detailTitle: '残局挑战',
      detailSubtitle: '预设残局 · 固定手牌 · 一回合解场',
      configSubtitle: '固定局面 · 一回合解场',
      rows: [
        ModeDetailRow('运行环境', 'localhost（残局脚本）'),
        ModeDetailRow('题库', '42 道'),
        ModeDetailRow('登录', '游客可用'),
      ],
      note: '无需卡组；按题库加载固定局面，达成胜利条件即通关',
    ),
    DuelModeEntry(
      id: 'practice-tutorial',
      title: '新手引导',
      subtitle: '教学关卡 · 开发中',
      rightText: '待完善',
      enabled: false,
      action: DuelModeAction.tutorial,
      detailTitle: '新手引导',
      detailSubtitle: '交互式教学 · 分步提示',
      configSubtitle: '教学关卡 · 开发中',
      rows: [
        ModeDetailRow('运行环境', 'localhost'),
        ModeDetailRow('章节', '6 章（规划）'),
        ModeDetailRow('登录', '游客可用'),
      ],
      note: '开发中：交互式教学与提示系统',
    ),
  ];

  static const List<DuelModeEntry> freeEntries = [
    DuelModeEntry(
      id: 'free-koishi',
      title: 'Koishi 通用环境',
      subtitle: '加入公共房 · 无需登录',
      rightText: '默认',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.koishi,
      detailTitle: '自由房间',
      detailSubtitle: '加入公共房 / 自建房间 · 共 8 个环境',
      configSubtitle: '选择环境后加入或自建房间',
      rows: [
        ModeDetailRow('默认环境', 'koishi.momobako.com:7211'),
        ModeDetailRow('可建房', 'mycard · mercury233'),
        ModeDetailRow('登录', '游客可加入公共房'),
      ],
      note: '房间参数走 RoomOptions：赛制 / 初始 LP / 手牌 / 回合时限',
    ),
    DuelModeEntry(
      id: 'free-mycard',
      title: 'mycard 环境',
      subtitle: '可建房 · 需 MyCard',
      rightText: '',
      badge: '需登录',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.mycard,
      detailTitle: 'mycard 环境',
      detailSubtitle: '自建房间 · 需 MyCard 登录',
      configSubtitle: '选择环境后加入或自建房间',
      rows: [
        ModeDetailRow('服务器', 'tiramisu.moenext.com:7912'),
        ModeDetailRow('建房', '可自建房间'),
        ModeDetailRow('登录', '需要 MyCard'),
      ],
      note: '房间参数走 RoomOptions，建房后把房间号/密码发给好友',
    ),
    DuelModeEntry(
      id: 'free-mercury233',
      title: 'mercury233 环境',
      subtitle: '可建房 · TCP 协议',
      rightText: '可建房',
      action: DuelModeAction.freeRoom,
      environment: DuelEnvironment.mercury233,
      detailTitle: 'mercury233 环境',
      detailSubtitle: '房间字符串 DSL · 裸 TCP',
      configSubtitle: '选择环境后加入或自建房间',
      rows: [
        ModeDetailRow('服务器', 's1.ygo233.com:233'),
        ModeDetailRow('建房', '可自建房间（房间串）'),
        ModeDetailRow('登录', '游客可加入'),
      ],
      note: '使用 mercury233 房间字符串 DSL；建房会把参数编码进房间串',
    ),
  ];

  static const List<DuelModeTab> tabs = [
    DuelModeTab(id: 'match', label: '匹配', entries: matchEntries),
    DuelModeTab(
      id: 'friend',
      label: '好友对战',
      entries: friendEntries,
      defaultIndex: 1,
    ),
    DuelModeTab(id: 'practice', label: '练习', entries: practiceEntries),
    DuelModeTab(id: 'free', label: '自由房间', entries: freeEntries),
  ];
}

/// 主页匹配条与建房页共享的「当前模式」。
class ModeSelection extends ChangeNotifier {
  ModeSelection._();

  static final ModeSelection instance = ModeSelection._();

  DuelModeEntry _current = DuelModes.matchEntries.first;

  DuelModeEntry get current => _current;

  void select(DuelModeEntry mode) {
    if (identical(_current, mode)) return;
    _current = mode;
    notifyListeners();
  }
}

/// 规则面板共用的选项表（设计稿取值；面板与逻辑共用同一份）。
abstract final class RoomRuleOptions {
  static const List<String> cardRules = [
    'OCG',
    'TCG',
    'OT 混',
    '自制卡',
    '专有卡禁止',
    '所有卡片',
  ];

  static const List<String> masterRules = ['MR 2020', 'MR 2019', '新大师规则'];
  static const List<String> lps = ['4000', '8000', '12000'];
  static const List<String> hands = ['4', '5', '6'];
  static const List<String> draws = ['1', '2', '3'];
  static const List<String> times = ['60 秒', '120 秒', '180 秒', '无限制'];
  static const List<String> banlists = ['默认'];

  static const List<String> freeEnvNames = ['Koishi', 'mycard', 'mercury233'];
  static const List<String> freeServers = [
    'momobako:7211',
    'moenext:7912',
    'ygo233:233',
  ];
}
