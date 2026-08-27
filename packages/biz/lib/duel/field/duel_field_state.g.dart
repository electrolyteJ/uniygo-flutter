// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duel_field_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

@ProviderFor(DuelFieldNotifier)
final duelFieldProvider = DuelFieldNotifierProvider._();

/// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
final class DuelFieldNotifierProvider
    extends $NotifierProvider<DuelFieldNotifier, DuelFieldState> {
  /// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
  /// override 隔离。
  DuelFieldNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duelFieldProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duelFieldNotifierHash();

  @$internal
  @override
  DuelFieldNotifier create() => DuelFieldNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuelFieldState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuelFieldState>(value),
    );
  }
}

String _$duelFieldNotifierHash() => r'251f2dbdc4890637ebc6ad4e1c1dbceebe478f2b';

/// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

abstract class _$DuelFieldNotifier extends $Notifier<DuelFieldState> {
  DuelFieldState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DuelFieldState, DuelFieldState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DuelFieldState, DuelFieldState>,
              DuelFieldState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
