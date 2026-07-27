import 'package:ygo_card_deck/models/lflist_info.dart';
import 'package:ygo_card_deck/ygo_card_deck.dart';

class CardService {
  static CardService? _instance;
  LflistInfo? _lflist;
  EnvConfig _envConfig;

  CardService._(this._envConfig) {
  }

  factory CardService(EnvConfig envConfig) {
    _instance ??= CardService._(envConfig);
    return _instance!;
  }

  EnvType get envType => _envConfig.type;

  void switchEnv(EnvConfig config) {
    _envConfig = config;
    _lflist = null;
  }

  Future<void> init() async {
    await _loadLflist();
  }

  Future<void> _loadLflist() async {
    _lflist = await fetchLflist();
  }

  String getCardImageUrl(int code) {
    return _envConfig.getCardImageUrl(code);
  }

  String getCardLimitText(int code) {
    return _lflist?.getLimitText(code) ?? '无限制';
  }

  int getCardLimit(int code) {
    return _lflist?.getLimit(code) ?? 3;
  }
}
