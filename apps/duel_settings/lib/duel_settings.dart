import 'package:biz/duel_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kChain1 = 'duel_settings.show_chain1_animation';
const _kMonster = 'duel_settings.auto_monster_position';
const _kSpellTrap = 'duel_settings.auto_spell_trap_position';

/// 带 SharedPreferences 持久化的设置实现。
///
/// build() 先返回内存默认值，随后异步读盘并覆盖 state；
/// 读盘落定前的用户改动通过 [DuelSettingsNotifier] 的 copyWith 保留。
class PersistentDuelSettingsNotifier extends DuelSettingsNotifier {
  bool _loaded = false;

  @override
  DuelSettings build() {
    _load();
    return DuelSettings.defaults;
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      showChain1Animation: prefs.getBool(_kChain1) ?? state.showChain1Animation,
      autoMonsterPosition:
          prefs.getBool(_kMonster) ?? state.autoMonsterPosition,
      autoSpellTrapPosition:
          prefs.getBool(_kSpellTrap) ?? state.autoSpellTrapPosition,
    );
  }

  @override
  void setShowChain1Animation(bool value) {
    super.setShowChain1Animation(value);
    _persist(_kChain1, value);
  }

  @override
  void setAutoMonsterPosition(bool value) {
    super.setAutoMonsterPosition(value);
    _persist(_kMonster, value);
  }

  @override
  void setAutoSpellTrapPosition(bool value) {
    super.setAutoSpellTrapPosition(value);
    _persist(_kSpellTrap, value);
  }

  Future<void> _persist(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}

/// 全局设置弹窗（纯 [StatefulWidget]，不 watch 任何 provider：
/// 设置初值与写回回调由 [showDuelSettingsDialog] 注入。这样弹窗挂在根
/// Navigator overlay 后无需依赖房间 ProviderScope，也避免弹窗 build 时
/// 同步 flush 共享 provider 触发其它监听者的 markNeedsBuild）。
class DuelSettingsDialog extends StatefulWidget {
  const DuelSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onShowChain1Changed,
    required this.onAutoMonsterChanged,
    required this.onAutoSpellTrapChanged,
  });

  final DuelSettings initialSettings;
  final ValueChanged<bool> onShowChain1Changed;
  final ValueChanged<bool> onAutoMonsterChanged;
  final ValueChanged<bool> onAutoSpellTrapChanged;

  @override
  State<DuelSettingsDialog> createState() => _DuelSettingsDialogState();
}

class _DuelSettingsDialogState extends State<DuelSettingsDialog> {
  late bool _showChain1;
  late bool _autoMonster;
  late bool _autoSpellTrap;

  @override
  void initState() {
    super.initState();
    _showChain1 = widget.initialSettings.showChain1Animation;
    _autoMonster = widget.initialSettings.autoMonsterPosition;
    _autoSpellTrap = widget.initialSettings.autoSpellTrapPosition;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('对局设置'),
      contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('连锁1 也要显示连锁动画'),
            subtitle: const Text('开启后，只有 1 张卡的连锁也会弹出连锁叠层'),
            value: _showChain1,
            onChanged: (v) {
              setState(() => _showChain1 = v);
              widget.onShowChain1Changed(v);
            },
          ),
          SwitchListTile(
            title: const Text('自动选择怪兽卡片位置'),
            subtitle: const Text('召唤 / 特殊召唤怪兽时自动选择空位'),
            value: _autoMonster,
            onChanged: (v) {
              setState(() => _autoMonster = v);
              widget.onAutoMonsterChanged(v);
            },
          ),
          SwitchListTile(
            title: const Text('自动选择魔陷卡片位置'),
            subtitle: const Text('发动 / 盖放魔陷时自动选择空位'),
            value: _autoSpellTrap,
            onChanged: (v) {
              setState(() => _autoSpellTrap = v);
              widget.onAutoSpellTrapChanged(v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 打开设置弹窗（由 [showDuelSettingsDialogProvider] 注入给对局包调用）。
///
/// 弹窗由 [showDialog] 挂到根 Navigator overlay，脱离了房间 ProviderScope
/// widget 树；这里在打开前用调用方 context 对应的容器同步读一次设置与
/// notifier，再以纯参数注入弹窗，弹窗内部不再 watch 跨树 provider。
void showDuelSettingsDialog(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final settings = container.read(duelSettingsProvider);
  final notifier = container.read(duelSettingsProvider.notifier);
  showDialog<void>(
    context: context,
    builder: (_) => DuelSettingsDialog(
      initialSettings: settings,
      onShowChain1Changed: notifier.setShowChain1Animation,
      onAutoMonsterChanged: notifier.setAutoMonsterPosition,
      onAutoSpellTrapChanged: notifier.setAutoSpellTrapPosition,
    ),
  );
}

/// 宿主 app 在应用级 ProviderScope/容器注册的 overrides：
/// 把持久化实现与设置弹窗注入 biz 里的 provider 契约。
final duelSettingsOverrides = <Override>[
  duelSettingsProvider.overrideWith(PersistentDuelSettingsNotifier.new),
  showDuelSettingsDialogProvider.overrideWithValue(showDuelSettingsDialog),
];
