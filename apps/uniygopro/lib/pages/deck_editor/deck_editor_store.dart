import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/lf_table.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';
import 'package:ygo_data/deck_info.dart';
import '../../models/deck_model.dart';
import '../../services/deck_service.dart';
import 'deck_editor_session.dart';

/// 卡组编辑器状态仓库。
///
/// 负责卡组列表加载、当前编辑中的卡组、卡片搜索筛选、
/// 禁限卡表校验，以及编辑页本身的加载/错误/UI 状态。
class DeckEditorStore extends ChangeNotifier {
  final DeckService _deckService = DeckService();
  // ── 卡组数据 ──
  List<DeckInfo> _decks = [];
  DeckInfo? _currentDeck;
  final EditingDeck _editingDeck = EditingDeck(deckName: '');

  // ── 搜索状态 ──
  String _searchQuery = '';
  CardFilter _filter = const CardFilter(env: 0);
  List<CardInfo> _searchResults = [];
  bool _isGridView = true;
  List<LfTable> _availableBanlists = [];
  int? _selectedBanlistHash;
  bool _isLoadingBanlists = false;

  // ── 添加卡牌目标区域 ──
  String _addTargetZone = 'main'; // main, extra, side

  // ── UI 状态 ──
  bool _isLoading = false;
  String? _errorMessage;
  DeckEditorRouteArgs? _routeArgs;
  DeckEditorSaveResult? _lastSaveResult;

  // ── Getters ──
  List<DeckInfo> get decks => _decks;
  DeckInfo? get currentDeck => _currentDeck;
  EditingDeck get editingDeck => _editingDeck;
  String get searchQuery => _searchQuery;
  CardFilter get filter => _filter;
  List<CardInfo> get searchResults => _searchResults;
  bool get isGridView => _isGridView;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get addTargetZone => _addTargetZone;
  List<LfTable> get availableBanlists => _availableBanlists;
  int get currentEnvironmentCode => _filter.env ?? 0;
  bool get isLoadingBanlists => _isLoadingBanlists;
  int? get selectedBanlistHash => _selectedBanlistHash;
  LfTable? get selectedBanlist {
    for (final table in _availableBanlists) {
      if (table.hash == _selectedBanlistHash) {
        return table;
      }
    }
    return null;
  }

  DeckEditorRouteArgs? get routeArgs => _routeArgs;
  DeckEditorSaveResult? get lastSaveResult => _lastSaveResult;
  bool get isWaitingRoomSession => _routeArgs?.isWaitingRoomSession ?? false;
  bool get lockDeckSelection => _routeArgs?.lockDeckSelection ?? false;
  bool get lockDeckName => _routeArgs?.lockDeckName ?? false;
  final dataService = ServiceSingleton.instance.dataService;
  // ── 初始化 ──

  /// 初始化卡牌数据库
  Future<void> initialize() async {
    await _loadBanlistsForCurrentEnvironment();
  }

  // ── 卡组操作 ──

