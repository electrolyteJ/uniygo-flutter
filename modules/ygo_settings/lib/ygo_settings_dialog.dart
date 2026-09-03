import 'package:biz/service_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'duel_room_renderer.dart';

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
    required this.onSpectateJumpChanged,
    required this.onReplaySpeedFactorChanged,
    this.extraActions = const [],
  });

  final YgoSettings initialSettings;
  final ValueChanged<bool> onShowChain1Changed;
  final ValueChanged<bool> onAutoMonsterChanged;
  final ValueChanged<bool> onAutoSpellTrapChanged;

  /// 观战回放模式切换（true = 跳到当前局面）。
  final ValueChanged<bool> onSpectateJumpChanged;

  /// 回放速度倍率切换（0.5/1/2/4）。
  final ValueChanged<double> onReplaySpeedFactorChanged;

  /// 弹窗底部附加动作（宿主自定义入口）。
  final List<SettingsExtraAction> extraActions;

  @override
  State<YgoSettingsDialog> createState() => _YgoSettingsDialogState();
}

class _YgoSettingsDialogState extends State<YgoSettingsDialog> {
  late bool _showChain1;
  late bool _autoMonster;
  late bool _autoSpellTrap;
  late bool _spectateJump;
  late double _replaySpeedFactor;

  @override
  void initState() {
    super.initState();
    _showChain1 = widget.initialSettings.showChain1Animation;
    _autoMonster = widget.initialSettings.autoMonsterPosition;
    _autoSpellTrap = widget.initialSettings.autoSpellTrapPosition;
    _spectateJump = widget.initialSettings.spectateJumpToCurrent;
    _replaySpeedFactor = widget.initialSettings.replaySpeedFactor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            // ── 观战 ──
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '观战',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.play_circle_outline),
                      label: Text('带节奏回放'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.fast_forward),
                      label: Text('跳到当前局面'),
                    ),
                  ],
                  selected: {_spectateJump},
                  onSelectionChanged: (selection) {
                    setState(() => _spectateJump = selection.first);
                    widget.onSpectateJumpChanged(selection.first);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '中途进入观战时，开局以来的历史消息如何呈现',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 0.5, label: Text('0.5x')),
                    ButtonSegment(value: 1.0, label: Text('1x')),
                    ButtonSegment(value: 2.0, label: Text('2x')),
                    ButtonSegment(value: 4.0, label: Text('4x')),
                  ],
                  selected: {_replaySpeedFactor},
                  onSelectionChanged: (selection) {
                    setState(() => _replaySpeedFactor = selection.first);
                    widget.onReplaySpeedFactorChanged(selection.first);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '带节奏回放的播放速度；跳到当前局面时无效',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
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
