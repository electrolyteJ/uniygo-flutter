// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duel_field_derived.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。

@ProviderFor(phaseActions)
final phaseActionsProvider = PhaseActionsProvider._();

/// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。

final class PhaseActionsProvider
    extends
        $FunctionalProvider<
          List<PlaymatResolvedAction>,
          List<PlaymatResolvedAction>,
          List<PlaymatResolvedAction>
        >
    with $Provider<List<PlaymatResolvedAction>> {
  /// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。
  PhaseActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phaseActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phaseActionsHash();

  @$internal
  @override
  $ProviderElement<List<PlaymatResolvedAction>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PlaymatResolvedAction> create(Ref ref) {
    return phaseActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PlaymatResolvedAction> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PlaymatResolvedAction>>(value),
    );
  }
}

String _$phaseActionsHash() => r'5758c77c0f8d6329b39aef87d4908f69a9c19b0e';

/// 手牌选中卡的操作菜单条目。

@ProviderFor(handActionMenu)
final handActionMenuProvider = HandActionMenuProvider._();

/// 手牌选中卡的操作菜单条目。

final class HandActionMenuProvider
    extends
        $FunctionalProvider<
          List<ActionMenuEntry>,
          List<ActionMenuEntry>,
          List<ActionMenuEntry>
        >
    with $Provider<List<ActionMenuEntry>> {
  /// 手牌选中卡的操作菜单条目。
  HandActionMenuProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'handActionMenuProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$handActionMenuHash();

  @$internal
  @override
  $ProviderElement<List<ActionMenuEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ActionMenuEntry> create(Ref ref) {
    return handActionMenu(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ActionMenuEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ActionMenuEntry>>(value),
    );
  }
}

String _$handActionMenuHash() => r'3c135eec1d72e15a1dc1fe0d57af9150794b1a6f';

/// 阶段菜单条目（阶段灯点击后的弹层内容）。

@ProviderFor(phaseActionMenu)
final phaseActionMenuProvider = PhaseActionMenuProvider._();

/// 阶段菜单条目（阶段灯点击后的弹层内容）。

final class PhaseActionMenuProvider
    extends
        $FunctionalProvider<
          List<ActionMenuEntry>,
          List<ActionMenuEntry>,
          List<ActionMenuEntry>
        >
    with $Provider<List<ActionMenuEntry>> {
  /// 阶段菜单条目（阶段灯点击后的弹层内容）。
  PhaseActionMenuProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phaseActionMenuProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phaseActionMenuHash();

  @$internal
  @override
  $ProviderElement<List<ActionMenuEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ActionMenuEntry> create(Ref ref) {
    return phaseActionMenu(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ActionMenuEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ActionMenuEntry>>(value),
    );
  }
}

String _$phaseActionMenuHash() => r'0811b86e2a63d43673ec53b5dc9e4c443f8f4f8b';

/// 场上选中卡的操作菜单条目。

@ProviderFor(fieldActionMenu)
final fieldActionMenuProvider = FieldActionMenuProvider._();

/// 场上选中卡的操作菜单条目。

final class FieldActionMenuProvider
    extends
        $FunctionalProvider<
          List<ActionMenuEntry>,
          List<ActionMenuEntry>,
          List<ActionMenuEntry>
        >
    with $Provider<List<ActionMenuEntry>> {
  /// 场上选中卡的操作菜单条目。
  FieldActionMenuProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fieldActionMenuProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fieldActionMenuHash();

  @$internal
  @override
  $ProviderElement<List<ActionMenuEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ActionMenuEntry> create(Ref ref) {
    return fieldActionMenu(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ActionMenuEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ActionMenuEntry>>(value),
    );
  }
}

String _$fieldActionMenuHash() => r'5efa8886583343edf3773a0dcd233ce6416d3c8a';

/// 区域浏览器（墓地/除外/额外）内展示的卡列表。