  /// 加载卡组列表（内置卡组 + 用户保存的卡组）
  Future<void> loadDecks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final builtinDecks = await _deckService.loadBuiltinDecks();
      final userDecks = await _deckService.loadDeckList();
      _decks = _mergeDecks(builtinDecks, userDecks);
    } catch (e) {
      _errorMessage = '加载卡组列表失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 选择卡组
  Future<void> selectDeck(String deckName) async {
    if (lockDeckSelection &&
        _currentDeck != null &&
        _currentDeck!.deckName != deckName) {
      return;
    }
    if (_editingDeck.isDirty) {
      // TODO: 提示保存
    }

    _isLoading = true;
    notifyListeners();

    try {
      final deckInfo = await _deckService.loadDeck(deckName);

      if (deckInfo != null) {
        final mainCards = await _resolveCards(deckInfo.mainDeck);
        final extraCards = await _resolveCards(deckInfo.extraDeck);
        final sideCards = await _resolveCards(deckInfo.sideDeck);
        _replaceEditingDeck(
          deckInfo.deckName,
          mainCards,
          extraCards,
          sideCards,
        );
        _currentDeck = _decks.firstWhere(
          (d) => d.deckName == deckName,
          orElse: () => deckInfo,
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

    final newDeck = DeckInfo(deckName: name);
    final success = await _deckService.saveDeck(newDeck);

    if (success) {
      _decks.add(newDeck);
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
  Future<DeckEditorSaveResult> saveDeck() async {
    if (!_editingDeck.isDirty) {
      return const DeckEditorSaveResult(saved: false);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deckInfo = _toDeckInfo();
      final success = await _deckService.saveDeck(deckInfo);
      if (success) {
        final validationErrors = await _validateForCurrentSession(deckInfo);
        _editingDeck.isDirty = false;
        final index = _decks.indexWhere(
          (d) => d.deckName == _editingDeck.deckName,
        );
        if (index >= 0) {
          _decks[index] = deckInfo;
        } else {
          _decks.add(deckInfo);
        }
        _currentDeck = deckInfo;
        _lastSaveResult = DeckEditorSaveResult(
          saved: true,
          validationErrors: validationErrors,
        );
      } else {
        _errorMessage = '保存卡组失败';
        _lastSaveResult = const DeckEditorSaveResult(saved: false);
      }
    } catch (e) {
      _errorMessage = '保存卡组失败: $e';
      _lastSaveResult = const DeckEditorSaveResult(saved: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _lastSaveResult ?? const DeckEditorSaveResult(saved: false);
  }

  /// 从 YDK 格式导入卡组
  Future<void> importDeckFromYdk(String content, String deckName) async {
    final deckInfo = await _deckService.importFromYdk(content, deckName);
    if (deckInfo != null) {
      final mainCards = await _resolveCards(deckInfo.mainDeck);
      final extraCards = await _resolveCards(deckInfo.extraDeck);
      final sideCards = await _resolveCards(deckInfo.sideDeck);
      _replaceEditingDeck(deckInfo.deckName, mainCards, extraCards, sideCards);
      _editingDeck.isDirty = true;
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
      await _applyEnvironment();
      _searchResults = await dataService.searchCombined(
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

  void resetSearchFilters() {
    _filter = CardFilter(env: currentEnvironmentCode);
    searchCards(_searchQuery);
  }

  Future<void> setEnvironment(int env) async {
    if (currentEnvironmentCode == env) {
      return;
    }
    _filter = _filter.copyWith(env: env);
    _searchResults = [];
    notifyListeners();
    await _loadBanlistsForCurrentEnvironment();
    if (_searchQuery.isNotEmpty) {
      await searchCards(_searchQuery);
    } else {
      notifyListeners();
    }
  }

  void selectBanlist(int? hash) {
    _selectedBanlistHash = hash;
    notifyListeners();
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
  Future<bool> addCard(CardInfo card, {String? targetZone}) async {
    final zone = targetZone ?? _autoSelectZone(card);
    final result = await _canAddCard(zone, card);

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
  Future<(bool, String?)> _canAddCard(String type, CardInfo card) async {
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

    final allCards = [
      ..._editingDeck.main,
      ..._editingDeck.extra,
      ..._editingDeck.side,
    ];
    final sameNameCount = allCards.where((c) => c.code == card.code).length;
    if (sameNameCount >= 3) {
      return (false, '同名卡最多3张');
    }
    final lflist = selectedBanlist;
    final lfInfo = lflist?.getLimit(card.code);
    final currentCount = sameNameCount;
    if (lfInfo == LfType.forbidden) {
      return (false, '${card.name} 已禁止');
    } else if (lfInfo == LfType.limited && currentCount >= 1) {
      return (false, '${card.name} 已限制 (最多1张)');
    } else if (lfInfo == LfType.semiLimited && currentCount >= 2) {
      return (false, '${card.name} 已准限制 (最多2张)');
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
    if (lockDeckName) {
      return;
    }
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

  Future<void> configureSession(DeckEditorRouteArgs? args) async {
    _routeArgs = args;
    _lastSaveResult = null;
    _errorMessage = null;
    if (args?.validationContext != null) {
      _selectedBanlistHash = args!.validationContext!.lfTableHash;
    }
    await _loadBanlistsForCurrentEnvironment(
      preferredHash: _selectedBanlistHash,
    );

    final deckName = args?.initialDeckName;
    if (deckName != null && deckName.isNotEmpty) {
      _currentDeck = null;
      await selectDeck(deckName);
    }

    notifyListeners();
  }

  /// 标记为脏（需要保存），通知监听者
  void markDirty() {
    _editingDeck.isDirty = true;
    notifyListeners();
  }

  /// 转换为 DeckInfo（用于导出/保存）
  DeckInfo toDeckInfo() => _toDeckInfo();

  /// 导出为 YDK 格式
  String exportToYdk() => _deckService.exportToYdk(_toDeckInfo());

  String getCardImageUrl(int code) => dataService.getCardImageUrl(code);

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
    final table = selectedBanlist;
    if (table == null) {
      return null;
    }
    final status = table.getLimitText(card.code);
    return status == '无限制' ? null : status;
  }

  // ── DeckInfo ↔ CardInfo 转换 ──

  DeckInfo _toDeckInfo() {
    return DeckInfo(
      deckName: _editingDeck.deckName,
      mainDeck: _groupCards(_editingDeck.main),
      extraDeck: _groupCards(_editingDeck.extra),
      sideDeck: _groupCards(_editingDeck.side),
    );
  }

  List<DeckCard> _groupCards(List<CardInfo> cards) {
    final grouped = <int, int>{};
    for (final c in cards) {
      grouped[c.code] = (grouped[c.code] ?? 0) + 1;
    }
    return grouped.entries
        .map((e) => DeckCard(code: e.key, count: e.value))
        .toList();
  }

  Future<List<CardInfo>> _resolveCards(List<DeckCard> deckCards) async {
    final result = <CardInfo>[];
    for (final dc in deckCards) {
      final card = await dataService.getCard(dc.code);
      if (card != null) {
        for (var i = 0; i < dc.count; i++) {
          result.add(card);
        }
      }
    }
    return result;
  }

  List<DeckInfo> _mergeDecks(
    List<DeckInfo> builtinDecks,
    List<DeckInfo> userDecks,
  ) {
    final merged = <String, DeckInfo>{};
    for (final deck in builtinDecks) {
      merged[deck.deckName] = deck;
    }
    for (final deck in userDecks) {
      merged[deck.deckName] = deck;
    }
    return merged.values.toList();
  }

  Future<List<String>?> _validateForCurrentSession(DeckInfo deckInfo) async {
    final validationContext = _routeArgs?.validationContext;
    if (validationContext != null && validationContext.noCheckDeck) {
      return null;
    }

    final lfTable = await _resolveActiveValidationLfTable();
    if (lfTable == null) {
      return null;
    }

    final main = await _resolveCards(deckInfo.mainDeck);
    final extra = await _resolveCards(deckInfo.extraDeck);
    final side = await _resolveCards(deckInfo.sideDeck);
    final validator = DeckValidator(lfInfos: lfTable.lfInfos);
    return validator.validate(main, extra, side);
  }

  Future<void> _applyEnvironment() async {
    dataService.envType = currentEnvironmentCode == 1
        ? EnvType.env408
        : EnvType.production;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> _loadBanlistsForCurrentEnvironment({int? preferredHash}) async {
    _isLoadingBanlists = true;
    notifyListeners();
    try {
      final envConfig = currentEnvironmentCode == 1
          ? EnvConfig.env408
          : EnvConfig.production;
      final response = await http.get(Uri.parse(envConfig.lflistUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      parseLflistConf(utf8.decode(response.bodyBytes));
      _availableBanlists = lflistHashToTable.values.toList()
        ..sort(_compareBanlistsByDateDesc);
      final targetHash = preferredHash ?? _selectedBanlistHash;
      if (targetHash != null &&
          _availableBanlists.any((table) => table.hash == targetHash)) {
        _selectedBanlistHash = targetHash;
      } else {
        _selectedBanlistHash = _availableBanlists.isEmpty
            ? null
            : _availableBanlists.first.hash;
      }
      await _applyEnvironment();
    } catch (e) {
      _availableBanlists = [];
      _selectedBanlistHash = null;
      _errorMessage = '加载禁限卡表失败: $e';
    } finally {
      _isLoadingBanlists = false;
      notifyListeners();
    }
  }

  Future<LfTable?> _resolveActiveValidationLfTable() async {
    if (_selectedBanlistHash != null) {
      for (final table in _availableBanlists) {
        if (table.hash == _selectedBanlistHash) {
          return table;
        }
      }
      return dataService.getLfTable(_selectedBanlistHash!);
    }

    final validationContext = _routeArgs?.validationContext;
    if (validationContext == null) {
      return null;
    }
    return dataService.getLfTable(validationContext.lfTableHash);
  }

  int _compareBanlistsByDateDesc(LfTable a, LfTable b) {
    final aDate = _extractBanlistSortKey(a);
    final bDate = _extractBanlistSortKey(b);
    for (var i = 0; i < 3; i++) {
      final diff = bDate[i].compareTo(aDate[i]);
      if (diff != 0) {
        return diff;
      }
    }
    return a.name.compareTo(b.name);
  }

  List<int> _extractBanlistSortKey(LfTable table) {
    final source = '${table.name} ${table.date}';

    final fullDate = RegExp(
      r'((?:19|20)\d{2})[.\-/_年\s]*?(\d{1,2})[.\-/_月\s]*?(\d{1,2})',
    ).firstMatch(source);
    if (fullDate != null) {
      return [
        int.tryParse(fullDate.group(1) ?? '') ?? -1,
        int.tryParse(fullDate.group(2) ?? '') ?? 0,
        int.tryParse(fullDate.group(3) ?? '') ?? 0,
      ];
    }

    final yearMonth = RegExp(
      r'((?:19|20)\d{2})[.\-/_年\s]*?(\d{1,2})',
    ).firstMatch(source);
    if (yearMonth != null) {
      return [
        int.tryParse(yearMonth.group(1) ?? '') ?? -1,
        int.tryParse(yearMonth.group(2) ?? '') ?? 0,
        0,
      ];
    }

    final yearOnly = RegExp(r'((?:19|20)\d{2})').firstMatch(source);
    if (yearOnly != null) {
      return [int.tryParse(yearOnly.group(1) ?? '') ?? -1, 0, 0];
    }

    return const [-1, 0, 0];
  }
}
