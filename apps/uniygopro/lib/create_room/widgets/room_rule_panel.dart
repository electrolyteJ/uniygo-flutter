/// 房间规则面板（好友对战 / 人机对决 / 自由房间共用）。
///
/// 名字不跟页签绑定：同一份「规则设置」在不同页签只是行数不同，
/// 由 [RoomRulePanel] 按 [showModeRow] / [showEnvRows] 组合。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import '../models/banlist_options.dart';
import '../models/mode_models.dart';

/// 房间规则值（各页签共用）。
@immutable
class RoomRuleConfig {
  const RoomRuleConfig({
    this.collapsed = false,
    this.mode = 2,
    this.env = 0,
    this.rule = 0,
    this.master = 0,
    this.lp = 1,
    this.hand = 1,
    this.draw = 0,
    this.time = 2,
    this.banlist = 0,
    this.noCheck = false,
    this.noShuffle = false,
    this.autoDeath = false,
  });

  final bool collapsed;

  /// 赛制：0=双打 2v2 / 1=三局两胜 / 2=单局。
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
}

/// 房间规则面板。
class RoomRulePanel extends StatefulWidget {
  const RoomRulePanel({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.showModeRow = false,
    this.showEnvRows = false,
    this.showAutoDeath = false,
    this.showCardRule = true,
    this.showBanlist = true,
    this.checksTop = 232,
    this.height = 276,
    this.modeOptions,
    this.envNames = const [],
    this.serverNames = const [],
  });

  final String title;
  final RoomRuleConfig value;
  final ValueChanged<RoomRuleConfig> onChanged;

  /// 是否显示「赛制」下拉（人机对决 / 自由房间）。
  final bool showModeRow;

  /// 是否显示「环境 / 服务器」两行（自由房间）。
  final bool showEnvRows;

  /// 是否显示「40 分钟自动超时」勾选（好友对战）。
  final bool showAutoDeath;

  /// 是否显示「卡片允许」行（自由房间不展示）。
  final bool showCardRule;

  /// 是否显示「禁限卡表」行（自由房间不展示）。
  final bool showBanlist;

  /// 勾选行的纵向起点（各页签行数不同，位置按设计稿给）。
  final double checksTop;

  /// 展开态高度（自由房间在下面还要放历史列表，所以更矮）。
  final double height;

  /// 赛制下拉的选项（缺省：双打 / 三局两胜 / 单局）。
  final List<String>? modeOptions;

  final List<String> envNames;
  final List<String> serverNames;

  @override
  State<RoomRulePanel> createState() => _RoomRulePanelState();
}

class _OptionRow {
  const _OptionRow(
    this.label,
    this.values,
    this.index,
    this.top,
    this.onSelected,
  );

  final String label;
  final List<String> values;
  final int index;
  final double top;
  final ValueChanged<int>? onSelected;
}

class _RoomRulePanelState extends State<RoomRulePanel> {
  static const List<String> _modes = ['双打 2v2', '三局两胜', '单局'];

  /// 当前展开的下拉行（按 label 唯一标识）；null 表示全部收起。
  String? _openLabel;
  List<BanlistOption> _banlists = BanlistCatalog.options;

  @override
  void initState() {
    super.initState();
    _loadBanlists();
  }

  Future<void> _loadBanlists() async {
    final list = await BanlistCatalog.ensureLoaded();
    if (!mounted || identical(list, _banlists)) return;
    setState(() => _banlists = list);
  }

  RoomRuleConfig get _v => widget.value;
  void _update(RoomRuleConfig v) => widget.onChanged(v);

