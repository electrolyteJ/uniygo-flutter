// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_confirm_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 卡片确认的 Notifier：持有确认呈现逻辑与自动消退计时器。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

@ProviderFor(CardConfirmNotifier)
final cardConfirmProvider = CardConfirmNotifierProvider._();

/// 卡片确认的 Notifier：持有确认呈现逻辑与自动消退计时器。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
final class CardConfirmNotifierProvider
    extends $NotifierProvider<CardConfirmNotifier, CardConfirmState> {
  /// 卡片确认的 Notifier：持有确认呈现逻辑与自动消退计时器。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
  /// override 隔离。
  CardConfirmNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardConfirmProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardConfirmNotifierHash();

  @$internal
  @override
  CardConfirmNotifier create() => CardConfirmNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CardConfirmState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CardConfirmState>(value),
    );
  }
}

String _$cardConfirmNotifierHash() =>
    r'ed1d4e4a07caf3467fd767f82f8531944b4d04a1';

/// 卡片确认的 Notifier：持有确认呈现逻辑与自动消退计时器。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

abstract class _$CardConfirmNotifier extends $Notifier<CardConfirmState> {
  CardConfirmState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CardConfirmState, CardConfirmState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CardConfirmState, CardConfirmState>,
              CardConfirmState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
