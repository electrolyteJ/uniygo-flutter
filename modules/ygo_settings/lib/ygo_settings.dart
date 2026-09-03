import 'package:biz/service_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.0：Override 类型不再从主库导出，需经 misc.dart 引入。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_settings/ygo_settings_dialog.dart';

export 'duel_room_renderer.dart';

const _kChain1 = 'duel_settings.show_chain1_animation';
const _kMonster = 'duel_settings.auto_monster_position';
const _kSpellTrap = 'duel_settings.auto_spell_trap_position';
const _kSpectateJump = 'duel_settings.spectate_jump_to_current';
const _kReplaySpeed = 'duel_settings.replay_speed_factor';


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
      spectateJumpToCurrent:
          prefs.getBool(_kSpectateJump) ?? state.spectateJumpToCurrent,
      replaySpeedFactor:
          prefs.getDouble(_kReplaySpeed) ?? state.replaySpeedFactor,
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

  @override
  void setSpectateJumpToCurrent(bool value) {
    super.setSpectateJumpToCurrent(value);
    _persist(_kSpectateJump, value);
  }

  @override
  void setReplaySpeedFactor(double value) {
    super.setReplaySpeedFactor(value);
    _persistDouble(_kReplaySpeed, value);
  }

  Future<void> _persist(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
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
      onSpectateJumpChanged: notifier.setSpectateJumpToCurrent,
      onReplaySpeedFactorChanged: notifier.setReplaySpeedFactor,
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
      onSpectateJumpChanged: notifier.setSpectateJumpToCurrent,
      onReplaySpeedFactorChanged: notifier.setReplaySpeedFactor,
    ),
  );
}

/// 宿主 app 在应用级 ProviderScope/容器注册的 overrides：
/// 把持久化实现与设置弹窗注入 biz 里的 provider 契约。
final ygoSettingsOverrides = <Override>[
  ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
  showYgoSettingsDialogProvider.overrideWithValue(showYgoSettingsDialog),
];