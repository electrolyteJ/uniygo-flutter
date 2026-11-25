/// 全局设置弹窗：画面 / 音效 / 对局 / 账号 / AI 设置。
///
/// 设计稿：Ardot 744179416852082 页面「03 主页大厅 · 设置弹窗」+「03g AI」。
/// 画面/音效/AI 偏好落 SharedPreferences；对局项写 biz 的 ygo_settings；
/// 账号页只负责展示，退出/登录由宿主通过回调注入（模块不依赖账号包）。
library;

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'duel_room_renderer.dart';

import 'theme/duel_controls.dart';
import 'theme/duel_sound.dart';
import 'theme/duel_theme.dart';
import 'ai_settings.dart';
import 'system_ui.dart';

const _kSoundKey = 'home_settings.sound_enabled';

// 等候厅默认行为（与 biz duel_room_state 的持久化键保持一致）。
const String _kAutoDuelKey = 'duel.auto_duel_enabled';
const String _kAutoHandKey = 'duel.auto_hand_enabled';
const String _kAutoTurnOrderKey = 'duel.auto_turn_order_enabled';

/// 设置弹窗附加动作（宿主注入的自定义入口，如「3D 场景预览」）。
class SettingsExtraAction {
  const SettingsExtraAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final void Function(BuildContext context) onTap;
}

class YgoSettingsDialog extends StatefulWidget {
  const YgoSettingsDialog({
    super.key,
    this.initialSettings,
    this.onShowChain1Changed,
    this.onAutoMonsterChanged,
    this.onAutoSpellTrapChanged,
    this.onSpectateJumpChanged,
    this.onReplaySpeedFactorChanged,
    this.extraActions = const [],
    this.autoDuel,
    this.autoHand,
    this.autoTurnOrder,
    this.onAutoDuelChanged,
    this.onAutoHandChanged,
    this.onAutoTurnOrderChanged,
    this.onClose,
    this.isLoggedIn = false,
    this.accountName,
    this.accountUsername,
    this.onSignOut,
    this.onGoLogin,
    this.onOpenPreview,
    this.scrim = true,
  });

  /// 等候厅三项开关的初值（等待室打开时传当前房间值；不传读本机偏好）。
  final bool? autoDuel;
  final bool? autoHand;
  final bool? autoTurnOrder;

  /// 等候厅三项开关的即时回调（等待室注入房间 notifier 的 setter）。
  final ValueChanged<bool>? onAutoDuelChanged;
  final ValueChanged<bool>? onAutoHandChanged;
  final ValueChanged<bool>? onAutoTurnOrderChanged;

  /// 对局设置初值（宿主从服务容器读出后注入）。
  final YgoSettings? initialSettings;

  /// 对局设置变更回调（宿主写回服务容器）。
  final ValueChanged<bool>? onShowChain1Changed;
  final ValueChanged<bool>? onAutoMonsterChanged;
  final ValueChanged<bool>? onAutoSpellTrapChanged;
  final ValueChanged<bool>? onSpectateJumpChanged;
  final ValueChanged<double>? onReplaySpeedFactorChanged;

  /// 附加动作（宿主自定义入口）。
  final List<SettingsExtraAction> extraActions;

  /// 关闭回调；为空时走 Navigator.maybePop。
  final VoidCallback? onClose;

  /// 是否绘制内部遮罩（嵌入舞台时为 true；showDialog 自带 barrier 时为 false）。
  final bool scrim;

  final bool isLoggedIn;
  final String? accountName;
  final String? accountUsername;

  /// 账号页动作（模块不依赖账号包，由宿主注入）。
  final VoidCallback? onSignOut;
  final VoidCallback? onGoLogin;

  /// 画面页的 2D/3D 场景预览入口。
  final void Function(bool is3d)? onOpenPreview;

  @override
  State<YgoSettingsDialog> createState() => _YgoSettingsDialogState();
}

class _YgoSettingsDialogState extends State<YgoSettingsDialog> {
  static const _navItems = ['画面', '音效', '对局', '账号', 'AI 设置'];

  int _nav = 0;
  bool _fullscreen = true;
  bool _soundEnabled = true;

  bool _aiServer233 = false;
  AiModel _aiModel = AiModel.onDevice;

