/// ygo_card_deck 配置
///
/// 集中管理 CDN 和 Deck API 的基准 URL，同时支持 Android 端不同 host。
class YgoCardDeckConfig {
  /// CDN 静态资源基准 URL
  final String cdnBaseUrl;

  /// Deck API 基准 URL
  final String deckApiBaseUrl;

  /// Deck API 基准 URL (Android 端，可能不同)
  final String? deckApiBaseUrlAndroid;

  /// 请求来源标识（Web: MDPro3, Android: YGOMobile）
  final String reqSource;

  const YgoCardDeckConfig({
    required this.cdnBaseUrl,
    required this.deckApiBaseUrl,
    this.deckApiBaseUrlAndroid,
    this.reqSource = 'MDPro3',
  });

  // ---------------------------------------------------------------------------
  // 预置配置
  // ---------------------------------------------------------------------------

  /// 正式环境 (neos-ts / MDPro3)
  static const production = YgoCardDeckConfig(
    cdnBaseUrl: 'https://cdn02.moecube.com:444',
    deckApiBaseUrl: 'https://deck.moecube.com',
    reqSource: 'MDPro3',
  );

  /// 预发布环境
  static const staging = YgoCardDeckConfig(
    cdnBaseUrl: 'https://cdn02.moecube.com:444',
    deckApiBaseUrl: 'https://deck.moecube.com',
    reqSource: 'MDPro3',
  );

  /// 408 环境
  static const env408 = YgoCardDeckConfig(
    cdnBaseUrl: 'https://cdn02.moecube.com:444',
    deckApiBaseUrl: 'https://deck.moecube.com',
    reqSource: 'MDPro3',
  );

  /// YGOMobile (Android) 正式环境
  static const android = YgoCardDeckConfig(
    cdnBaseUrl: 'https://cdn02.moecube.com:444',
    deckApiBaseUrl: 'https://deck.moecube.com',
    deckApiBaseUrlAndroid: 'https://deck.moecube.com',
    reqSource: 'YGOMobile',
  );

  /// 获取当前平台对应的 Deck API URL
  String get effectiveDeckApiBaseUrl =>
      deckApiBaseUrlAndroid ?? deckApiBaseUrl;
}
