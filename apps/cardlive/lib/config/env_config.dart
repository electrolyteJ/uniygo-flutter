enum EnvType {
  production,
  staging,
  env408,
}

class EnvConfig {
  final EnvType type;
  final String name;
  final String cardImageUrl;
  final String cardDatabaseUrl;
  final String lflistUrl;

  EnvConfig({
    required this.type,
    required this.name,
    required this.cardImageUrl,
    required this.cardDatabaseUrl,
    required this.lflistUrl,
  });

  static EnvConfig production = EnvConfig(
    type: EnvType.production,
    name: '正式环境',
    cardImageUrl: 'https://cdntx.moecube.com/images/ygopro-images-zh-CN/{code}.jpg',
    cardDatabaseUrl: 'https://cdn02.moecube.com:444/ygopro-database/zh-CN/cards.cdb',
    lflistUrl: 'https://cdn02.moecube.com:444/ygopro-database/zh-CN/lflist.conf',
  );

  static EnvConfig staging = EnvConfig(
    type: EnvType.staging,
    name: '预发环境',
    cardImageUrl: 'https://cdn02.moecube.com:444/ygopro-super-pre/data/pics/{code}.jpg',
    cardDatabaseUrl: 'https://cdn02.moecube.com:444/ygopro-super-pre/data/test-release.cdb',
    lflistUrl: 'https://cdn02.moecube.com:444/ygopro-database/zh-CN/lflist.conf',
  );

  static EnvConfig env408 = EnvConfig(
    type: EnvType.env408,
    name: '408环境',
    cardImageUrl: 'https://cdn02.moecube.com:444/ygopro-super-pre/data/pics/{code}.jpg',
    cardDatabaseUrl: 'https://cdn02.moecube.com:444/ygopro-super-pre/data/test-release.cdb',
    lflistUrl: 'https://cdn02.moecube.com:444/cn-database/env408-zh-CN/expansions/lflist.conf',
  );

  String getCardImageUrl(int code) {
    return cardImageUrl.replaceAll('{code}', code.toString());
  }

  static EnvConfig fromType(EnvType type) {
    switch (type) {
      case EnvType.production:
        return production;
      case EnvType.staging:
        return staging;
      case EnvType.env408:
        return env408;
    }
  }
}