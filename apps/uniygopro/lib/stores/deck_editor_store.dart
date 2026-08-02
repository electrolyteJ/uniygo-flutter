import 'dart:developer' as console;

import 'package:flutter/foundation.dart';
import 'package:ygo_card/card_info.dart';
import '../models/deck_model.dart';
import '../service_singleton.dart';
import '../services/deck_service.dart';

/// 卡组编辑器状态仓库。
///
/// 负责卡组列表加载、当前编辑中的卡组、卡片搜索筛选、
/// 禁限卡表校验，以及编辑页本身的加载/错误/UI 状态。
class DeckEditorStore extends ChangeNotifier {
  final DeckService _deckService = DeckService();
  // ── 卡组数据 ──
  List<DeckMeta> _decks = [];
  DeckMeta? _currentDeck;
  final EditingDeck _editingDeck = EditingDeck(deckName: '');

  // ── 搜索状态 ──
  String _searchQuery = '';
  CardFilter _filter = const CardFilter();
  List<CardInfo> _searchResults = [];
  bool _isGridView = true;

  // ── 禁限卡表 ──
  Map<int, int> _banlist = {}; // code → 限制等级 (0=准限, 1=限制, 2=准限, 3=禁止)
  bool _banlistLoaded = false;

  // ── 添加卡牌目标区域 ──
  String _addTargetZone = 'main'; // main, extra, side

  // ── UI 状态 ──
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ──
  List<DeckMeta> get decks => _decks;
  DeckMeta? get currentDeck => _currentDeck;
  EditingDeck get editingDeck => _editingDeck;
  String get searchQuery => _searchQuery;
  CardFilter get filter => _filter;
  List<CardInfo> get searchResults => _searchResults;
  bool get isGridView => _isGridView;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<int, int> get banlist => _banlist;
  bool get banlistLoaded => _banlistLoaded;
  String get addTargetZone => _addTargetZone;

  // ── 初始化 ──

  /// 初始化卡牌数据库
  Future<void> initialize() async {
    await _loadBanlist();
  }

  /// 加载禁限卡表
  Future<void> _loadBanlist() async {
    try {
      console.log('加载禁限卡表中...', name: 'DeckEditorStore');
      final lflist = await ServiceSingleton.instance.cardService.fetchLflist();
      _banlist = {};
      for (final entry in lflist.entries) {
        _banlist[entry.code] = entry.limit;
      }
      _banlistLoaded = true;
    } catch (e) {
      console.log('加载禁限卡表失败: $e', name: 'DeckEditorStore');
      // 禁限卡表加载失败不影响使用
      _banlistLoaded = false;
    }
  }

  // ── 卡组操作 ──

  /// 加载卡组列表（内置卡组 + 用户保存的卡组）
  Future<void> loadDecks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 加载内置卡组
      final builtinDecks = await _deckService.loadBuiltinDecks();
      // 加载用户保存的卡组
      final userDecks = await _deckService.loadDeckList();

