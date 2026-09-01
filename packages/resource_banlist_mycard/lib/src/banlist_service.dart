import 'package:applog/console.dart' as console;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:resource_data/env_config.dart';
import 'package:resource_data/ygo_data.dart';
import 'parse_lf_table.dart';
import 'deck_validator.dart';

bool _banlistLoaded = false;

Future<void> preloadBanlist(String lflistUrl) async {
  if (_banlistLoaded) return;
  try {
    console.log('加载禁限卡表中...', name: 'DuelRoomStore');
    final response = await http.get(Uri.parse(lflistUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    parseLflistConf(utf8.decode(response.bodyBytes));
    _banlistLoaded = true;
  } catch (e) {
    console.log('加载禁限卡表失败: $e', name: 'DuelRoomStore');
    _banlistLoaded = false;
  }
}

class BanlistService extends IBanlistService {
  bool get isLoaded => _banlistLoaded;

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    if (!_banlistLoaded) {
      throw Exception('Banlist not loaded. Call preloadBanlist() first.');
    }
    final lfInfos = lflistHashToTable.isNotEmpty
        ? lflistHashToTable.values.first.lfInfos
        : <int, LfInfo>{};
    final validator = DeckValidator(lfInfos: lfInfos);
    return validator.validate(main, extra, side);
  }

  @override
  Future<Map<int, LfTable>> getAllLfTable() async {
    if (!_banlistLoaded) {
      throw Exception('Banlist not loaded. Call preloadBanlist() first.');
    }
    return lflistHashToTable;
  }

  @override
  Future<LfTable?> getLfTable(int code) async {
    if (!_banlistLoaded) {
      throw Exception('Banlist not loaded. Call preloadBanlist() first.');
    }
    return getLflist(code);
  }

  @override
  Future<Map<int, LfTable>> fetchBanlists(EnvConfig config) async {
    final response = await http.get(Uri.parse(config.lflistUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    parseLflistConf(utf8.decode(response.bodyBytes));
    _banlistLoaded = true;
    return lflistHashToTable;
  }
}
