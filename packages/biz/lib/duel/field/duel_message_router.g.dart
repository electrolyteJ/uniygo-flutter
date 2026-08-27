// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duel_message_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 服务器消息路由器（按房间 ProviderScope 隔离）。
///
/// 取代原 DuelFieldController 的「消息分发」职责：在
/// duelServiceProvider.connect 之后调用 [DuelMessageRouter.start]，
/// 订阅对局消息流并把 MSG_* / STOC_* 分发到对应子状态 Notifier。
///
/// - 四个子状态（duelField / selectWindow / cardConfirm / fieldOverlay）
///   仍是唯一的状态持有者，写逻辑各归其 Notifier；
/// - 本 router 不持有任何 UI 状态，只做「流订阅 + 消息分发 + 音效」，
///   生命周期（取消订阅）交给 Riverpod 的 ref.onDispose；
/// - 跨状态的本地交互与菜单派生逻辑已内联到 DuelFieldPage。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

@ProviderFor(DuelMessageRouter)
final duelMessageRouterProvider = DuelMessageRouterProvider._();

/// 服务器消息路由器（按房间 ProviderScope 隔离）。
///
/// 取代原 DuelFieldController 的「消息分发」职责：在
/// duelServiceProvider.connect 之后调用 [DuelMessageRouter.start]，
/// 订阅对局消息流并把 MSG_* / STOC_* 分发到对应子状态 Notifier。
///
/// - 四个子状态（duelField / selectWindow / cardConfirm / fieldOverlay）
///   仍是唯一的状态持有者，写逻辑各归其 Notifier；
/// - 本 router 不持有任何 UI 状态，只做「流订阅 + 消息分发 + 音效」，
///   生命周期（取消订阅）交给 Riverpod 的 ref.onDispose；
/// - 跨状态的本地交互与菜单派生逻辑已内联到 DuelFieldPage。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
final class DuelMessageRouterProvider
    extends $NotifierProvider<DuelMessageRouter, void> {
  /// 服务器消息路由器（按房间 ProviderScope 隔离）。
  ///
  /// 取代原 DuelFieldController 的「消息分发」职责：在
  /// duelServiceProvider.connect 之后调用 [DuelMessageRouter.start]，
  /// 订阅对局消息流并把 MSG_* / STOC_* 分发到对应子状态 Notifier。
  ///
  /// - 四个子状态（duelField / selectWindow / cardConfirm / fieldOverlay）
  ///   仍是唯一的状态持有者，写逻辑各归其 Notifier；
  /// - 本 router 不持有任何 UI 状态，只做「流订阅 + 消息分发 + 音效」，
  ///   生命周期（取消订阅）交给 Riverpod 的 ref.onDispose；
  /// - 跨状态的本地交互与菜单派生逻辑已内联到 DuelFieldPage。
  ///
  /// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
  /// override 隔离。
  DuelMessageRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duelMessageRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duelMessageRouterHash();

  @$internal
  @override
  DuelMessageRouter create() => DuelMessageRouter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$duelMessageRouterHash() => r'07a9eb81467136402adc7e560e193af18760435f';

/// 服务器消息路由器（按房间 ProviderScope 隔离）。
///
/// 取代原 DuelFieldController 的「消息分发」职责：在
/// duelServiceProvider.connect 之后调用 [DuelMessageRouter.start]，
/// 订阅对局消息流并把 MSG_* / STOC_* 分发到对应子状态 Notifier。
///
/// - 四个子状态（duelField / selectWindow / cardConfirm / fieldOverlay）
///   仍是唯一的状态持有者，写逻辑各归其 Notifier；
/// - 本 router 不持有任何 UI 状态，只做「流订阅 + 消息分发 + 音效」，
///   生命周期（取消订阅）交给 Riverpod 的 ref.onDispose；
/// - 跨状态的本地交互与菜单派生逻辑已内联到 DuelFieldPage。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。

abstract class _$DuelMessageRouter extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