      // 合并，内置卡组排在前面
      _decks = [...builtinDecks, ...userDecks];
    } catch (e) {
      _errorMessage = '加载卡组列表失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 选择卡组
  Future<void> selectDeck(String deckName) async {

    if (_editingDeck.isDirty) {
      // TODO: 提示保存
    }

    _isLoading = true;
    notifyListeners();

    try {
      final deck = await _deckService.loadDeck(deckName);

      if (deck != null) {
        _replaceEditingDeck(
          deck.deckName,
          deck.main,
          deck.extra,
          deck.side,
        );
        _currentDeck = _decks.firstWhere(
          (d) => d.deckName == deckName,
          orElse: () => deck.toMeta(),
        );
      }
    } catch (e) {
      _errorMessage = '加载卡组失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建新卡组
  Future<void> createDeck(String name) async {
    if (_decks.any((d) => d.deckName == name)) {
      _errorMessage = '卡组名已存在';
      notifyListeners();
      return;
    }

    final newDeck = EditingDeck(deckName: name);
    final success = await _deckService.saveDeck(newDeck);

    if (success) {
      _decks.add(newDeck.toMeta());
      selectDeck(name);
    } else {
      _errorMessage = '创建卡组失败';
      notifyListeners();
    }
  }

  /// 删除卡组
  Future<void> deleteDeck(String name) async {
    final success = await _deckService.deleteDeck(name);
    if (success) {
      _decks.removeWhere((d) => d.deckName == name);
      if (_currentDeck?.deckName == name) {
        _currentDeck = null;
        _replaceEditingDeck('', [], [], []);
      }
      notifyListeners();
    } else {
      _errorMessage = '删除卡组失败';
      notifyListeners();
    }
  }

  /// 保存卡组
  Future<void> saveDeck() async {
    if (!_editingDeck.isDirty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _deckService.saveDeck(_editingDeck);
      if (success) {
        _editingDeck.isDirty = false;
        // 更新元数据列表
        final index = _decks.indexWhere(
          (d) => d.deckName == _editingDeck.deckName,
        );
        if (index >= 0) {
          _decks[index] = _editingDeck.toMeta();
        }
      } else {
        _errorMessage = '保存卡组失败';
      }
    } catch (e) {
      _errorMessage = '保存卡组失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 搜索操作 ──

  /// 搜索卡牌（使用本地 SQLite 数据库）
  Future<void> searchCards(String query) async {
    _searchQuery = query;
    _isLoading = true;
    notifyListeners();

    try {
      _searchResults = await ServiceSingleton.instance.cardService.searchCombined(
        query: query.isNotEmpty ? query : null,
        cardType: _filter.cardType,
        attribute: _filter.attribute,
        race: _filter.race,
        maxResults: 100,
      );
    } catch (e) {
      _errorMessage = '搜索失败: $e';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新筛选条件
  void updateFilter(CardFilter filter) {
    _filter = filter;
    searchCards(_searchQuery);
  }

  /// 切换视图模式
  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  // ── 添加卡牌目标区域 ──

  /// 设置添加卡牌的目标区域
  void setAddTargetZone(String zone) {
    _addTargetZone = zone;
    notifyListeners();
  }

  // ── 卡牌操作 ──

  /// 添加卡牌到卡组（自动根据卡牌类型选择目标区域）
  bool addCard(CardInfo card, {String? targetZone}) {
    final zone = targetZone ?? _autoSelectZone(card);
    final result = _canAddCard(zone, card);
    if (!result.$1) {
      _errorMessage = result.$2;
      notifyListeners();
      return false;
    }

    switch (zone) {
      case 'main':
        _editingDeck.main.add(card);
        break;
      case 'extra':
        _editingDeck.extra.add(card);
        break;
      case 'side':
        _editingDeck.side.add(card);
        break;
    }

    _editingDeck.isDirty = true;
    notifyListeners();
    return true;
  }

  /// 根据卡牌类型自动选择目标区域
  String _autoSelectZone(CardInfo card) {
    if (card.isFusion || card.isSynchro || card.isXyz || card.isLink) {
      return 'extra';
    }
    return _addTargetZone;
  }

  /// 从卡组移除卡牌
  void removeCard(String type, CardInfo card) {
    switch (type) {
      case 'main':
        _editingDeck.main.remove(card);
        break;
      case 'extra':
        _editingDeck.extra.remove(card);
        break;
      case 'side':
        _editingDeck.side.remove(card);
        break;
    }

    _editingDeck.isDirty = true;
    notifyListeners();
  }

  /// 检查是否可以添加卡牌
  (bool, String?) _canAddCard(String type, CardInfo card) {
    // 检查卡组数量限制
    switch (type) {
      case 'main':
        if (_editingDeck.mainCount >= 60) {
          return (false, '主卡组已满 (最多60张)');
        }
        break;
      case 'extra':
        if (_editingDeck.extraCount >= 15) {
          return (false, '额外卡组已满 (最多15张)');
        }
        // 检查是否为额外卡组怪兽
        if (!card.isFusion && !card.isSynchro && !card.isXyz && !card.isLink) {
          return (false, '额外卡组只能放入融合/同调/XYZ/连接怪兽');
        }
        break;
      case 'side':
        if (_editingDeck.sideCount >= 15) {
          return (false, '备牌已满 (最多15张)');
        }
        break;
    }

    // 检查同名卡数量
    final allCards = [
      ..._editingDeck.main,
      ..._editingDeck.extra,
      ..._editingDeck.side,
    ];
    final sameNameCount = allCards.where((c) => c.code == card.code).length;
    if (sameNameCount >= 3) {
      return (false, '同名卡最多3张');
    }

    // 检查禁限卡表
    if (_banlistLoaded && _banlist.containsKey(card.code)) {
      final limit = _banlist[card.code]!;
      final currentCount = sameNameCount;
      if (limit == 3 && currentCount >= 1) {
        return (false, '${card.name} 已禁止');
      } else if (limit == 2 && currentCount >= 2) {
        return (false, '${card.name} 已限制 (最多2张)');
      } else if (limit == 1 && currentCount >= 2) {
        return (false, '${card.name} 已准限制 (最多2张)');
      }
    }

    return (true, null);
  }

  /// 清空卡组
  void clearDeck() {
    _editingDeck.clear();
    notifyListeners();
  }

  /// 重置卡组
  Future<void> resetDeck() async {
    if (_currentDeck != null) {
      await selectDeck(_currentDeck!.deckName);
    }
  }

  /// 洗切卡组
  void shuffleDeck() {
    _editingDeck.main.shuffle();
    _editingDeck.extra.shuffle();
    _editingDeck.side.shuffle();
    _editingDeck.isDirty = true;
    notifyListeners();
  }

  /// 排序卡组
  void sortDeck() {
    _editingDeck.main.sort((a, b) => a.name.compareTo(b.name));
    _editingDeck.extra.sort((a, b) => a.name.compareTo(b.name));
    _editingDeck.side.sort((a, b) => a.name.compareTo(b.name));
    _editingDeck.isDirty = true;
    notifyListeners();
  }

  /// 更新当前编辑卡组名称，并标记为未保存。
  void renameEditingDeck(String deckName) {
    if (deckName == _editingDeck.deckName) {
      return;
    }
    _editingDeck.deckName = deckName;
    _editingDeck.isDirty = true;
    notifyListeners();
  }

  /// 用指定内容替换当前编辑卡组。
  void replaceEditingDeck({
    required String deckName,
    required List<CardInfo> main,
    required List<CardInfo> extra,
    required List<CardInfo> side,
    bool markDirty = false,
  }) {
    _replaceEditingDeck(deckName, main, extra, side);
    _editingDeck.isDirty = markDirty;
    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 标记为脏（需要保存），通知监听者
  void markDirty() {
    _editingDeck.isDirty = true;
    notifyListeners();
  }

  void _replaceEditingDeck(
    String deckName,
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    _editingDeck.reset(deckName, main, extra, side);
  }

  /// 获取卡牌的禁限状态描述
  String? getBanlistStatus(CardInfo card) {
    if (!_banlistLoaded || !_banlist.containsKey(card.code)) return null;
    final limit = _banlist[card.code]!;
    switch (limit) {
      case 3:
        return '禁止';
      case 2:
        return '限制';
      case 1:
        return '准限制';
      default:
        return null;
    }
  }
}
