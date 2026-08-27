// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'select_window_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
/// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

@ProviderFor(SelectWindowNotifier)
final selectWindowProvider = SelectWindowNotifierProvider._();

/// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
/// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
final class SelectWindowNotifierProvider
    extends $NotifierProvider<SelectWindowNotifier, SelectWindowState> {
  /// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
  /// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
  /// override 隔离。
  SelectWindowNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectWindowNotifierHash();

  @$internal
  @override
  SelectWindowNotifier create() => SelectWindowNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectWindowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectWindowState>(value),
    );
  }
}

String _$selectWindowNotifierHash() =>
    r'9d746ea87f1223b75007e9bf4d55deec08050e87';

/// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
/// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

abstract class _$SelectWindowNotifier extends $Notifier<SelectWindowState> {
  SelectWindowState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SelectWindowState, SelectWindowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SelectWindowState, SelectWindowState>,
              SelectWindowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