@ProviderFor(zoneBrowserEntries)
final zoneBrowserEntriesProvider = ZoneBrowserEntriesFamily._();

/// 区域浏览器（墓地/除外/额外）内展示的卡列表。

final class ZoneBrowserEntriesProvider
    extends
        $FunctionalProvider<
          List<ZoneBrowserCardEntry>,
          List<ZoneBrowserCardEntry>,
          List<ZoneBrowserCardEntry>
        >
    with $Provider<List<ZoneBrowserCardEntry>> {
  /// 区域浏览器（墓地/除外/额外）内展示的卡列表。
  ZoneBrowserEntriesProvider._({
    required ZoneBrowserEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'zoneBrowserEntriesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$zoneBrowserEntriesHash();

  @override
  String toString() {
    return r'zoneBrowserEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<ZoneBrowserCardEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ZoneBrowserCardEntry> create(Ref ref) {
    final argument = this.argument as String;
    return zoneBrowserEntries(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ZoneBrowserCardEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ZoneBrowserCardEntry>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ZoneBrowserEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$zoneBrowserEntriesHash() =>
    r'6efcb51365ce8063452d67977b26f41d1fc61baa';

/// 区域浏览器（墓地/除外/额外）内展示的卡列表。

final class ZoneBrowserEntriesFamily extends $Family
    with $FunctionalFamilyOverride<List<ZoneBrowserCardEntry>, String> {
  ZoneBrowserEntriesFamily._()
    : super(
        retry: null,
        name: r'zoneBrowserEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 区域浏览器（墓地/除外/额外）内展示的卡列表。

  ZoneBrowserEntriesProvider call(String zoneKey) =>
      ZoneBrowserEntriesProvider._(argument: zoneKey, from: this);

  @override
  String toString() => r'zoneBrowserEntriesProvider';
}

/// 区域浏览器内选中卡的操作菜单条目。

@ProviderFor(zoneBrowserActions)
final zoneBrowserActionsProvider = ZoneBrowserActionsFamily._();

/// 区域浏览器内选中卡的操作菜单条目。

final class ZoneBrowserActionsProvider
    extends
        $FunctionalProvider<
          List<ActionMenuEntry>,
          List<ActionMenuEntry>,
          List<ActionMenuEntry>
        >
    with $Provider<List<ActionMenuEntry>> {
  /// 区域浏览器内选中卡的操作菜单条目。
  ZoneBrowserActionsProvider._({
    required ZoneBrowserActionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'zoneBrowserActionsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$zoneBrowserActionsHash();

  @override
  String toString() {
    return r'zoneBrowserActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<ActionMenuEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ActionMenuEntry> create(Ref ref) {
    final argument = this.argument as String;
    return zoneBrowserActions(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ActionMenuEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ActionMenuEntry>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ZoneBrowserActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$zoneBrowserActionsHash() =>
    r'ef3b7e3edb37392d408470f2d5e9e0b7df89b273';

/// 区域浏览器内选中卡的操作菜单条目。

final class ZoneBrowserActionsFamily extends $Family
    with $FunctionalFamilyOverride<List<ActionMenuEntry>, String> {
  ZoneBrowserActionsFamily._()
    : super(
        retry: null,
        name: r'zoneBrowserActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 区域浏览器内选中卡的操作菜单条目。

  ZoneBrowserActionsProvider call(String zoneKey) =>
      ZoneBrowserActionsProvider._(argument: zoneKey, from: this);

  @override
  String toString() => r'zoneBrowserActionsProvider';
}

/// 区域浏览器的「隐藏数量」展示值。

@ProviderFor(zoneHiddenCount)
final zoneHiddenCountProvider = ZoneHiddenCountFamily._();

/// 区域浏览器的「隐藏数量」展示值。

final class ZoneHiddenCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 区域浏览器的「隐藏数量」展示值。
  ZoneHiddenCountProvider._({
    required ZoneHiddenCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'zoneHiddenCountProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$zoneHiddenCountHash();

  @override
  String toString() {
    return r'zoneHiddenCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as String;
    return zoneHiddenCount(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ZoneHiddenCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$zoneHiddenCountHash() => r'f4c0b9bdf4a38fe93023946b9b483073d39ba2cc';

/// 区域浏览器的「隐藏数量」展示值。

final class ZoneHiddenCountFamily extends $Family
    with $FunctionalFamilyOverride<int, String> {
  ZoneHiddenCountFamily._()
    : super(
        retry: null,
        name: r'zoneHiddenCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 区域浏览器的「隐藏数量」展示值。

  ZoneHiddenCountProvider call(String zoneKey) =>
      ZoneHiddenCountProvider._(argument: zoneKey, from: this);

  @override
  String toString() => r'zoneHiddenCountProvider';
}

/// 出现更高优先级选择窗口（非阶段指令）时，本地弹层是否应当让位。

@ProviderFor(needsHigherPriorityDismiss)
final needsHigherPriorityDismissProvider =
    NeedsHigherPriorityDismissProvider._();

/// 出现更高优先级选择窗口（非阶段指令）时，本地弹层是否应当让位。

final class NeedsHigherPriorityDismissProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 出现更高优先级选择窗口（非阶段指令）时，本地弹层是否应当让位。
  NeedsHigherPriorityDismissProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'needsHigherPriorityDismissProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$needsHigherPriorityDismissHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return needsHigherPriorityDismiss(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$needsHigherPriorityDismissHash() =>
    r'ead4c512f7f4b1171fba573a0ddc7674a2e9be80';

/// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
/// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
///
/// 仅覆盖主阶段 idle 指令窗口：战斗指令窗口（MSG_SELECT_BATTLE_CMD）的
/// action 是攻击，attacker 均在场上，不涉及墓地/除外/额外发动；
/// 战斗中的快速效果走 MSG_SELECT_CHAIN，属另一套交互，不在此处理。

@ProviderFor(activatableZoneKeys)
final activatableZoneKeysProvider = ActivatableZoneKeysProvider._();

/// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
/// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
///
/// 仅覆盖主阶段 idle 指令窗口：战斗指令窗口（MSG_SELECT_BATTLE_CMD）的
/// action 是攻击，attacker 均在场上，不涉及墓地/除外/额外发动；
/// 战斗中的快速效果走 MSG_SELECT_CHAIN，属另一套交互，不在此处理。

final class ActivatableZoneKeysProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
  /// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
  ///
  /// 仅覆盖主阶段 idle 指令窗口：战斗指令窗口（MSG_SELECT_BATTLE_CMD）的
  /// action 是攻击，attacker 均在场上，不涉及墓地/除外/额外发动；
  /// 战斗中的快速效果走 MSG_SELECT_CHAIN，属另一套交互，不在此处理。
  ActivatableZoneKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activatableZoneKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activatableZoneKeysHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return activatableZoneKeys(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$activatableZoneKeysHash() =>
    r'34da74cf78871a93adebfebb0a9b1a7f4aee895c';

/// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
/// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。

@ProviderFor(selectPromptMode)
final selectPromptModeProvider = SelectPromptModeProvider._();

/// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
/// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。

final class SelectPromptModeProvider
    extends
        $FunctionalProvider<
          SelectPromptMode,
          SelectPromptMode,
          SelectPromptMode
        >
    with $Provider<SelectPromptMode> {
  /// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
  /// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。
  SelectPromptModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectPromptModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectPromptModeHash();

  @$internal
  @override
  $ProviderElement<SelectPromptMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SelectPromptMode create(Ref ref) {
    return selectPromptMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectPromptMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectPromptMode>(value),
    );
  }
}

String _$selectPromptModeHash() => r'cf2dc46344106fb2e06715df36578cd65b23daa8';
