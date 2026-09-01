import 'package:biz/service_singleton.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:resource_data/env_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';
import 'package:resource_data/lf_table.dart';

import 'card_search_filter.dart';
import 'editor_rules.dart';

part 'editor_controller.g.dart';

/// copyWith 中可空字段（selectedBanlistHash）的「未传」哨兵。
const Object _unset = Object();

/// 编辑器状态：卡组内容 + 校验信息 + 卡池搜索结果。
class EditorState {
  const EditorState({
    required this.deck,
    this.structuralErrors = const [],
    this.banlistErrors = const [],
    this.searchResults = const [],
    this.searching = false,
    this.lastAddResult,
    this.dirty = false,
    this.environment = 0,
    this.availableBanlists = const [],
    this.selectedBanlistHash,
    this.loadingBanlists = false,
    this.query = '',
    this.filter = CardSearchFilter.defaults,
  });

  final DeckEditState deck;
  final List<String> structuralErrors;
  final List<String> banlistErrors;
  final List<CardInfo> searchResults;
  final bool searching;
  final AddCardResult? lastAddResult;
  final bool dirty;

  /// 禁限卡环境：0 = OCG（正式），1 = 408（408 环境）。
  final int environment;

  /// 当前环境已加载的禁限卡表（按日期倒序）。
  final List<LfTable> availableBanlists;

  /// 当前选中的禁限卡表 hash。
  final int? selectedBanlistHash;

  /// 是否正在加载禁限卡表。
  final bool loadingBanlists;

  /// 当前搜索关键字（卡池左栏）。
  final String query;

  /// 卡池搜索的类别/子类筛选。
  final CardSearchFilter filter;

  bool get hasErrors =>
      structuralErrors.isNotEmpty || banlistErrors.isNotEmpty;

  EditorState copyWith({
    DeckEditState? deck,
    List<String>? structuralErrors,
    List<String>? banlistErrors,
    List<CardInfo>? searchResults,
    bool? searching,
    AddCardResult? lastAddResult,
    bool? dirty,
    int? environment,
    List<LfTable>? availableBanlists,
    Object? selectedBanlistHash = _unset,
    bool? loadingBanlists,
    String? query,
    CardSearchFilter? filter,
  }) {
    return EditorState(
      deck: deck ?? this.deck,
      structuralErrors: structuralErrors ?? this.structuralErrors,
      banlistErrors: banlistErrors ?? this.banlistErrors,
      searchResults: searchResults ?? this.searchResults,
      searching: searching ?? this.searching,
      lastAddResult: lastAddResult,
      dirty: dirty ?? this.dirty,
      environment: environment ?? this.environment,
      availableBanlists: availableBanlists ?? this.availableBanlists,
      selectedBanlistHash: identical(selectedBanlistHash, _unset)
          ? this.selectedBanlistHash
          : selectedBanlistHash as int?,
      loadingBanlists: loadingBanlists ?? this.loadingBanlists,
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }
}

/// 组卡编辑器控制器。
@Riverpod(keepAlive: true)
class EditorController extends _$EditorController {
  @override
  EditorState build() => EditorState(deck: DeckEditState());

  YgoDataService get _data => ServiceSingleton.instance.dataService;

  /// 新建空白卡组。
  void newDeck() {
    state = EditorState(deck: DeckEditState());
  }

  /// 载入既有卡组。
  void loadDeck(DeckInfo deck) {
    state = EditorState(deck: DeckEditState.fromDeckInfo(deck));
    _revalidate();
    // 预热卡信息缓存（异步），完成后再次 _revalidate 刷新禁限校验与角标。
    // ignore: unawaited_futures
    warmCardCache();
  }

  void rename(String name) {
    state.deck.name = name;
    state = state.copyWith(deck: state.deck, dirty: true);
  }

  /// 加卡（自动路由到合法分区：额外怪 → extra，其余 → main）。
  AddCardResult addCard(CardInfo info) {
    final zone = allowedZones(info).contains(DeckZone.main)
        ? DeckZone.main
        : DeckZone.extra;
    return addCardTo(info, zone);
  }

