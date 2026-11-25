/// 禁限卡表选项：从 MyCard 卡表服务加载，供规则面板下拉使用。
library;

import 'package:biz/service_singleton.dart';
import 'package:resource_data/lf_table.dart';

/// 一个可选的禁限卡表（[hash] 为 ygopro 的卡表 hash）。
class BanlistOption {
  const BanlistOption(this.name, this.hash);

  final String name;
  final int hash;
}

/// 233 服房间串/AI 密码使用的卡表选项：除 hash 外还有 LF<n>/NF token。
///
/// 参考历史实现 buildMercury233BanlistOptions：卡表按服务端顺序编号，
/// token 为 LF1、LF2…，lfTableHash 由 [LfTable.hash] 直传。
class Mercury233BanlistOption {
  const Mercury233BanlistOption({
    required this.label,
    required this.token,
    required this.lfTableHash,
  });

  final String label;
  final String token;
  final int lfTableHash;
}

/// 按服务端卡表顺序生成 233 选项（末尾追加「无禁限」）。
List<Mercury233BanlistOption> buildMercury233BanlistOptions(
  Iterable<LfTable> tables,
) {
  final ordered = tables.toList();
  if (ordered.isEmpty) {
    return const [
      Mercury233BanlistOption(label: '默认禁限', token: 'LF1', lfTableHash: 0),
      Mercury233BanlistOption(label: '无禁限', token: 'NF', lfTableHash: 0),
    ];
  }
  return [
    for (var i = 0; i < ordered.length; i++)
      Mercury233BanlistOption(
        label: ordered[i].name.isEmpty ? '禁限卡表 ${i + 1}' : ordered[i].name,
        token: 'LF${i + 1}',
        lfTableHash: ordered[i].hash,
      ),
    const Mercury233BanlistOption(label: '无禁限', token: 'NF', lfTableHash: 0),
  ];
}

/// 卡表目录：全局缓存一份，规则面板与建房参数共用。
///
/// 不提供「默认」占位：列表按卡表名里的日期倒序，第一项即最新卡表，
/// 未选择时直接使用最新卡表的 hash。
class BanlistCatalog {
  static List<BanlistOption> options = const [];

  /// 服务端原始顺序的卡表（233 的 LF<n> 编号依赖这个顺序）。
  static List<LfTable> tables = const [];

  static Future<List<BanlistOption>>? _loading;

  static Future<List<BanlistOption>> ensureLoaded() {
    if (options.isNotEmpty) return Future.value(options);
    return _loading ??= _load().whenComplete(() {
      if (options.isEmpty) _loading = null;
    });
  }

  static Future<List<BanlistOption>> _load() async {
    try {
      final tableMap = await ServiceSingleton.instance.dataService
          .getAllLfTable();
      tables = tableMap.values.toList();
      final list = <BanlistOption>[];
      for (final table in tables) {
        final name = table.name.trim();
        if (name.isEmpty || name == '默认') continue;
        list.add(BanlistOption(name, table.hash));
      }
      // 卡表名形如 2026.1 / 2025.10：按数字段比较，新的在前。
      list.sort((a, b) => _compareName(b.name, a.name));
      if (list.isNotEmpty) options = list;
    } catch (_) {
      // 卡表尚未加载或服务未注册：保持空列表（面板显示加载中）。
    }
    return options;
  }

  static int hashAt(int index) {
    if (options.isEmpty) return 0;
    return options[index.clamp(0, options.length - 1)].hash;
  }

  /// 233 服的禁限 token：按服务端原始顺序把 hash 映射成 LF<n>。
  static String mercury233TokenForHash(int hash) {
    if (hash == 0) return '';
    for (var i = 0; i < tables.length; i++) {
      if (tables[i].hash == hash) return 'LF${i + 1}';
    }
    return '';
  }

  static int _compareName(String a, String b) {
    final na = _numbers(a);
    final nb = _numbers(b);
    final length = na.length < nb.length ? na.length : nb.length;
    for (var i = 0; i < length; i++) {
      final c = na[i].compareTo(nb[i]);
      if (c != 0) return c;
    }
    final byLength = na.length.compareTo(nb.length);
    if (byLength != 0) return byLength;
    return a.compareTo(b);
  }

  static List<int> _numbers(String name) => [
    for (final match in RegExp(r'\d+').allMatches(name))
      int.tryParse(match.group(0)!) ?? 0,
  ];
}