  bool _chainAnimation = true;
  bool _autoMonster = false;

  // 等候厅（房间默认行为）：入座 / 猜拳 / 先后手。
  bool _autoDuel = false;
  bool _autoHand = false;
  bool _autoTurnOrder = false;
  bool _autoSpellTrap = false;
  bool _spectateJump = false;
  int _replaySpeedIndex = 1;

  static const _replaySpeeds = [0.5, 1.0, 2.0, 4.0];
  static const _replayLabels = ['0.5x', '1x', '2x', '4x'];

  SharedPreferences? _prefs;

  void _setShowChain1(bool v) {
    final cb = widget.onShowChain1Changed;
    if (cb != null) {
      cb(v);
    } else {
      _settingsNotifier()?.setShowChain1Animation(v);
    }
  }

  void _setAutoMonster(bool v) {
    final cb = widget.onAutoMonsterChanged;
    if (cb != null) {
      cb(v);
    } else {
      _settingsNotifier()?.setAutoMonsterPosition(v);
    }
  }

  void _setAutoSpellTrap(bool v) {
    final cb = widget.onAutoSpellTrapChanged;
    if (cb != null) {
      cb(v);
    } else {
      _settingsNotifier()?.setAutoSpellTrapPosition(v);
    }
  }

  void _setSpectateJump(bool v) {
    final cb = widget.onSpectateJumpChanged;
    if (cb != null) {
      cb(v);
    } else {
      _settingsNotifier()?.setSpectateJumpToCurrent(v);
    }
  }

  void _setReplaySpeed(double v) {
    final cb = widget.onReplaySpeedFactorChanged;
    if (cb != null) {
      cb(v);
    } else {
      _settingsNotifier()?.setReplaySpeedFactor(v);
    }
  }

  YgoSettingsNotifier? _settingsNotifier() {
    try {
      return duelRoomServiceContainer.read(ygoSettingsProvider.notifier);
    } catch (_) {
      return null;
    }
  }

