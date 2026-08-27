// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duel_chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对局/房间聊天控制器（Riverpod 版 DuelChatStore）。
///
/// 发送者名字解析从页面闭包改为控制器内 `ref.read(duelRoomProvider)`，
/// 不再依赖页面把 players 传进来。
///
/// keepAlive: true 保持与手写 NotifierProvider 一致的常驻语义，
/// 房间级隔离仍由房间 ProviderScope 的 overrideWith 提供。

@ProviderFor(DuelChatNotifier)
final duelChatProvider = DuelChatNotifierProvider._();

/// 对局/房间聊天控制器（Riverpod 版 DuelChatStore）。
///
/// 发送者名字解析从页面闭包改为控制器内 `ref.read(duelRoomProvider)`，
/// 不再依赖页面把 players 传进来。
///
/// keepAlive: true 保持与手写 NotifierProvider 一致的常驻语义，
/// 房间级隔离仍由房间 ProviderScope 的 overrideWith 提供。
final class DuelChatNotifierProvider
    extends $NotifierProvider<DuelChatNotifier, DuelChatState> {
  /// 对局/房间聊天控制器（Riverpod 版 DuelChatStore）。
  ///
  /// 发送者名字解析从页面闭包改为控制器内 `ref.read(duelRoomProvider)`，
  /// 不再依赖页面把 players 传进来。
  ///
  /// keepAlive: true 保持与手写 NotifierProvider 一致的常驻语义，
  /// 房间级隔离仍由房间 ProviderScope 的 overrideWith 提供。
  DuelChatNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duelChatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duelChatNotifierHash();

  @$internal
  @override
  DuelChatNotifier create() => DuelChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuelChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuelChatState>(value),
    );
  }
}

String _$duelChatNotifierHash() => r'58b7040bcded6b0b9798f5fbf18202ddc8e7eac6';

/// 对局/房间聊天控制器（Riverpod 版 DuelChatStore）。
///
/// 发送者名字解析从页面闭包改为控制器内 `ref.read(duelRoomProvider)`，
/// 不再依赖页面把 players 传进来。
///
/// keepAlive: true 保持与手写 NotifierProvider 一致的常驻语义，
/// 房间级隔离仍由房间 ProviderScope 的 overrideWith 提供。

abstract class _$DuelChatNotifier extends $Notifier<DuelChatState> {
  DuelChatState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DuelChatState, DuelChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DuelChatState, DuelChatState>,
              DuelChatState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
