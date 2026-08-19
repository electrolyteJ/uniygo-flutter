// ────────────────────────────────────────────────────────────
// 233 服共享参数表单（建房表单与 AI 房面板复用）
// ────────────────────────────────────────────────────────────

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import '../../models/mercury233_room_spec.dart';
import 'room_dialog.dart';

/// 233 服房间共享参数表单：大师规则 / 卡片允许 / 禁限卡表 /
/// 初始 LP / 初始手牌 / 每回合抽卡 / 时间限制 / 卡组检查开关。
///
/// 以 [Mercury233RoomSpec] 驱动，供自由房创建表单
/// （[Mercury233RoomFormSection] 之外的参数部分）与 AI 房面板复用，
/// 两侧不再各自维护重复的参数控件。
///
/// 房间名 / 对战模式 / 手动房间串是建房表单专属（AI 主机密码没有
/// 这些概念），留在 Mercury233RoomFormSection。
class Mercury233RoomParamsForm extends StatefulWidget {
  final Mercury233RoomSpec spec;
  final ValueChanged<Mercury233RoomSpec> onSpecChanged;

  /// 禁限卡表选项数据源（如 dataService 的全部 lflist 表）；
  /// 加载失败或为空时回退内置默认选项（默认禁限 / 无禁限）。
  final Future<List<Mercury233BanlistOption>> Function()? banlistOptionsLoader;

  /// 是否显示禁限卡表选项（本地 AI 用不到禁限，可隐藏）。
  final bool showBanlist;

  const Mercury233RoomParamsForm({
    super.key,
    required this.spec,
    required this.onSpecChanged,
    this.banlistOptionsLoader,
    this.showBanlist = true,
  });

  @override
  State<Mercury233RoomParamsForm> createState() =>
      _Mercury233RoomParamsFormState();
}

class _Mercury233RoomParamsFormState extends State<Mercury233RoomParamsForm> {
  List<Mercury233BanlistOption> _banlistOptions = mercury233BanlistOptions;
  int _banlistLoadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadBanlistOptions();
  }

  Future<void> _loadBanlistOptions() async {
    final loader = widget.banlistOptionsLoader;
    if (loader == null) return;
    try {
      final options = await loader();
      if (!mounted) return;

      if (options.isEmpty) {
        _scheduleBanlistRetry();
        return;
      }

      final selected = _resolveBanlistOption(widget.spec.banlist, options);
      setState(() {
        _banlistOptions = options;
      });
      if (selected != widget.spec.banlist) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onSpecChanged(widget.spec.copyWith(banlist: selected));
        });
      }
    } catch (_) {
      _scheduleBanlistRetry();
    }
  }

  void _scheduleBanlistRetry() {
    if (!mounted) return;
    if (_banlistLoadAttempts >= 5) {
      setState(() {
        _banlistOptions = mercury233BanlistOptions;
      });
      return;
    }
    _banlistLoadAttempts += 1;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _loadBanlistOptions();
    });
  }

  Mercury233BanlistOption _resolveBanlistOption(
    Mercury233BanlistOption current,
    List<Mercury233BanlistOption> options,
  ) {
    for (final option in options) {
      if (current.lfTableHash != 0 &&
          option.lfTableHash == current.lfTableHash) {
        return option;
      }
    }
    for (final option in options) {
      if (option.token == current.token) {
        return option;
      }
    }
    return options.first;
  }

  void _update(Mercury233RoomSpec next) => widget.onSpecChanged(next);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dropdownRow<RoomMode>(
          label: '对战模式',
          value: widget.spec.mode,
          items: const [
            DropdownMenuItem(value: RoomMode.single, child: Text('单局')),
            DropdownMenuItem(
              value: RoomMode.match,
              child: Text('三局两胜 (Match)'),
            ),
            DropdownMenuItem(value: RoomMode.tag, child: Text('双打 (Tag)')),
          ],
          onChanged: (value) => _update(widget.spec.copyWith(mode: value)),
        ),
        dropdownRow<DuelRule>(
          label: '大师规则',
          value: widget.spec.duelRule,
          items: const [
            DropdownMenuItem(value: DuelRule.mr3, child: Text('MR3 (2014)')),
            DropdownMenuItem(value: DuelRule.mr4, child: Text('MR4 (2017)')),
            DropdownMenuItem(
              value: DuelRule.mr2020,
              child: Text('MR5 (2020)'),
            ),
          ],
          onChanged: (value) => _update(widget.spec.copyWith(duelRule: value)),
        ),
        dropdownRow<Mercury233CardPoolMode>(
          label: '卡片允许',
          value: widget.spec.cardPoolMode,
          items: const [
            DropdownMenuItem(
              value: Mercury233CardPoolMode.ocg,
              child: Text('OCG'),
            ),
            DropdownMenuItem(
              value: Mercury233CardPoolMode.tcgAndOcg,
              child: Text('TCG + OCG'),
            ),
            DropdownMenuItem(
              value: Mercury233CardPoolMode.tcgOnly,
              child: Text('仅 TCG'),
            ),
            DropdownMenuItem(
              value: Mercury233CardPoolMode.noUnique,
              child: Text('无独有卡'),
            ),
          ],
          onChanged: (value) =>
              _update(widget.spec.copyWith(cardPoolMode: value)),
        ),
        if (widget.showBanlist)
          dropdownRow<Mercury233BanlistOption>(
            label: '禁限卡表',
            value: _resolveBanlistOption(widget.spec.banlist, _banlistOptions),
            items: _banlistOptions
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) => _update(widget.spec.copyWith(banlist: value)),
          ),
        const SizedBox(height: 6),
        numberRow(
          '初始 LP',
          widget.spec.startLp,
          (value) => _update(widget.spec.copyWith(startLp: value)),
          max: 65535,
        ),
        numberRow(
          '初始手牌',
          widget.spec.startHand,
          (value) => _update(widget.spec.copyWith(startHand: value)),
          max: 15,
        ),
        numberRow(
          '每回合抽卡',
          widget.spec.drawCount,
          (value) => _update(widget.spec.copyWith(drawCount: value)),
          max: 15,
        ),
        dropdownRow<int>(
          label: '时间限制',
          value: widget.spec.timeLimit,
          items: const [
            DropdownMenuItem(value: 0, child: Text('无限制')),
            DropdownMenuItem(value: 180, child: Text('3 分钟')),
            DropdownMenuItem(value: 240, child: Text('4 分钟')),
            DropdownMenuItem(value: 300, child: Text('5 分钟')),
            DropdownMenuItem(value: 600, child: Text('10 分钟')),
          ],
          onChanged: (value) => _update(widget.spec.copyWith(timeLimit: value)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            checkRow(
              '不检查卡组',
              widget.spec.noCheckDeck,
              (value) =>
                  _update(widget.spec.copyWith(noCheckDeck: value ?? false)),
            ),
            const SizedBox(width: 16),
            checkRow(
              '不切洗卡组',
              widget.spec.noShuffleDeck,
              (value) =>
                  _update(widget.spec.copyWith(noShuffleDeck: value ?? false)),
            ),
          ],
        ),
      ],
    );
  }
}
