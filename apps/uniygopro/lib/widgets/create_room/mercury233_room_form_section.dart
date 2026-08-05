import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_spec.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_string_codec.dart';
import 'package:uniygopro/widgets/shared/create_room.dart';

class Mercury233RoomFormSection extends StatefulWidget {
  final Mercury233RoomSpec spec;
  final String? errorText;
  final ValueChanged<Mercury233RoomSpec> onSpecChanged;

  const Mercury233RoomFormSection({
    super.key,
    required this.spec,
    required this.errorText,
    required this.onSpecChanged,
  });

  @override
  State<Mercury233RoomFormSection> createState() =>
      _Mercury233RoomFormSectionState();
}

class _Mercury233RoomFormSectionState extends State<Mercury233RoomFormSection> {
  late final TextEditingController _roomNameCtrl;
  late final TextEditingController _manualRoomStringCtrl;
  List<Mercury233BanlistOption> _banlistOptions = mercury233BanlistOptions;
  bool _hasInteracted = false;
  bool _hasSeededManualRoomString = false;
  int _banlistLoadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _roomNameCtrl = TextEditingController(text: widget.spec.roomName);
    _manualRoomStringCtrl = TextEditingController(
      text: widget.spec.manualRoomString,
    );
    _hasSeededManualRoomString =
        widget.spec.manualRoomStringEnabled ||
        widget.spec.manualRoomString.isNotEmpty;
    _loadBanlistOptions();
  }

  @override
  void didUpdateWidget(covariant Mercury233RoomFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_roomNameCtrl, widget.spec.roomName);
    _syncController(_manualRoomStringCtrl, widget.spec.manualRoomString);
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _manualRoomStringCtrl.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  void _update(Mercury233RoomSpec next) {
    _hasInteracted = true;
    widget.onSpecChanged(next);
  }

  Future<void> _loadBanlistOptions() async {
    try {
      final tables = await ServiceSingleton.instance.dataService.getAllLfTable();
      if (!mounted) return;

       if (tables.isEmpty) {
        _scheduleBanlistRetry();
        return;
      }

      final options = buildMercury233BanlistOptions(tables.values);
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
      if (current.lfTableHash != 0 && option.lfTableHash == current.lfTableHash) {
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

  void _setManualMode(bool enabled, String generatedRoomString) {
    final shouldSeedManualRoomString = enabled && !_hasSeededManualRoomString;
    if (enabled) {
      _hasSeededManualRoomString = true;
    }
    _update(
      widget.spec.copyWith(
        manualRoomStringEnabled: enabled,
        manualRoomString: shouldSeedManualRoomString
            ? generatedRoomString
            : widget.spec.manualRoomString,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = Mercury233RoomStringCodec.build(widget.spec);
    final errorText =
        widget.errorText ?? (_hasInteracted ? result.error : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _darkTextField(
          controller: _roomNameCtrl,
          label: '房间名称',
          icon: Icons.edit,
          onChanged: (value) => _update(widget.spec.copyWith(roomName: value)),
        ),
        const SizedBox(height: 10),
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
            DropdownMenuItem(value: DuelRule.mr2020, child: Text('MR5 (2020)')),
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
        dropdownRow<Mercury233BanlistOption>(
          label: '禁限卡表',
          value: _resolveBanlistOption(widget.spec.banlist, _banlistOptions),
          items: _banlistOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option.label)),
              )
              .toList(),
          onChanged: (value) => _update(widget.spec.copyWith(banlist: value)),
        ),
        const SizedBox(height: 6),
        numberRow(
          '初始 LP',
          widget.spec.startLp,
          (value) => _update(widget.spec.copyWith(startLp: value)),
        ),
        numberRow(
          '初始手牌',
          widget.spec.startHand,
          (value) => _update(widget.spec.copyWith(startHand: value)),
        ),
        numberRow(
          '每回合抽卡',
          widget.spec.drawCount,
          (value) => _update(widget.spec.copyWith(drawCount: value)),
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
        const SizedBox(height: 8),
        Material(
          color: const Color(0xFF1E2A38),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: Colors.amber,
            value: widget.spec.manualRoomStringEnabled,
            onChanged: (value) => _setManualMode(value, result.value),
            title: Text(
              '手动编辑最终房间串',
              style: TextStyle(color: Colors.blueGrey.shade100),
            ),
          ),
        ),
        if (widget.spec.manualRoomStringEnabled)
          _darkTextField(
            controller: _manualRoomStringCtrl,
            label: '最终房间串',
            icon: Icons.code,
            onChanged: (value) {
              _hasSeededManualRoomString = true;
              _update(widget.spec.copyWith(manualRoomString: value));
            },
          )
        else
          _roomStringPreview(result.value),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey.shade300),
        prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
        filled: true,
        fillColor: Colors.blueGrey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _roomStringPreview(String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '最终房间串: $value',
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      ),
    );
  }
}
