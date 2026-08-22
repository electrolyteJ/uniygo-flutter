// ────────────────────────────────────────────────────────────
// 通用房间参数表单（mycard / 233 / AI 房共用）
// ────────────────────────────────────────────────────────────

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import '../../models/mercury233_room_spec.dart';
import 'duel_room_params_fields.dart';
import 'room_dialog.dart';

/// 通用房间参数表单：对战模式（可选）/ 大师规则 / 卡片允许 /
/// 初始 LP / 初始手牌 / 每回合抽卡 / 时间限制 / 卡组检查开关，
/// 以及（可选）禁限卡表。
///
/// 以 [RoomOptions] 为唯一数据模型，供 mycard/koishi 建房表单
/// （CreateRoomForm）、233 建房表单（Mercury233RoomFormSection）与
/// AI 房面板（AiRoomSheet）复用，三处不再各自维护重复的参数控件
/// 与选项列表。
///
/// - [cardRuleItems]：卡片允许选项集（mycard 用 cardRuleItems 6 档，
///   233 用 cardRuleItems233 4 档）。
/// - [showMode]：本地 AI 固定单局，传入 false 隐藏对战模式。
/// - [showBanlist]：仅 233 需要禁限卡表，mycard/本地 AI 传 false。
class RoomParamsForm extends StatefulWidget {
  final RoomOptions options;
  final ValueChanged<RoomOptions> onChanged;
  final List<DropdownMenuItem<int>> cardRuleItems;
  final bool showMode;
  final bool showBanlist;

  /// 禁限卡表选项数据源；加载失败或为空时回退内置默认选项。
  final Future<List<Mercury233BanlistOption>> Function()? banlistOptionsLoader;

  /// 当前禁限卡表选择（仅 [showBanlist] 时使用）。
  final Mercury233BanlistOption banlist;

  /// 禁限卡表变更回调（仅 [showBanlist] 时使用）。
  final ValueChanged<Mercury233BanlistOption>? onBanlistChanged;

  const RoomParamsForm({
    super.key,
    required this.options,
    required this.onChanged,
    required this.cardRuleItems,
    this.showMode = true,
    this.showBanlist = false,
    this.banlistOptionsLoader,
    this.banlist = const Mercury233BanlistOption(
      label: '默认禁限',
      token: 'LF1',
      lfTableHash: 0,
    ),
    this.onBanlistChanged,
  });

  @override
  State<RoomParamsForm> createState() => _RoomParamsFormState();
}

class _RoomParamsFormState extends State<RoomParamsForm> {
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

      final selected = _resolveBanlistOption(widget.banlist, options);
      setState(() {
        _banlistOptions = options;
      });
      if (selected != widget.banlist) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onBanlistChanged?.call(selected);
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

  void _update(RoomOptions next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showMode)
          roomModeField(
            widget.options.mode,
            (value) => _update(widget.options.copyWith(mode: value)),
          ),
        duelRuleField(
          widget.options.duelRule,
          (value) => _update(widget.options.copyWith(duelRule: value)),
        ),
        cardRuleField(
          widget.options.rule,
          widget.cardRuleItems,
          (value) => _update(widget.options.copyWith(rule: value)),
        ),
        if (widget.showBanlist)
          dropdownRow<Mercury233BanlistOption>(
            label: '禁限卡表',
            value: _resolveBanlistOption(widget.banlist, _banlistOptions),
            items: _banlistOptions
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) widget.onBanlistChanged?.call(value);
            },
          ),
        const SizedBox(height: 6),
        startLpField(
          widget.options.startLp,
          (value) => _update(widget.options.copyWith(startLp: value)),
        ),
        startHandField(
          widget.options.startHand,
          (value) => _update(widget.options.copyWith(startHand: value)),
        ),
        drawCountField(
          widget.options.drawCount,
          (value) => _update(widget.options.copyWith(drawCount: value)),
        ),
        timeLimitField(
          widget.options.timeLimit,
          (value) => _update(widget.options.copyWith(timeLimit: value)),
        ),
        const SizedBox(height: 6),
        deckCheckFields(
          noCheckDeck: widget.options.noCheckDeck,
          noShuffleDeck: widget.options.noShuffleDeck,
          onNoCheckDeckChanged: (value) =>
              _update(widget.options.copyWith(noCheckDeck: value ?? false)),
          onNoShuffleDeckChanged: (value) =>
              _update(widget.options.copyWith(noShuffleDeck: value ?? false)),
        ),
      ],
    );
  }
}
