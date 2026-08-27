// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'square_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 卡组市场控制器：MDPro3 卡组广场（分页/搜索/排序）。

@ProviderFor(SquareController)
final squareControllerProvider = SquareControllerProvider._();

/// 卡组市场控制器：MDPro3 卡组广场（分页/搜索/排序）。
final class SquareControllerProvider
    extends $NotifierProvider<SquareController, SquareState> {
  /// 卡组市场控制器：MDPro3 卡组广场（分页/搜索/排序）。
  SquareControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'squareControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$squareControllerHash();

  @$internal
  @override
  SquareController create() => SquareController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SquareState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SquareState>(value),
    );
  }
}

String _$squareControllerHash() => r'ee5d23f748cd7ec6083a0cf5976e09588d334a33';

/// 卡组市场控制器：MDPro3 卡组广场（分页/搜索/排序）。

abstract class _$SquareController extends $Notifier<SquareState> {
  SquareState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SquareState, SquareState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SquareState, SquareState>,
              SquareState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