  @override
  Widget build(BuildContext context) {
    final collapsed = _v.collapsed;
    var top = 36.0;
    final rows = <Widget>[];
    final optionRows = <_OptionRow>[];

    void addOption(
      String label,
      List<String> values,
      int index,
      ValueChanged<int>? onSelected,
    ) {
      final row = _OptionRow(label, values, index, top, onSelected);
      optionRows.add(row);
      rows.addAll(_textRow(row));
      top += 24;
    }

    if (widget.showEnvRows) {
      addOption(
        '环境',
        widget.envNames,
        _clampEnv(),
        (i) => _update(_v.copyWith(env: i)),
      );
      addOption('服务器', [widget.serverNames[_clampEnv()]], 0, null);
    }

    if (widget.showModeRow) {
      addOption(
        '赛制',
        _modeList,
        _v.mode.clamp(0, _modeList.length - 1),
        (i) => _update(_v.copyWith(mode: i)),
      );
    }

    final labels = <String>[
      if (widget.showCardRule) '卡片允许',
      '大师规则',
      '初始 LP',
      '初始手牌',
      '每回合抽卡',
      '每回合时限',
      if (widget.showBanlist) '禁限卡表',
    ];
    final values = <List<String>>[
      if (widget.showCardRule) RoomRuleOptions.cardRules,
      RoomRuleOptions.masterRules,
      RoomRuleOptions.lps,
      RoomRuleOptions.hands,
      RoomRuleOptions.draws,
      RoomRuleOptions.times,
      if (widget.showBanlist) [for (final option in _banlists) option.name],
    ];
    final indices = <int>[
      if (widget.showCardRule) _v.rule,
      _v.master,
      _v.lp,
      _v.hand,
      _v.draw,
      _v.time,
      if (widget.showBanlist) _v.banlist,
    ];
    final setters = <void Function(int)>[
      if (widget.showCardRule) (i) => _update(_v.copyWith(rule: i)),
      (i) => _update(_v.copyWith(master: i)),
      (i) => _update(_v.copyWith(lp: i)),
      (i) => _update(_v.copyWith(hand: i)),
      (i) => _update(_v.copyWith(draw: i)),
      (i) => _update(_v.copyWith(time: i)),
      if (widget.showBanlist) (i) => _update(_v.copyWith(banlist: i)),
    ];
    for (var i = 0; i < labels.length; i++) {
      addOption(labels[i], values[i], indices[i], setters[i]);
    }

    _OptionRow? openRow;
    if (!collapsed) {
      for (final row in optionRows) {
        if (row.label == _openLabel &&
            row.onSelected != null &&
            row.values.isNotEmpty) {
          openRow = row;
          break;
        }
      }
    }

    return Positioned(
      left: 644,
      top: 52,
      width: 184,
      height: collapsed ? 36 : widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080F19),
          border: Border.all(color: DuelColors.borderPanel),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            _header(collapsed),
            if (!collapsed) ...[
              Positioned(
                left: 12,
                top: 28,
                width: 160,
                child: Container(height: 1, color: DuelColors.divider),
              ),
              ...rows,
              _checkRow(
                '不检查卡组',
                12,
                widget.checksTop,
                _v.noCheck,
                (v) => _update(_v.copyWith(noCheck: v)),
              ),
              _checkRow(
                '不切洗卡组',
                96,
                widget.checksTop,
                _v.noShuffle,
                (v) => _update(_v.copyWith(noShuffle: v)),
              ),
              if (widget.showAutoDeath)
                _checkRow(
                  '40 分钟自动超时',
                  12,
                  widget.checksTop + 24,
                  _v.autoDeath,
                  (v) => _update(_v.copyWith(autoDeath: v)),
                ),
              if (openRow != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _openLabel = null),
                  ),
                ),
                _optionsOverlay(openRow),
              ],
            ],
          ],
        ),
      ),
    );
  }

  int _clampEnv() =>
      _v.env.clamp(0, widget.envNames.isEmpty ? 0 : widget.envNames.length - 1);

  Widget _header(bool collapsed) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: Text(widget.title, style: DuelType.sans(11, height: 1.2)),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: DuelHit(
            onTap: () {
              _openLabel = null;
              _update(_v.copyWith(collapsed: !collapsed));
            },
            child: Text(
              collapsed ? '展开 ›' : '收起 ›',
              style: DuelType.sans(8, color: DuelColors.textGhost),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _textRow(_OptionRow row) {
    final selectable = row.onSelected != null && row.values.isNotEmpty;
    final safeIndex = row.values.isEmpty
        ? 0
        : row.index.clamp(0, row.values.length - 1);
    return [
      Positioned(
        left: 12,
        top: row.top + 6,
        child: Text(
          row.label,
          style: DuelType.sans(8, color: DuelColors.textFaint),
        ),
      ),
      Positioned(
        left: 72,
        top: row.top,
        width: 100,
        height: 22,
        child: DuelHit(
          onTap: selectable
              ? () {
                  DuelSounds.tabSwitch();
                  setState(() {
                    _openLabel = _openLabel == row.label ? null : row.label;
                  });
                }
              : null,
          child: _valueBox(
            row.values.isEmpty ? '加载中…' : row.values[safeIndex],
            arrow: selectable,
          ),
        ),
      ),
    ];
  }

  List<String> get _modeList => widget.modeOptions ?? _modes;

  /// 展开的下拉多选：沿用赛制原来的 100×20 紧凑列表样式。
  Widget _optionsOverlay(_OptionRow row) {
    const itemHeight = 20.0;
    final maxHeight = widget.height - 8;
    final fullHeight = row.values.length * itemHeight + 2;
    final listHeight = fullHeight > maxHeight ? maxHeight : fullHeight;
    var listTop = row.top + 22;
    if (listTop + listHeight > widget.height - 4) {
      listTop = row.top - listHeight;
    }
    if (listTop < 4) listTop = 4;
    final maxTop = widget.height - listHeight - 4;
    if (maxTop >= 4 && listTop > maxTop) listTop = maxTop;

    final selected = row.index.clamp(0, row.values.length - 1);
    return Positioned(
      left: 72,
      top: listTop,
      width: 100,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1723),
          border: Border.all(color: DuelColors.accent),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < row.values.length; i++)
                DuelHit(
                  key: ValueKey('rule-option-${row.label}-$i'),
                  onTap: () {
                    DuelSounds.tabSwitch();
                    setState(() => _openLabel = null);
                    row.onSelected!(i);
                  },
                  child: Container(
                    height: itemHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    color: i == selected
                        ? DuelColors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.values[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DuelType.sans(
                              8.5,
                              color: i == selected
                                  ? DuelColors.accent
                                  : DuelColors.textPrimary,
                            ),
                          ),
                        ),
                        if (i == selected)
                          Text(
                            '✓',
                            style: DuelType.sans(8, color: DuelColors.accent),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueBox(String text, {bool arrow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A121C),
        border: Border.all(color: DuelColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 5,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DuelType.sans(8.5, color: DuelColors.textPrimary),
            ),
          ),
          if (arrow)
            Positioned(
              right: 6,
              top: 5,
              child: Text(
                '▾',
                style: DuelType.latin(7, color: DuelColors.textGhost),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checkRow(
    String label,
    double left,
    double top,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: DuelHit(
        onTap: () {
          DuelSounds.tabSwitch();
          onChanged(!value);
        },
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: value ? DuelColors.accent : Colors.transparent,
                border: Border.all(
                  color: value ? DuelColors.accent : const Color(0xFF3A4A5E),
                ),
              ),
              alignment: Alignment.center,
              child: value
                  ? const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 7,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: DuelColors.inkOnAccent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 5),
            Text(label, style: DuelType.sans(7.5, color: DuelColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
