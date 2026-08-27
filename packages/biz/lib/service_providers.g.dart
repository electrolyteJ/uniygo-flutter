// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cardService)
final cardServiceProvider = CardServiceProvider._();

final class CardServiceProvider
    extends
        $FunctionalProvider<
          MyCardCardService,
          MyCardCardService,
          MyCardCardService
        >
    with $Provider<MyCardCardService> {
  CardServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardServiceHash();

  @$internal
  @override
  $ProviderElement<MyCardCardService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MyCardCardService create(Ref ref) {
    return cardService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MyCardCardService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MyCardCardService>(value),
    );
  }
}

String _$cardServiceHash() => r'7671394eec427f348c2e11edec926cdf1830ab17';

/// AI 对局服务：需要注入卡片查询函数才能解析服务器下发的卡码。

@ProviderFor(aiDuelService)
final aiDuelServiceProvider = AiDuelServiceProvider._();

/// AI 对局服务：需要注入卡片查询函数才能解析服务器下发的卡码。

final class AiDuelServiceProvider
    extends $FunctionalProvider<AiDuelService, AiDuelService, AiDuelService>
    with $Provider<AiDuelService> {
  /// AI 对局服务：需要注入卡片查询函数才能解析服务器下发的卡码。
  AiDuelServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiDuelServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiDuelServiceHash();

  @$internal
  @override
  $ProviderElement<AiDuelService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiDuelService create(Ref ref) {
    return aiDuelService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiDuelService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiDuelService>(value),
    );
  }
}

String _$aiDuelServiceHash() => r'5bd01670ff105920da4c37c791769a92b35ced58';

/// 按 URI scheme 路由到 ws/tcp/ai/puzzle 底层实现的对局服务门面。

@ProviderFor(duelService)
final duelServiceProvider = DuelServiceProvider._();

/// 按 URI scheme 路由到 ws/tcp/ai/puzzle 底层实现的对局服务门面。

final class DuelServiceProvider
    extends $FunctionalProvider<IDuelService, IDuelService, IDuelService>
    with $Provider<IDuelService> {
  /// 按 URI scheme 路由到 ws/tcp/ai/puzzle 底层实现的对局服务门面。
  DuelServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duelServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duelServiceHash();

  @$internal
  @override
  $ProviderElement<IDuelService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IDuelService create(Ref ref) {
    return duelService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IDuelService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IDuelService>(value),
    );
  }
}

String _$duelServiceHash() => r'51f740be20ef6d04e7b662ad4e58c90991fa6d51';

@ProviderFor(dataService)
final dataServiceProvider = DataServiceProvider._();

final class DataServiceProvider
    extends $FunctionalProvider<YgoDataService, YgoDataService, YgoDataService>
    with $Provider<YgoDataService> {
  DataServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataServiceHash();

  @$internal
  @override
  $ProviderElement<YgoDataService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  YgoDataService create(Ref ref) {
    return dataService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YgoDataService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YgoDataService>(value),
    );
  }
}

String _$dataServiceHash() => r'71d005d985c6b3fabb3f2ddce52ab12f9b0f8ed1';

@ProviderFor(ygoSoundService)
final ygoSoundServiceProvider = YgoSoundServiceProvider._();

final class YgoSoundServiceProvider
    extends
        $FunctionalProvider<YgoSoundService, YgoSoundService, YgoSoundService>
    with $Provider<YgoSoundService> {
  YgoSoundServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ygoSoundServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ygoSoundServiceHash();

  @$internal
  @override
  $ProviderElement<YgoSoundService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  YgoSoundService create(Ref ref) {
    return ygoSoundService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YgoSoundService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YgoSoundService>(value),
    );
  }
}

String _$ygoSoundServiceHash() => r'fc83defaa3dba91c2eb58797ffddd510c2b7f766';

/// 引擎字符串表（strings.conf）：MSG_HINT 提示文案。应用级单例，
/// 首次读取时后台抓取，未加载完成前 systemString 返回 null（降级为不显示文案）。

@ProviderFor(stringsService)
final stringsServiceProvider = StringsServiceProvider._();

/// 引擎字符串表（strings.conf）：MSG_HINT 提示文案。应用级单例，
/// 首次读取时后台抓取，未加载完成前 systemString 返回 null（降级为不显示文案）。

final class StringsServiceProvider
    extends $FunctionalProvider<StringsService, StringsService, StringsService>
    with $Provider<StringsService> {
  /// 引擎字符串表（strings.conf）：MSG_HINT 提示文案。应用级单例，
  /// 首次读取时后台抓取，未加载完成前 systemString 返回 null（降级为不显示文案）。
  StringsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stringsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stringsServiceHash();

  @$internal
  @override
  $ProviderElement<StringsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StringsService create(Ref ref) {
    return stringsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StringsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StringsService>(value),
    );
  }
}

String _$stringsServiceHash() => r'e7ea3e5e564ba58f4f24d78cfa3d653c2b07eed9';
