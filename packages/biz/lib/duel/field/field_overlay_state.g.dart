// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_overlay_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 场地浮层的 Notifier：持有全部本地交互（点选/检视/开关浮层）逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

@ProviderFor(FieldOverlayNotifier)
final fieldOverlayProvider = FieldOverlayNotifierProvider._();

/// 场地浮层的 Notifier：持有全部本地交互（点选/检视/开关浮层）逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
final class FieldOverlayNotifierProvider
    extends $NotifierProvider<FieldOverlayNotifier, FieldOverlayState> {
  /// 场地浮层的 Notifier：持有全部本地交互（点选/检视/开关浮层）逻辑。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
  /// override 隔离。
  FieldOverlayNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fieldOverlayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fieldOverlayNotifierHash();

  @$internal
  @override
  FieldOverlayNotifier create() => FieldOverlayNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FieldOverlayState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FieldOverlayState>(value),
    );
  }
}

String _$fieldOverlayNotifierHash() =>
    r'7d4e867c9ec83a703fd7573d49e960e17b3dd7c7';

/// 场地浮层的 Notifier：持有全部本地交互（点选/检视/开关浮层）逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

abstract class _$FieldOverlayNotifier extends $Notifier<FieldOverlayState> {
  FieldOverlayState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FieldOverlayState, FieldOverlayState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FieldOverlayState, FieldOverlayState>,
              FieldOverlayState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
