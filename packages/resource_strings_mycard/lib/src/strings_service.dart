import 'dart:convert';
import 'package:applog/console.dart' as console;

import 'package:http/http.dart' as http;

/// strings.conf 字符串表：YGOPRO 引擎的提示文案。
///
/// 格式（MyCard CDN，每行一条）：
///   !system <index> <text>   —— 系统提示（MSG_HINT 的 message/selectMessage 等）
///   !counter <code> <name>   —— 指示物名
/// 与卡片数据库（cards.cdb）不同，这是引擎规则/文案资源，故独立成包。
class StringsService {
  StringsService({this.url = defaultStringsUrl})
    : _system = {},
      _counter = {},
      _loaded = false;

  /// 测试用：直接注入字符串表，跳过网络抓取。
  StringsService.seeded({
    Map<int, String> system = const {},
    Map<int, String> counter = const {},
  }) : url = '',
       _system = Map.of(system),
       _counter = Map.of(counter),
       _loaded = true;

  static const defaultStringsUrl =
      'https://cdn02.moecube.com:444/ygopro-database/zh-CN/strings.conf';

  final String url;

  final Map<int, String> _system;
  final Map<int, String> _counter;
  bool _loaded;

  bool get isLoaded => _loaded;

  /// 抓取并解析 strings.conf；失败不抛出，保持空表（调用方降级为不显示文案）。
  Future<void> load() async {
    if (_loaded) return;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _parse(utf8.decode(response.bodyBytes));
      _loaded = true;
    } catch (e) {
      console.log('加载 strings.conf 失败: $e');
    }
  }

  void _parse(String content) {
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      switch (parts[0]) {
        case '!system':
          final index = int.tryParse(parts[1]);
          if (index != null) _system[index] = parts.sublist(2).join(' ');
        case '!counter':
          final code = int.tryParse(parts[1]);
          if (code != null) _counter[code] = parts.sublist(2).join(' ');
      }
    }
  }

  /// !system 索引 → 文案（MSG_HINT 的 event/message/selectMessage/optionSelected）。
  String? systemString(int index) => _system[index];

  /// !counter 卡密 → 指示物名。
  String? counterName(int code) => _counter[code];
}
