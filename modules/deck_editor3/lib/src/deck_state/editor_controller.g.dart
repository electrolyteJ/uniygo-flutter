// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 组卡编辑器控制器。

@ProviderFor(EditorController)
final editorControllerProvider = EditorControllerProvider._();

/// 组卡编辑器控制器。
final class EditorControllerProvider
    extends $NotifierProvider<EditorController, EditorState> {
  /// 组卡编辑器控制器。
  EditorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorControllerHash();

  @$internal
  @override
  EditorController create() => EditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditorState>(value),
    );
  }
}

String _$editorControllerHash() => r'a4831b178205642ccb4aa8133b6a8a8d96462b4f';

/// 组卡编辑器控制器。

abstract class _$EditorController extends $Notifier<EditorState> {
  EditorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditorState, EditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EditorState, EditorState>,
              EditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
