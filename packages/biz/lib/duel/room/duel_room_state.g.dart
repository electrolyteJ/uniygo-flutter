// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duel_room_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 房间级连接生命周期钩子：房间 ProviderScope 销毁时兜底断开 socket。
///
/// 应用级单例 duelService 的连接不随房间页面回收，若不主动断开，
/// 系统返回等方式离开房间后服务器会一直保留座位。房间页需在本 scope 内
/// `ref.watch` 本 provider 使其创建，scope 销毁即触发 onDispose。
/// [IDuelService.disconnect] 幂等，与 duel_room_exit.dart 中显式的
/// disconnect 重复调用是安全的。

@ProviderFor(roomConnectionLifetime)
final roomConnectionLifetimeProvider = RoomConnectionLifetimeProvider._();

/// 房间级连接生命周期钩子：房间 ProviderScope 销毁时兜底断开 socket。
///
/// 应用级单例 duelService 的连接不随房间页面回收，若不主动断开，
/// 系统返回等方式离开房间后服务器会一直保留座位。房间页需在本 scope 内
/// `ref.watch` 本 provider 使其创建，scope 销毁即触发 onDispose。
/// [IDuelService.disconnect] 幂等，与 duel_room_exit.dart 中显式的
/// disconnect 重复调用是安全的。

final class RoomConnectionLifetimeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// 房间级连接生命周期钩子：房间 ProviderScope 销毁时兜底断开 socket。
  ///
  /// 应用级单例 duelService 的连接不随房间页面回收，若不主动断开，
  /// 系统返回等方式离开房间后服务器会一直保留座位。房间页需在本 scope 内
  /// `ref.watch` 本 provider 使其创建，scope 销毁即触发 onDispose。
  /// [IDuelService.disconnect] 幂等，与 duel_room_exit.dart 中显式的
  /// disconnect 重复调用是安全的。
  RoomConnectionLifetimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomConnectionLifetimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomConnectionLifetimeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return roomConnectionLifetime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$roomConnectionLifetimeHash() =>
    r'0df8489854870a44e53d312952edfc87fba9b437';

/// 决斗房间控制器（Riverpod 版 DuelRoomStore）。
///
/// 与 Provider 版的差异：
/// - 不再持有 BuildContext：导航由页面 `ref.listen(stage)` 负责，
///   准备失败的提示通过 [toggleReady] 的返回值交给页面弹 SnackBar。
/// - 流订阅从 `bind(context)` 改为 [start]（由页面在 connect 完成后调用），
///   取消逻辑收敛在 `ref.onDispose`。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；房间隔离由房间
/// ProviderScope 的 overrideWith 提供。

@ProviderFor(DuelRoomNotifier)
final duelRoomProvider = DuelRoomNotifierProvider._();

/// 决斗房间控制器（Riverpod 版 DuelRoomStore）。
///
/// 与 Provider 版的差异：
/// - 不再持有 BuildContext：导航由页面 `ref.listen(stage)` 负责，
///   准备失败的提示通过 [toggleReady] 的返回值交给页面弹 SnackBar。
/// - 流订阅从 `bind(context)` 改为 [start]（由页面在 connect 完成后调用），
///   取消逻辑收敛在 `ref.onDispose`。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；房间隔离由房间
/// ProviderScope 的 overrideWith 提供。
final class DuelRoomNotifierProvider
    extends $NotifierProvider<DuelRoomNotifier, DuelRoomState> {
  /// 决斗房间控制器（Riverpod 版 DuelRoomStore）。
  ///
  /// 与 Provider 版的差异：
  /// - 不再持有 BuildContext：导航由页面 `ref.listen(stage)` 负责，
  ///   准备失败的提示通过 [toggleReady] 的返回值交给页面弹 SnackBar。
  /// - 流订阅从 `bind(context)` 改为 [start]（由页面在 connect 完成后调用），
  ///   取消逻辑收敛在 `ref.onDispose`。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；房间隔离由房间
  /// ProviderScope 的 overrideWith 提供。
  DuelRoomNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duelRoomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duelRoomNotifierHash();

  @$internal
  @override
  DuelRoomNotifier create() => DuelRoomNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuelRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuelRoomState>(value),
    );
  }
}

String _$duelRoomNotifierHash() => r'dee583b0a540f714f1319745e62a2e9401072732';

/// 决斗房间控制器（Riverpod 版 DuelRoomStore）。
///
/// 与 Provider 版的差异：
/// - 不再持有 BuildContext：导航由页面 `ref.listen(stage)` 负责，
///   准备失败的提示通过 [toggleReady] 的返回值交给页面弹 SnackBar。
/// - 流订阅从 `bind(context)` 改为 [start]（由页面在 connect 完成后调用），
///   取消逻辑收敛在 `ref.onDispose`。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；房间隔离由房间
/// ProviderScope 的 overrideWith 提供。

abstract class _$DuelRoomNotifier extends $Notifier<DuelRoomState> {
  DuelRoomState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DuelRoomState, DuelRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DuelRoomState, DuelRoomState>,
              DuelRoomState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
