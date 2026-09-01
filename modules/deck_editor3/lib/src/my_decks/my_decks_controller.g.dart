// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_decks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 我的卡组（本地，ygo_deck_mycard）控制器。

@ProviderFor(MyDecksController)
final myDecksControllerProvider = MyDecksControllerProvider._();

/// 我的卡组（本地，ygo_deck_mycard）控制器。
final class MyDecksControllerProvider
    extends $NotifierProvider<MyDecksController, AsyncValue<List<DeckInfo>>> {
  /// 我的卡组（本地，ygo_deck_mycard）控制器。
  MyDecksControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myDecksControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myDecksControllerHash();

  @$internal
  @override
  MyDecksController create() => MyDecksController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<DeckInfo>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<DeckInfo>>>(value),
    );
  }
}

String _$myDecksControllerHash() => r'a259e72a65ee63bc6358f536a9660cdcaa7698d4';

/// 我的卡组（本地，ygo_deck_mycard）控制器。

abstract class _$MyDecksController
    extends $Notifier<AsyncValue<List<DeckInfo>>> {
  AsyncValue<List<DeckInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<DeckInfo>>, AsyncValue<List<DeckInfo>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DeckInfo>>,
                AsyncValue<List<DeckInfo>>
              >,
              AsyncValue<List<DeckInfo>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
