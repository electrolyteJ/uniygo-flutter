import 'package:biz/service_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.0：Override 类型不再从主库导出，需经 misc.dart 引入。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'duel_room_renderer.dart';

export 'duel_room_renderer.dart';

const _kChain1 = 'duel_settings.show_chain1_animation';
const _kMonster = 'duel_settings.auto_monster_position';
const _kSpellTrap = 'duel_settings.auto_spell_trap_position';

/// 带 SharedPreferences 持久化的设置实现。
///
/// build() 先返回内存默认值，随后异步读盘并覆盖 state；
/// 读盘落定前的用户改动通过 [YgoSettingsNotifier] 的 copyWith 保留。
class PersistentYgoSettingsNotifier extends YgoSettingsNotifier {
  bool _loaded = false;

  @override
  YgoSettings build() {
    _load();
    return YgoSettings.defaults;
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

/// 设置弹窗附加动作（宿主注入的自定义入口，如「3D 场景预览」）。
class SettingsExtraAction {
  const SettingsExtraAction({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final void Function(BuildContext context) onTap;
  final IconData? icon;
}

/// 全局设置弹窗（纯 [StatefulWidget]，不 watch 任何 provider：
/// 设置初值与写回回调由打开方注入。这样弹窗挂在根 Navigator overlay 后
/// 无需依赖房间 ProviderScope，也避免弹窗 build 时同步 flush 共享
/// provider 触发其它监听者的 markNeedsBuild）。
class YgoSettingsDialog extends StatefulWidget {
  const YgoSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onShowChain1Changed,
    required this.onAutoMonsterChanged,
    required this.onAutoSpellTrapChanged,
    this.extraActions = const [],
  });

  final YgoSettings initialSettings;
  final ValueChanged<bool> onShowChain1Changed;
  final ValueChanged<bool> onAutoMonsterChanged;
  final ValueChanged<bool> onAutoSpellTrapChanged;

  /// 弹窗底部附加动作（宿主自定义入口）。
  final List<SettingsExtraAction> extraActions;

  @override
  State<YgoSettingsDialog> createState() => _YgoSettingsDialogState();
}

class _YgoSettingsDialogState extends State<YgoSettingsDialog> {
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
      title: const Text('设置'),
      contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 决斗场地渲染（2D/3D）；3D 需 Flutter GPU，Web 端隐藏 ──
            if (!kIsWeb) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  '决斗场地',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: ValueListenableBuilder<DuelRoomRenderer>(
                  valueListenable: DuelRoomRendererPreference.current,
                  builder: (context, renderer, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<DuelRoomRenderer>(
                        segments: const [
                          ButtonSegment(
                            value: DuelRoomRenderer.room2d,
                            icon: Icon(Icons.grid_on),
                            label: Text('2D'),
                          ),
                          ButtonSegment(
                            value: DuelRoomRenderer.room3d,
                            icon: Icon(Icons.view_in_ar),
                            label: Text('3D'),
                          ),
                        ],
                        selected: {renderer},
                        onSelectionChanged: (selection) {
                          DuelRoomRendererPreference.set(selection.first);
                        },
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  '3D 为 flame_3d 场景（需 Flutter GPU），建房/匹配进场生效',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
              const Divider(),
            ],
            // ── 对局行为 ──
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
            // ── 宿主附加动作 ──
            if (widget.extraActions.isNotEmpty) ...[
              const Divider(),
              for (final action in widget.extraActions)
                ListTile(
                  leading: Icon(action.icon ?? Icons.open_in_new),
                  title: Text(action.label),
                  onTap: () => action.onTap(context),
                ),
            ],
          ],
        ),
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

/// 从应用级服务容器读取设置并打开弹窗（首页等无 ProviderScope 场景）。
void showGlobalSettingsDialog(
  BuildContext context, {
  List<SettingsExtraAction> extraActions = const [],
}) {
  final settings = duelRoomServiceContainer.read(ygoSettingsProvider);
  final notifier = duelRoomServiceContainer.read(ygoSettingsProvider.notifier);
  showDialog<void>(
    context: context,
    builder: (_) => YgoSettingsDialog(
      initialSettings: settings,
      onShowChain1Changed: notifier.setShowChain1Animation,
      onAutoMonsterChanged: notifier.setAutoMonsterPosition,
      onAutoSpellTrapChanged: notifier.setAutoSpellTrapPosition,
      extraActions: extraActions,
    ),
  );
}

/// 打开设置弹窗（由 [showYgoSettingsDialogProvider] 注入给对局包调用）。
///
/// 弹窗由 [showDialog] 挂到根 Navigator overlay，脱离了房间 ProviderScope
/// widget 树；这里在打开前用调用方 context 对应的容器同步读一次设置与
/// notifier，再以纯参数注入弹窗，弹窗内部不再 watch 跨树 provider。
void showYgoSettingsDialog(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final settings = container.read(ygoSettingsProvider);
  final notifier = container.read(ygoSettingsProvider.notifier);
  showDialog<void>(
    context: context,
    builder: (_) => YgoSettingsDialog(
      initialSettings: settings,
      onShowChain1Changed: notifier.setShowChain1Animation,
      onAutoMonsterChanged: notifier.setAutoMonsterPosition,
      onAutoSpellTrapChanged: notifier.setAutoSpellTrapPosition,
    ),
  );
}

/// 宿主 app 在应用级 ProviderScope/容器注册的 overrides：
/// 把持久化实现与设置弹窗注入 biz 里的 provider 契约。
final ygoSettingsOverrides = <Override>[
  ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
  showYgoSettingsDialogProvider.overrideWithValue(showYgoSettingsDialog),
];
