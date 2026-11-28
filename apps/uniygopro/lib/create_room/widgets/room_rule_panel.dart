/// 房间规则面板（好友对战 / 人机对决 / 自由房间共用）。
///
/// 面板只负责渲染通用条目：下拉行由 [RuleRowSpec] 描述，勾选项由
/// [RuleCheckSpec] 描述。具体展示哪些条目由调用方决定，便于各页签扩展。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import '../models/rule_row_spec.dart';

export '../models/rule_row_spec.dart';
export '../models/room_rule_config.dart';

class RoomRulePanel extends StatefulWidget {
  const RoomRulePanel({
    super.key,
    required this.title,
    required this.rows,
    this.checks = const [],
    this.collapsed = false,
    this.checksTop = 232,
    this.height = 276,
    this.onToggleCollapsed,
    this.note,
    this.left = 644,
    this.top = 52,
    this.width = 184,
  });

  final String title;
  final List<RuleRowSpec> rows;
  final List<RuleCheckSpec> checks;
  final bool collapsed;
  final double checksTop;
  final double height;
  final VoidCallback? onToggleCollapsed;

  /// 面板底部说明（如「规则由环境锁定 · 不可修改」）；为空时不占行。
  final String? note;

  final double left;
  final double top;
  final double width;

  @override
  State<RoomRulePanel> createState() => _RoomRulePanelState();
}

class _RuleRow {
  const _RuleRow(this.spec, this.top);

  final RuleRowSpec spec;
  final double top;
}

class _RoomRulePanelState extends State<RoomRulePanel> {
  String? _openKey;

  @override
  Widget build(BuildContext context) {
    // 没有折叠回调就不显示「收起/展开」。
    final collapsible = widget.onToggleCollapsed != null;
    final collapsed = widget.collapsed && collapsible;
    var top = 36.0;
    final rows = <Widget>[];
    final optionRows = <_RuleRow>[];
    for (final spec in widget.rows) {
      final row = _RuleRow(spec, top);
      optionRows.add(row);
      rows.addAll(_textRow(row));
      top += 24;
    }

    _RuleRow? openRow;
    if (!collapsed) {
      for (final row in optionRows) {
        if (row.spec.key == _openKey &&
            row.spec.onSelected != null &&
            row.spec.options.isNotEmpty) {
          openRow = row;
          break;
        }
      }
    }

    final checks = <Widget>[];
    for (var i = 0; i < widget.checks.length; i++) {
      final line = i ~/ 2;
      checks.add(
        _checkRow(
          widget.checks[i],
          i.isEven ? 12 : 96,
          widget.checksTop + line * 18,
        ),
      );
    }

    return Positioned(
      left: widget.left,
      top: widget.top,
      width: widget.width,
      height: collapsed ? 36 : widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080F19),
          border: Border.all(color: DuelColors.borderPanel),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            _header(collapsed, collapsible),
            if (!collapsed) ...[
              Positioned(
                left: 12,
                top: 28,
                width: 160,
                child: Container(height: 1, color: DuelColors.divider),
              ),
              ...rows,
              ...checks,
              if (widget.note != null)
                Positioned(
                  left: 12,
                  top: 36 + widget.rows.length * 24 + 4,
                  width: widget.width - 24,
                  child: Text(
                    widget.note!,
                    style: DuelType.sans(7.5, color: DuelColors.textGhost),
                  ),
                ),
              if (openRow != null) _optionsOverlay(openRow),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(bool collapsed, bool collapsible) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: Text(widget.title, style: DuelType.sans(11, height: 1.2)),
        ),
        if (collapsible)
          Positioned(
          right: 12,
          top: 12,
          child: DuelHit(
            onTap: () {
              _openKey = null;
              widget.onToggleCollapsed?.call();
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

  List<Widget> _textRow(_RuleRow row) {
    final spec = row.spec;
    final selectable = spec.onSelected != null && spec.options.isNotEmpty;
    final safeIndex = spec.options.isEmpty
        ? 0
        : spec.selected.clamp(0, spec.options.length - 1);
    return [
      Positioned(
        left: 12,
        top: row.top + 6,
        child: Text(
          spec.label,
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
                    _openKey = _openKey == spec.key ? null : spec.key;
                  });
                }
              : null,
          child: _valueBox(
            spec.options.isEmpty ? '加载中…' : spec.options[safeIndex],
            arrow: selectable,
          ),
        ),
      ),
    ];
  }

  Widget _optionsOverlay(_RuleRow row) {
    const itemHeight = 20.0;
    final spec = row.spec;
    final maxHeight = widget.height - 8;
    final fullHeight = spec.options.length * itemHeight + 2;
    final listHeight = fullHeight > maxHeight ? maxHeight : fullHeight;
    var listTop = row.top + 22;
    if (listTop + listHeight > widget.height - 4) {
      listTop = row.top - listHeight;
    }
    if (listTop < 4) listTop = 4;
    final maxTop = widget.height - listHeight - 4;
    if (maxTop >= 4 && listTop > maxTop) listTop = maxTop;

    final selected = spec.selected.clamp(0, spec.options.length - 1);
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
              for (var i = 0; i < spec.options.length; i++)
                DuelHit(
                  key: ValueKey('rule-option-${spec.key}-$i'),
                  onTap: () {
                    DuelSounds.tabSwitch();
                    setState(() => _openKey = null);
                    spec.onSelected!(i);
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
                            spec.options[i],
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

  Widget _checkRow(RuleCheckSpec spec, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: DuelHit(
        key: ValueKey('rule-check-' + spec.key),
        onTap: () {
          DuelSounds.tabSwitch();
          spec.onChanged(!spec.value);
        },
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: spec.value ? DuelColors.accent : Colors.transparent,
                border: Border.all(
                  color: spec.value ? DuelColors.accent : const Color(0xFF3A4A5E),
                ),
              ),
              alignment: Alignment.center,
              child: spec.value
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
            Text(
              spec.label,
              style: DuelType.sans(7.5, color: DuelColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