  void _close() {
    final close = widget.onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  final ScrollController _duelScroll = ScrollController();

  @override
  void dispose() {
    _duelScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDuelSettings();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _fullscreen = prefs.getBool(kFullscreenSettingKey) ?? true;
      _soundEnabled = prefs.getBool(_kSoundKey) ?? YgoSoundService.enabled;
      YgoSoundService.enabled = _soundEnabled;
      _aiServer233 = prefs.getBool(kAiServer233Key) ?? false;
      _aiModel = AiModel.values[(prefs.getInt(kAiModelKey) ?? 0).clamp(0, 2)];
      // 等候厅开关：宿主（等待室）传了当前房间值就优先用它。
      _autoDuel = widget.autoDuel ?? prefs.getBool(_kAutoDuelKey) ?? false;
      _autoHand = widget.autoHand ?? prefs.getBool(_kAutoHandKey) ?? false;
      _autoTurnOrder =
          widget.autoTurnOrder ?? prefs.getBool(_kAutoTurnOrderKey) ?? false;
    });
  }

  void _loadDuelSettings() {
    // 优先用宿主注入的初值；没注入再从服务容器读（容器未注册则用默认值）。
    final YgoSettings settings;
    final injected = widget.initialSettings;
    if (injected != null) {
      settings = injected;
    } else {
      try {
        settings = duelRoomServiceContainer.read(ygoSettingsProvider);
      } catch (_) {
        return;
      }
    }
    _chainAnimation = settings.showChain1Animation;
    _autoMonster = settings.autoMonsterPosition;
    _autoSpellTrap = settings.autoSpellTrapPosition;
    _spectateJump = settings.spectateJumpToCurrent;
    final speedIndex = _replaySpeeds.indexWhere(
      (s) => (s - settings.replaySpeedFactor).abs() < 0.01,
    );
    _replaySpeedIndex = speedIndex < 0 ? 1 : speedIndex;
  }

  Future<void> _save() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(kFullscreenSettingKey, _fullscreen);
    YgoSoundService.enabled = _soundEnabled;
    // 音效是纯偏好，与当前房间无关，必须无条件落盘（曾经被下面的
    // 「有即时回调就不写」分支误吞，导致等候厅打开设置时静音重启失效）。
    await prefs.setBool(_kSoundKey, _soundEnabled);
    // 等候厅三项：有即时回调时由宿主的房间 notifier 负责持久化（并处理
    // 已准备态拒绝），这里不再重复写，避免「当前房间没生效但偏好被改了」。
    if (widget.onAutoDuelChanged == null) {
      await prefs.setBool(_kAutoDuelKey, _autoDuel);
    }
    if (widget.onAutoHandChanged == null) {
      await prefs.setBool(_kAutoHandKey, _autoHand);
    }
    if (widget.onAutoTurnOrderChanged == null) {
      await prefs.setBool(_kAutoTurnOrderKey, _autoTurnOrder);
    }
    await prefs.setBool(kAiServer233Key, _aiServer233);
    await prefs.setInt(kAiModelKey, _aiModel.index);
    await applyFullscreenSetting(_fullscreen);
    if (!mounted) return;
    _toast('设置已保存');
    _close();
  }

  /// 恢复默认：默认值立即写回偏好，不再依赖随后点「保存」。
  ///
  /// 旧实现只重置 UI 与即时生效项，画面/音效/AI 的键保持原值，
  /// 「恢复默认 → 直接关闭」下次打开又回到旧值。
  Future<void> _restoreDefaults() async {
    // 容器未注册时只重置本地 UI 值。
    setState(() {
      _fullscreen = true;
      _soundEnabled = true;
      _aiServer233 = false;
      _aiModel = AiModel.onDevice;
      _chainAnimation = false;
      _replaySpeedIndex = 1;
      _autoMonster = false;
      _autoDuel = false;
      _autoHand = false;
      _autoTurnOrder = false;
      _autoSpellTrap = false;
      _spectateJump = false;
    });
    final notifier = _settingsNotifier();
    notifier?.setShowChain1Animation(false);
    notifier?.setAutoMonsterPosition(false);
    notifier?.setAutoSpellTrapPosition(false);
    notifier?.setSpectateJumpToCurrent(false);
    notifier?.setReplaySpeedFactor(1.0);
    await DuelRoomRendererPreference.set(DuelRoomRenderer.room2d);
    YgoSoundService.enabled = true;
    // 等候厅三项同时作用到当前房间（房间 notifier 自己负责持久化）。
    widget.onAutoDuelChanged?.call(false);
    widget.onAutoHandChanged?.call(false);
    widget.onAutoTurnOrderChanged?.call(false);

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(kFullscreenSettingKey, _fullscreen);
    await prefs.setBool(_kSoundKey, _soundEnabled);
    if (widget.onAutoDuelChanged == null) {
      await prefs.setBool(_kAutoDuelKey, _autoDuel);
    }
    if (widget.onAutoHandChanged == null) {
      await prefs.setBool(_kAutoHandKey, _autoHand);
    }
    if (widget.onAutoTurnOrderChanged == null) {
      await prefs.setBool(_kAutoTurnOrderKey, _autoTurnOrder);
    }
    await prefs.setBool(kAiServer233Key, _aiServer233);
    await prefs.setInt(kAiModelKey, _aiModel.index);
    await applyFullscreenSetting(_fullscreen);
    if (!mounted) return;
    _toast('已恢复默认设置');
  }

  void _signOut() {
    widget.onSignOut?.call();
    _toast('已退出 MyCard 登录，可点击头像重新登录');
    _close();
  }

  void _goLogin() {
    _close();
    widget.onGoLogin?.call();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.isLoggedIn;

    return Stack(
      children: [
        if (widget.scrim)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: Container(color: const Color(0xB8000000)),
            ),
          ),
        Positioned(
          left: 102,
          top: 45,
          width: 640,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              color: DuelColors.panel,
              border: Border.all(color: DuelColors.borderPanel),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: Container(height: 2, color: DuelColors.accent),
                ),
                Positioned(
                  left: 20,
                  top: 9,
                  child: Text('设置', style: DuelType.sans(14, height: 1.2)),
                ),
                Positioned(
                  left: 20,
                  top: 30,
                  child: Text(
                    'SETTINGS · 即时生效 · 保存后留存',
                    style: DuelType.latin(7.5, color: DuelColors.textFaint),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 8,
                  child: DuelHit(
                    onTap: _close,
                    borderRadius: BorderRadius.circular(2),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: DuelColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 49,
                  right: 22,
                  child: Container(height: 1, color: DuelColors.divider),
                ),
                for (var i = 0; i < _navItems.length; i++) _navItem(i),
                Positioned(
                  left: 142,
                  top: 61,
                  child: Container(
                    width: 1,
                    height: 180,
                    color: DuelColors.divider,
                  ),
                ),
                ..._pane(loggedIn),
                _footer(loggedIn),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem(int index) {
    final selected = index == _nav;
    return Positioned(
      left: 16,
      top: 61 + index * 42,
      width: 116,
      height: 36,
      child: DuelHit(
        onTap: () {
          if (selected) return;
          DuelSounds.tabSwitch();
          setState(() => _nav = index);
        },
        child: Stack(
          children: [
            if (selected) ...[
              Positioned.fill(
                child: Container(color: DuelColors.surfaceSelected),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: DuelColors.accent),
              ),
            ],
            Positioned(
              left: 14,
              top: 9,
              child: Text(
                _navItems[index],
                style: DuelType.sans(
                  11,
                  color: selected ? DuelColors.accent : DuelColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pane(bool loggedIn) {
    return switch (_nav) {
      0 => _screenPane(),
      1 => _soundPane(),
      2 => [_duelPane()],
      3 => _accountPane(loggedIn),
      _ => _aiPane(),
    };
  }

  List<Widget> _screenPane() {
    // 分辨率 / 画质 / 帧率没有消费方（渲染层不读这些键），做成可点项会
    // 造成「改完保存了却不生效」。这里只展示自动值，可调的只有全屏。
    return [
      _label('分辨率', 75),
      _staticValue(75, '自动 · 跟随屏幕'),
      _divider(109),
      _label('画质', 127),
      _staticValue(127, '自动 · 跟随设备性能'),
      _divider(161),
      _label('帧率上限', 179),
      _staticValue(179, '自动 · 跟随屏幕刷新率'),
      _divider(213),
      _label('全屏显示', 231),
      Positioned(
        left: 576,
        top: 229,
        child: _DuelSwitch(
          value: _fullscreen,
          onChanged: (v) => setState(() => _fullscreen = v),
        ),
      ),
    ];
  }

  List<Widget> _soundPane() {
    return [
      _label('音效总开关', 75),
      Positioned(
        left: 576,
        top: 73,
        child: _DuelSwitch(
          key: const ValueKey('settings-sound-switch'),
          value: _soundEnabled,
          onChanged: (v) {
            setState(() => _soundEnabled = v);
            YgoSoundService.enabled = v;
          },
        ),
      ),
      _divider(109),
      _label('音效资源', 127),
      _staticValue(127, '随包分发（本地 wav）'),
      _divider(151),
      _label('音量控制', 169),
      _staticValue(169, '跟随系统音量'),
      _note(205, '关闭总开关后界面与对局音效全部静音'),
    ];
  }

  Widget _duelPane() {
    return Positioned(
      left: 160,
      top: 61,
      width: 458,
      height: 184,
      child: Scrollbar(
        controller: _duelScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _duelScroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('等候厅'),
              _switchRow('自动加入决斗', _autoDuel, (v) {
                setState(() => _autoDuel = v);
                widget.onAutoDuelChanged?.call(v);
              }),
              _hDivider(),
              _switchRow('自动猜拳', _autoHand, (v) {
                setState(() => _autoHand = v);
                widget.onAutoHandChanged?.call(v);
              }),
              _hDivider(),
              _switchRow('自动选先后手', _autoTurnOrder, (v) {
                setState(() => _autoTurnOrder = v);
                widget.onAutoTurnOrderChanged?.call(v);
              }),
              _hDivider(),
              _sectionLabel('决斗场地'),
              _switchRow('连锁1 也要显示连锁动画', _chainAnimation, (v) {
                setState(() => _chainAnimation = v);
                _setShowChain1(v);
              }),
              _hDivider(),
              _switchRow('自动选择怪兽卡片位置', _autoMonster, (v) {
                setState(() => _autoMonster = v);
                _setAutoMonster(v);
              }),
              _hDivider(),
              _switchRow('自动选择魔陷卡片位置', _autoSpellTrap, (v) {
                setState(() => _autoSpellTrap = v);
                _setAutoSpellTrap(v);
              }),
              if (!kIsWeb) ...[
                _hDivider(),
                ValueListenableBuilder<DuelRoomRenderer>(
                  valueListenable: DuelRoomRendererPreference.current,
                  builder: (context, renderer, _) => _chipRow(
                    '渲染模式',
                    const ['2D', '3D'],
                    renderer == DuelRoomRenderer.room3d ? 1 : 0,
                    (index) => DuelRoomRendererPreference.set(
                      index == 0
                          ? DuelRoomRenderer.room2d
                          : DuelRoomRenderer.room3d,
                    ),
                    width: 64,
                  ),
                ),
              ],
              _hDivider(),
              _chipRow(
                '观战历史',
                const ['带节奏回放', '跳到当前局面'],
                _spectateJump ? 1 : 0,
                (index) {
                  setState(() => _spectateJump = index == 1);
                  _setSpectateJump(index == 1);
                },
                width: 86,
              ),
              _noteLine('中途进入观战时，开局以来的历史消息如何呈现'),
              _hDivider(),
              _chipRow('回放速度', _replayLabels, _replaySpeedIndex, (index) {
                setState(() => _replaySpeedIndex = index);
                _setReplaySpeed(_replaySpeeds[index]);
              }),
              _noteLine('带节奏回放的播放速度；跳到当前局面时无效'),
              for (final action in widget.extraActions) ...[
                _hDivider(),
                _linkRow(action.label, () => action.onTap(context)),
              ],
              if (!kIsWeb) ...[
                _hDivider(),
                _linkRow('2D 场景预览', () {
                  widget.onOpenPreview?.call(false);
                  _close();
                }),
                _linkRow('3D 场景预览', () {
                  widget.onOpenPreview?.call(true);
                  _close();
                }),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(text, style: DuelType.sans(9, color: DuelColors.textGhost)),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    // 整行可点（老实现就是整行切换，保持调用方与既有测试的交互习惯）。
    return DuelHit(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 40,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 12,
              child: Text(
                label,
                style: DuelType.sans(10, color: DuelColors.textBody),
              ),
            ),
            Positioned(
              right: 0,
              top: 9,
              child: _DuelSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(
    String label,
    List<String> options,
    int selected,
    ValueChanged<int> onSelected, {
    double width = 54,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DuelType.sans(10, color: DuelColors.textBody),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: DuelHit(
                onTap: () {
                  if (i == selected) return;
                  DuelSounds.tabSwitch();
                  onSelected(i);
                },
                child: Container(
                  width: width,
                  height: 26,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? DuelColors.accent
                        : const Color(0xFF0A121C),
                    border: Border.all(
                      color: i == selected
                          ? DuelColors.accent
                          : DuelColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: DuelType.sans(
                      9,
                      color: i == selected
                          ? DuelColors.inkOnAccent
                          : DuelColors.textMuted,
                      weight: i == selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noteLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(text, style: DuelType.sans(8, color: DuelColors.textGhost)),
    );
  }

  Widget _hDivider() => Container(height: 1, color: DuelColors.divider);

  Widget _linkRow(String label, VoidCallback onTap) {
    return SizedBox(
      height: 26,
      child: DuelHit(
        onTap: onTap,
        child: Row(
          children: [
            Text(label, style: DuelType.sans(9, color: DuelColors.textMuted)),
            const Spacer(),
            Text('›', style: DuelType.sans(10, color: DuelColors.accent)),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountPane(bool loggedIn) {
    return [
      _label('当前账号', 75),
      _staticValue(75, loggedIn ? (widget.accountName ?? '已登录') : '游客'),
      _divider(109),
      _label('用户名', 127),
      _staticValue(
        127,
        loggedIn ? '@' + (widget.accountUsername ?? '') : '未登录',
      ),
      _divider(161),
      _label('登录方式', 179),
      _staticValue(179, loggedIn ? 'MyCard' : '—'),
      _note(215, loggedIn ? '退出后回到游客态，可重新登录' : '登录后可参与竞技/休闲匹配'),
    ];
  }

  Widget _footer(bool loggedIn) {
    final isAccount = _nav == 3;
    final actionLabel = isAccount ? (loggedIn ? '退出账号' : '前往登录') : '恢复默认';
    return Stack(
      children: [
        Positioned(
          left: 160,
          top: 261,
          width: 92,
          height: 28,
          child: DuelHit(
            key: const ValueKey('settings-secondary'),
            onTap: isAccount
                ? (loggedIn ? _signOut : _goLogin)
                : _restoreDefaults,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: DuelColors.borderPanel),
              ),
              alignment: Alignment.center,
              child: Text(
                actionLabel,
                style: DuelType.sans(9.5, color: DuelColors.textBody),
              ),
            ),
          ),
        ),
        Positioned(
          left: 268,
          top: 269,
          child: Text(
            '设置会保存在本机 · 云同步需登录',
            style: DuelType.sans(8, color: DuelColors.textGhost),
          ),
        ),
        Positioned(
          left: 526,
          top: 261,
          width: 92,
          height: 28,
          child: DuelHit(
            key: const ValueKey('settings-save'),
            onTap: _save,
            child: Container(
              color: DuelColors.accent,
              alignment: Alignment.center,
              child: Text(
                '保存',
                style: DuelType.sans(
                  9.5,
                  color: DuelColors.inkOnAccent,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, double top) {
    return Positioned(
      left: 160,
      top: top,
      child: Text(text, style: DuelType.sans(10, color: DuelColors.textBody)),
    );
  }

  Widget _staticValue(double top, String text) {
    return Positioned(
      left: 348,
      top: top,
      width: 270,
      child: Text(text, style: DuelType.sans(9.5, color: DuelColors.textMuted)),
    );
  }

  Widget _note(double top, String text) {
    return Positioned(
      left: 160,
      top: top,
      width: 440,
      child: Text(text, style: DuelType.sans(8, color: DuelColors.textGhost)),
    );
  }

  /// AI 设置页（设计稿 03g）：来源 + 本地推理模型。
  List<Widget> _aiPane() {
    final local = !_aiServer233;
    return [
      _label('AI 来源', 67),
      _aiOption(160, 83, 172, '本地 AI', local, () {
        setState(() => _aiServer233 = false);
      }),
      _aiOption(340, 83, 278, '233 服 AI（远端）', !local, () {
        setState(() => _aiServer233 = true);
      }),
      _note(121, '本地 AI 离线运行；233 服 AI 需联网，无需选择推理模型'),
      _divider(145),
      if (local) ...[
        _label('推理模型', 155),
        _aiOption(160, 171, 146, '端侧模型', _aiModel == AiModel.onDevice, () {
          setState(() => _aiModel = AiModel.onDevice);
        }),
        _aiOption(314, 171, 146, '规则 AI', _aiModel == AiModel.rule, () {
          setState(() => _aiModel = AiModel.rule);
        }),
        _aiOption(468, 171, 146, '远端模型', _aiModel == AiModel.remote, () {
          setState(() => _aiModel = AiModel.remote);
        }),
        _note(209, '端侧 = 本地 ygo-agent 神经网络（首次加载约 17MB 模型）'),
        _divider(233),
      ] else
        Positioned(
          left: 160,
          top: 243,
          width: 458,
          child: Text(
            '选择「233 服 AI」时无需选择推理模型，模型由服务端决定',
            style: DuelType.sans(8.5, color: DuelColors.accent),
          ),
        ),
    ];
  }

  Widget _aiOption(
    double left,
    double top,
    double width,
    String text,
    bool selected,
    VoidCallback onTap,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: 30,
      child: DuelHit(
        onTap: () {
          if (selected) return;
          DuelSounds.tabSwitch();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? DuelColors.surfaceSelected
                : const Color(0xFF0A121C),
            border: Border.all(
              color: selected ? DuelColors.accent : DuelColors.border,
            ),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: DuelType.sans(
              10,
              color: selected ? DuelColors.accent : DuelColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(double top) {
    return Positioned(
      left: 160,
      top: top,
      width: 458,
      child: Container(height: 1, color: DuelColors.divider),
    );
  }
}

class _DuelSwitch extends StatelessWidget {
  const _DuelSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DuelHit(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 22,
        decoration: BoxDecoration(
          color: value ? DuelColors.accent : const Color(0xFF1A2C3E),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 120),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? DuelColors.inkOnAccent : const Color(0xFF8A93A8),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
