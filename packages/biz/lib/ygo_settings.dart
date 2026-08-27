import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ygo_settings.g.dart';

/// 决斗相关的全局设置项（跨对局持久化）。
///
/// 契约定义在 biz（共享层）而非 duel_room2，使「设置 UI / 持久化包」
/// 与「对局包」能双向消费而不产生包间依赖：
/// - duel_room2 只依赖 biz 里的 provider 契约，不依赖设置包；
/// - 具体持久化与设置弹窗由宿主 app（uniygopro）经
///   [registerAppLevelOverrides]（见 service_providers.dart）注入
///   modules/ygo_settings 的实现。
class YgoSettings {
  const YgoSettings({
    this.showChain1Animation = false,
    this.autoMonsterPosition = false,
    this.autoSpellTrapPosition = false,
  });

  /// 连锁 1 也显示连锁叠层动画（默认只显示 2 张及以上）。
  final bool showChain1Animation;

  /// 自动选择怪兽卡放置位置（MSG_SELECT_PLACE 时自动回包）。
  final bool autoMonsterPosition;

  /// 自动选择魔陷卡放置位置（MSG_SELECT_PLACE 时自动回包）。
  final bool autoSpellTrapPosition;

  static const defaults = YgoSettings();

  YgoSettings copyWith({
    bool? showChain1Animation,
    bool? autoMonsterPosition,
    bool? autoSpellTrapPosition,
  }) {
    return YgoSettings(
      showChain1Animation: showChain1Animation ?? this.showChain1Animation,
      autoMonsterPosition: autoMonsterPosition ?? this.autoMonsterPosition,
      autoSpellTrapPosition:
          autoSpellTrapPosition ?? this.autoSpellTrapPosition,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is YgoSettings &&
      other.showChain1Animation == showChain1Animation &&
      other.autoMonsterPosition == autoMonsterPosition &&
      other.autoSpellTrapPosition == autoSpellTrapPosition;

  @override
  int get hashCode => Object.hash(
    showChain1Animation,
    autoMonsterPosition,
    autoSpellTrapPosition,
  );
}

/// 设置状态的 Notifier 基类：默认纯内存、无持久化。
/// 宿主 app 通过 [ygoSettingsProvider.overrideWith] 注入带
/// SharedPreferences 持久化的实现（见 modules/ygo_settings）。
///
/// keepAlive: true 保持手写 NotifierProvider 语义（全局设置常驻）。
@Riverpod(keepAlive: true)
class YgoSettingsNotifier extends _$YgoSettingsNotifier {
  @override
  YgoSettings build() => YgoSettings.defaults;

  void setShowChain1Animation(bool value) =>
      state = state.copyWith(showChain1Animation: value);

  void setAutoMonsterPosition(bool value) =>
      state = state.copyWith(autoMonsterPosition: value);

  void setAutoSpellTrapPosition(bool value) =>
      state = state.copyWith(autoSpellTrapPosition: value);
}

/// 打开全局设置弹窗的函数指针。默认 null（对局包不感知设置 UI 的具体实现），
/// 由宿主 app 注入 apps/duel_settings 的弹窗。
typedef ShowYgoSettingsDialog = void Function(BuildContext context);

/// 打开全局设置弹窗的函数指针 provider。默认 null，由宿主 app override 注入。
@Riverpod(keepAlive: true)
ShowYgoSettingsDialog? showYgoSettingsDialog(Ref ref) => null;
