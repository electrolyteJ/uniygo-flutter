// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ygo_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置状态的 Notifier 基类：默认纯内存、无持久化。
/// 宿主 app 通过 [ygoSettingsProvider.overrideWith] 注入带
/// SharedPreferences 持久化的实现（见 modules/ygo_settings）。
///
/// keepAlive: true 保持手写 NotifierProvider 语义（全局设置常驻）。

@ProviderFor(YgoSettingsNotifier)
final ygoSettingsProvider = YgoSettingsNotifierProvider._();

/// 设置状态的 Notifier 基类：默认纯内存、无持久化。
/// 宿主 app 通过 [ygoSettingsProvider.overrideWith] 注入带
/// SharedPreferences 持久化的实现（见 modules/ygo_settings）。
///
/// keepAlive: true 保持手写 NotifierProvider 语义（全局设置常驻）。
final class YgoSettingsNotifierProvider
    extends $NotifierProvider<YgoSettingsNotifier, YgoSettings> {
  /// 设置状态的 Notifier 基类：默认纯内存、无持久化。
  /// 宿主 app 通过 [ygoSettingsProvider.overrideWith] 注入带
  /// SharedPreferences 持久化的实现（见 modules/ygo_settings）。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义（全局设置常驻）。
  YgoSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ygoSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ygoSettingsNotifierHash();

  @$internal
  @override
  YgoSettingsNotifier create() => YgoSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YgoSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YgoSettings>(value),
    );
  }
}

String _$ygoSettingsNotifierHash() =>
    r'f6d8f4e6e4cc4f03f3a25f817001aa48c8befff4';

/// 设置状态的 Notifier 基类：默认纯内存、无持久化。
/// 宿主 app 通过 [ygoSettingsProvider.overrideWith] 注入带
/// SharedPreferences 持久化的实现（见 modules/ygo_settings）。
///
/// keepAlive: true 保持手写 NotifierProvider 语义（全局设置常驻）。

abstract class _$YgoSettingsNotifier extends $Notifier<YgoSettings> {
  YgoSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<YgoSettings, YgoSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<YgoSettings, YgoSettings>,
              YgoSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 打开全局设置弹窗的函数指针 provider。默认 null，由宿主 app override 注入。

@ProviderFor(showYgoSettingsDialog)
final showYgoSettingsDialogProvider = ShowYgoSettingsDialogProvider._();

/// 打开全局设置弹窗的函数指针 provider。默认 null，由宿主 app override 注入。

final class ShowYgoSettingsDialogProvider
    extends
        $FunctionalProvider<
          ShowYgoSettingsDialog?,
          ShowYgoSettingsDialog?,
          ShowYgoSettingsDialog?
        >
    with $Provider<ShowYgoSettingsDialog?> {
  /// 打开全局设置弹窗的函数指针 provider。默认 null，由宿主 app override 注入。
  ShowYgoSettingsDialogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showYgoSettingsDialogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showYgoSettingsDialogHash();

  @$internal
  @override
  $ProviderElement<ShowYgoSettingsDialog?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShowYgoSettingsDialog? create(Ref ref) {
    return showYgoSettingsDialog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowYgoSettingsDialog? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowYgoSettingsDialog?>(value),
    );
  }
}

String _$showYgoSettingsDialogHash() =>
    r'5019cf8a4a49bd7a27192c6ec0987b37adc7153c';
