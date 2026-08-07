import 'package:service_loader/service_loader.dart';
import 'package:ygo_data/deck_info.dart';
import 'package:ygo_data/deck_list_page.dart';
import 'package:ygo_data/ygo_data.dart';

import 'deck_api_client.dart';


@OnServiceRegister()
onServiceRegister() {

}

/// 卡组广场服务
///
/// 封装 [DeckApiClient]，提供高层级的卡组管理能力。
@Service(IDeckService)
class DeckService implements IDeckService{
  final DeckApiClient _client;

  DeckService({
    DeckApiClient? client,
  }) : _client = client ?? DeckApiClient();

  // ---------------------------------------------------------------------------
  // 浏览
  // ---------------------------------------------------------------------------

  /// 获取卡组广场分页列表
  Future<DeckListPage> fetchDeckList({
    int page = 1,
    int size = 20,
    String? keyword,
    bool sortLike = false,
    bool sortRank = false,
    String? contributor,
  }) =>
      _client.fetchDeckList(
        page: page,
        size: size,
        keyword: keyword,
        sortLike: sortLike,
        sortRank: sortRank,
        contributor: contributor,
      );

  /// 获取卡组详情
  Future<MdPro3DeckInfo> fetchDeckDetail(String deckId) =>
      _client.fetchDeckDetail(deckId);

  /// 生成新卡组 ID
  Future<String> generateDeckId() => _client.generateDeckId();

  // ---------------------------------------------------------------------------
  // 云端同步
  // ---------------------------------------------------------------------------

  /// 获取用户云端卡组列表
  Future<List<MdPro3DeckInfo>> fetchUserDecks({
    required int userId,
    required String token,
  }) =>
      _client.fetchUserDecks(userId: userId, token: token);

  /// 上传卡组
  Future<void> uploadDeck({
    required MdPro3DeckInfo deck,
    required int userId,
    required String contributor,
    required String token,
  }) =>
      _client.uploadDeck(
        deck: deck,
        userId: userId,
        contributor: contributor,
        token: token,
      );

  /// 删除卡组
  Future<void> deleteDeck({
    required String deckId,
    required int userId,
    required String contributor,
    required String token,
  }) =>
      _client.deleteDeck(
        deckId: deckId,
        userId: userId,
        contributor: contributor,
        token: token,
      );

  /// 切换卡组公开/私密
  Future<void> toggleDeckPublic({
    required String deckId,
    required int userId,
    required bool isPublic,
    required String token,
  }) =>
      _client.toggleDeckPublic(
        deckId: deckId,
        userId: userId,
        isPublic: isPublic,
        token: token,
      );

  /// 点赞卡组
  Future<void> likeDeck(String deckId) => _client.likeDeck(deckId);
}
