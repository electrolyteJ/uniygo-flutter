import 'dart:developer' as console;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/lf_table.dart';
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

class BanlistService {
  bool get isLoaded => _banlistLoaded;

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

  LfTable? getLfTable(int hash) => getLflist(hash);

  Map<int, LfTable> getAllLfTables() => Map.unmodifiable(lflistHashToTable);
}