  AddCardResult addCardTo(CardInfo info, DeckZone zone) {
    final result = tryAddCard(state.deck, info, zone);
    state = state.copyWith(lastAddResult: result, dirty: true);
    if (result == AddCardResult.ok) _revalidate();
    return result;
  }

  bool removeCard(int code, DeckZone zone) {
    final removed = tryRemoveCard(state.deck, code, zone);
    if (removed) {
      state = state.copyWith(dirty: true);
      _revalidate();
    }
    return removed;
  }

  /// 搜索卡池（关键字 + 类别/子类筛选，searchCombined 粗筛 + 本地精筛）。
  Future<void> search(String keyword) async {
    state = state.copyWith(query: keyword.trim());
    await _runSearch();
  }

  /// 切换大类（怪兽/额外卡/魔法/陷阱）。
  Future<void> toggleCategory(CardCategory category) async {
    final f = state.filter;
    final next = f.copyWith(
      monster: category == CardCategory.monster ? !f.monster : f.monster,
      extra: category == CardCategory.extra ? !f.extra : f.extra,
      spell: category == CardCategory.spell ? !f.spell : f.spell,
      trap: category == CardCategory.trap ? !f.trap : f.trap,
    );
    state = state.copyWith(filter: next);
    await _runSearch();
  }

