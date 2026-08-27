import 'dart:convert';
import 'dart:io';

/// 卡组市场元数据存储（点赞数/贡献者），sidecar 文件 data/deck_meta.json。
/// 与 DeckStore 的卡组文件解耦，不影响本地卡组存储格式互通。
class MetaStore {
  MetaStore(this.filePath);

  final String filePath;

  Map<String, dynamic> _readAll() {
    final file = File(filePath);
    if (!file.existsSync()) return {};
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  int likesOf(String key) {
    final meta = _readAll()[key];
    if (meta is Map<String, dynamic>) return (meta['likes'] ?? 0) as int;
    return 0;
  }

  String contributorOf(String key) {
    final meta = _readAll()[key];
    if (meta is Map<String, dynamic>) {
      return (meta['contributor'] ?? '') as String;
    }
    return '';
  }

  Map<String, int> allLikes() {
    return {
      for (final e in _readAll().entries)
        e.key: ((e.value as Map?)?['likes'] ?? 0) as int,
    };
  }

  Future<int> addLike(String key) async {
    final all = _readAll();
    final meta = (all[key] as Map?)?.cast<String, dynamic>() ?? {};
    final likes = ((meta['likes'] ?? 0) as int) + 1;
    meta['likes'] = likes;
    all[key] = meta;
    await _writeAll(all);
    return likes;
  }

  Future<void> setContributor(String key, String contributor) async {
    if (contributor.isEmpty) return;
    final all = _readAll();
    final meta = (all[key] as Map?)?.cast<String, dynamic>() ?? {};
    meta['contributor'] = contributor;
    all[key] = meta;
    await _writeAll(all);
  }
}
