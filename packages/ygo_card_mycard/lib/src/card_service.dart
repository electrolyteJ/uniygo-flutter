import 'dart:typed_data';

import 'package:ygo_card/card_info.dart';
import 'package:ygo_card/lflist_info.dart';

import 'card_api_client.dart';
import 'env_config.dart';


/// 卡片资源服务
///
/// 封装 [CardApiClient]，提供高层级的卡片数据获取能力。
/// 管理 CDN 配置，支持多环境切换。
class CardService {
  late CardApiClient _client;

  CardService({EnvConfig? config}) {
    this._client = CardApiClient(config: config ?? EnvConfig.production);
  }
  // ---------------------------------------------------------------------------
  // 数据库
  // ---------------------------------------------------------------------------

  /// 下载完整的 cards.cdb 数据库文件
  ///
  /// 返回 SQLite 格式的字节数据，调用方可使用 sqflite 等库打开。
  Future<Uint8List> downloadDatabase() => _client.fetchCardDatabase();

  // ---------------------------------------------------------------------------
  // 禁限卡表
  // ---------------------------------------------------------------------------

  /// 获取标准禁限卡表
  Future<LflistInfo> fetchLflist() => _client.fetchLflist();


  // ---------------------------------------------------------------------------
  // 字符串
  // ---------------------------------------------------------------------------

  /// 获取系统字符串表（系统提示、类别名称等）
  Future<Map<String, String>> fetchStrings() => _client.fetchStrings();

  // ---------------------------------------------------------------------------
  // 先行卡
  // ---------------------------------------------------------------------------

  /// 获取先行卡/预发布卡列表
  Future<List<CardInfo>> fetchPreReleaseCards() =>
      _client.fetchPreReleaseCards();

  /// 获取先行卡版本号
  Future<String> fetchPreReleaseVersion() =>
      _client.fetchPreReleaseVersion();

  // ---------------------------------------------------------------------------
  // 卡图
  // ---------------------------------------------------------------------------

  /// 获取正式卡图 URL
  String getCardImageUrl(int code) => _client.getCardImageUrl(code);

  /// 下载卡图
  Future<Uint8List> downloadCardImage(int code) =>
      _client.fetchCardImage(code);

}