  /// 切换怪兽属性。
  Future<void> toggleMonsterAttribute(int value) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        attributes: _toggle(state.filter.attributes, value),
      ),
    );
    await _runSearch();
  }

  /// 切换怪兽种族。
  Future<void> toggleMonsterRace(int value) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        races: _toggle(state.filter.races, value),
      ),
    );
    await _runSearch();
  }

  /// 切换额外卡种类（融合/同调/超量/连接）。
  Future<void> toggleExtraType(int value) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        extraTypes: _toggle(state.filter.extraTypes, value),
      ),
    );
    await _runSearch();
  }

  /// 切换魔法子类。
  Future<void> toggleSpellType(int value) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        spellTypes: _toggle(state.filter.spellTypes, value),
      ),
    );
    await _runSearch();
  }

  /// 切换陷阱子类。
  Future<void> toggleTrapType(int value) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        trapTypes: _toggle(state.filter.trapTypes, value),
      ),
    );
    await _runSearch();
  }

  /// 重置为默认筛选（仅选中怪兽）并重新搜索。
  Future<void> clearFilters() async {
    state = state.copyWith(filter: CardSearchFilter.defaults);
    await _runSearch();
  }

  Set<int> _toggle(Set<int> set, int value) {
    final next = Set<int>.from(set);
    if (!next.add(value)) next.remove(value);
    return next;
  }

  Future<void> _runSearch() async {
    final q = state.query;
    final filter = state.filter;
    if (q.isEmpty && filter.isEmpty) {
      state = state.copyWith(searchResults: const [], searching: false);
      return;
    }
    state = state.copyWith(searching: true);
    try {
      final broadMask = filter.broadTypeMask;
      final results = await _data.searchCombined(
        query: q.isEmpty ? null : q,
        cardType: broadMask == 0 ? null : broadMask,
        maxResults: 100000,
      );
      final filtered =
          filter.isEmpty ? results : results.where(filter.matches).toList();
      state = state.copyWith(searchResults: filtered, searching: false);
    } catch (_) {
      state = state.copyWith(searchResults: const [], searching: false);
    }
  }

  /// 保存到本地（ygo_deck_mycard）。
  Future<bool> save() async {
    final ok = await _data.saveDeck(state.deck.toDeckInfo());
    if (ok) state = state.copyWith(dirty: false);
    return ok;
  }

  /// 当前选中的禁限卡表（未选中或未加载时返回 null）。
  LfTable? get selectedBanlist {
    final hash = state.selectedBanlistHash;
    if (hash == null) return null;
    for (final t in state.availableBanlists) {
      if (t.hash == hash) return t;
    }
    return null;
  }

  /// 查询某卡的禁限状态文本（禁止/限制/准限制）；无限制返回 null。
  String? banlistStatusOf(int code) {
    final table = selectedBanlist;
    if (table == null) return null;
    final status = table.getLimitText(code);
    return status == '无限制' ? null : status;
  }

  /// 加载指定环境的禁限卡表（0 = OCG，1 = 408）。
  Future<void> loadBanlists([int? environment]) async {
    final env = environment ?? state.environment;
    state = state.copyWith(environment: env, loadingBanlists: true);
    try {
      final config = env == 1 ? EnvConfig.env408 : EnvConfig.production;
      final tables = await _data.fetchBanlists(config);
      final list = tables.values.toList()
        ..sort((a, b) => b.name.compareTo(a.name));
      final current = state.selectedBanlistHash;
      final selected = (current != null && list.any((t) => t.hash == current))
          ? current
          : (list.isEmpty ? null : list.first.hash);
      state = state.copyWith(
        environment: env,
        availableBanlists: list,
        selectedBanlistHash: selected,
        loadingBanlists: false,
      );
    } catch (_) {
      state = state.copyWith(
        environment: env,
        availableBanlists: const [],
        selectedBanlistHash: null,
        loadingBanlists: false,
      );
    }
    _revalidate();
  }

  /// 切换禁限卡表（hash 为空表示不校验禁限）。
  void selectBanlist(int? hash) {
    state = state.copyWith(selectedBanlistHash: hash);
    _revalidate();
  }

  /// 切换禁限卡环境（0 = OCG，1 = 408），并重载禁限卡表。
  void setEnvironment(int env) {
    if (env == state.environment) return;
    loadBanlists(env);
  }

  /// 预热卡组内所有卡的 CardInfo 缓存（供禁限角标与校验使用）。
  Future<void> warmCardCache() async {
    final codes = <int>{};
    for (final c in [
      ...state.deck.main,
      ...state.deck.extra,
      ...state.deck.side,
    ]) {
      codes.add(c.code);
    }
    await Future.wait(codes.map((c) => _data.getCard(c)));
    _revalidate();
  }

  void _revalidate() {
    final errors = structuralErrors(state.deck);
    final table = selectedBanlist;
    var banlistErrors = const <String>[];
    if (table != null && _allCardsLoaded) {
      banlistErrors = _banlistErrorsFor(state.deck, table);
    }
    state = state.copyWith(
      structuralErrors: errors,
      banlistErrors: banlistErrors,
    );
  }

  bool get _allCardsLoaded {
    for (final c in [
      ...state.deck.main,
      ...state.deck.extra,
      ...state.deck.side,
    ]) {
      if (_data.getCardCached(c.code) == null) return false;
    }
    return true;
  }

  /// 禁限卡校验（含同名卡 ≤3 张，别名归一）。仅返回禁限/同名卡错误。
  List<String> _banlistErrorsFor(DeckEditState deck, LfTable table) {
    final errors = <String>[];
    final counts = <int, int>{};
    final names = <int, String>{};
    for (final c in [...deck.main, ...deck.extra, ...deck.side]) {
      final info = _data.getCardCached(c.code);
      final canonical = (info != null && info.alias != 0) ? info.alias : c.code;
      counts[canonical] = (counts[canonical] ?? 0) + c.count;
      names[canonical] = info?.name ?? names[canonical] ?? '${c.code}';
    }
    for (final e in counts.entries) {
      final label = names[e.key] ?? '${e.key}';
      if (e.value > 3) {
        errors.add('$label 超过 3 张（当前${e.value}张）');
        continue;
      }
      switch (table.getLimit(e.key)) {
        case LfType.forbidden:
          errors.add('$label 是禁止卡');
        case LfType.limited:
          if (e.value > 1) {
            errors.add('$label 是限制卡（最多1张，当前${e.value}张）');
          }
        case LfType.semiLimited:
          if (e.value > 2) {
            errors.add('$label 是准限制卡（最多2张，当前${e.value}张）');
          }
        case LfType.unlimited:
          break;
      }
    }
    return errors;
  }
}
