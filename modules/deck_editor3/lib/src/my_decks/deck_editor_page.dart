import 'package:biz/service_singleton.dart';
import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';

import 'card_search_filter.dart';
import 'editor_controller.dart';
import 'editor_rules.dart';
import '../widgets/banlist_badge.dart';
import '../widgets/deck_zone_grid.dart';

/// 怪兽属性筛选选项（值 = attribute 位掩码）。
const List<(String, int)> _attributeOptions = [
  ('地', 0x01),
  ('水', 0x02),
  ('炎', 0x04),
  ('风', 0x08),
  ('光', 0x10),
  ('暗', 0x20),
  ('神', 0x40),
];

/// 怪兽种族筛选选项（值 = race 位掩码）。
const List<(String, int)> _raceOptions = [
  ('战士', 0x1),
  ('魔法师', 0x2),
  ('天使', 0x4),
  ('恶魔', 0x8),
  ('不死', 0x10),
  ('机械', 0x20),
  ('水族', 0x40),
  ('炎族', 0x80),
  ('岩石', 0x100),
  ('鸟兽', 0x200),
  ('植物', 0x400),
  ('昆虫', 0x800),
  ('雷族', 0x1000),
  ('龙', 0x2000),
  ('兽', 0x4000),
  ('兽战士', 0x8000),
  ('恐龙', 0x10000),
  ('鱼', 0x20000),
  ('海龙', 0x40000),
  ('爬虫类', 0x80000),
  ('念动力', 0x100000),
  ('幻神', 0x200000),
  ('创造神', 0x400000),
  ('幻龙', 0x800000),
  ('电子界', 0x1000000),
  ('幻兽神', 0x2000000),
];

/// 额外卡种类（值 = type 标志位）。
const List<(String, int)> _extraTypeOptions = [
  ('融合', 0x40),
  ('同调', 0x2000),
  ('超量', 0x800000),
  ('连接', 0x4000000),
];

/// 魔法子类（值 0 = 通常魔法，其余为 type 标志位）。
const List<(String, int)> _spellTypeOptions = [
  ('通常', 0),
  ('速攻', 0x10000),
  ('永续', 0x20000),
  ('装备', 0x40000),
  ('场地', 0x80000),
  ('仪式', 0x80),
];

/// 陷阱子类（值 0 = 通常陷阱，其余为 type 标志位）。
const List<(String, int)> _trapTypeOptions = [
  ('通常', 0),
  ('永续', 0x20000),
  ('反击', 0x100000),
  ('陷阱怪兽', 0x100),
];

/// 全新组卡编辑器：三栏布局（卡池 | 卡组 | 详情），MDPro3 风格暗色科技风。
///
/// - 左栏卡池：搜索框 + 禁限环境/卡表选择 + 结果网格（右上「+」加卡，单击看详情）
/// - 中栏卡组：主/额外/副三区网格（右上「×」减卡，单击看详情），计数与校验实时显示
/// - 右栏详情：当前选中卡大图 + 禁限状态 + 效果文本（点任意卡更新）
class DeckEditor3Page extends ConsumerStatefulWidget {
  const DeckEditor3Page({super.key, this.initialDeck});

  /// 进入编辑器时载入的卡组；为空表示新建空白卡组。
  final DeckInfo? initialDeck;

  @override
  ConsumerState<DeckEditor3Page> createState() => _DeckEditor3PageState();
}

class _DeckEditor3PageState extends ConsumerState<DeckEditor3Page> {
  final _searchController = TextEditingController();
  CardInfo? _focusedCard;

  /// 详情焦点是否来自卡组（true = 卡组 → 显示「×」移出；false = 卡池 → 显示「+」加入）。
  bool _focusedFromDeck = false;

  /// 焦点卡来自卡组时所在的分区（用于「×」移出）。
  DeckZone? _focusedZone;

  /// 详情异步取卡的请求序号，用于丢弃过期结果（快速连点时避免旧结果覆盖新卡）。
  int _detailRequestSeq = 0;

  /// 详情是否正在异步取卡（缓存未命中时）。
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    final deck = widget.initialDeck;
    // 编辑器自带独立 ProviderScope，其 editorControllerProvider 与「我的卡组」
    // 页不在同一作用域，因此通过构造参数传入卡组，并在首帧后载入。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(editorControllerProvider.notifier);
      if (deck != null) controller.loadDeck(deck);
      // 加载禁限卡表（默认 OCG 环境，可在左栏切换 408）。
      // ignore: unawaited_futures
      controller.loadBanlists();
      // 默认选中「怪兽」大类，初始即展示怪兽卡池。
      // ignore: unawaited_futures
      controller.search('');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: Colors.white,
        title: _DeckNameField(
          name: state.deck.name,
          onSubmitted: controller.rename,
        ),
        actions: [
          // 校验状态
          if (state.hasErrors)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: [
                  ...state.structuralErrors,
                  ...state.banlistErrors,
                ].join('\n'),
                child: const Icon(Icons.warning_amber,
                    color: Color(0xFFFFD75A)),
              ),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B7FA8),
            ),
            icon: const Icon(Icons.save, size: 16),
            label: const Text('保存'),
            onPressed: () => _save(context, controller),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 左栏：卡池 ──
          Expanded(flex: 5, child: _buildPool(state, controller)),
          const VerticalDivider(width: 1, color: Color(0xFF1E3A55)),
          // ── 中栏：卡组区 ──
          Expanded(flex: 4, child: _buildDeck(state, controller)),
          const VerticalDivider(width: 1, color: Color(0xFF1E3A55)),
          // ── 右栏：卡片详情 ──
          Expanded(flex: 3, child: _buildDetail(controller)),
        ],
      ),
    );
  }

  Widget _buildPool(EditorState state, EditorController controller) {
    return Column(
      children: [
        _buildSearchAndBanlistBar(state, controller),
        _buildFilterBar(state, controller),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: state.searching
                ? const Text('搜索中…',
                    style: TextStyle(color: Colors.white38, fontSize: 12))
                : Text(
                    '共 ${state.searchResults.length} 张卡',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
          ),
        ),
        Expanded(
          child: state.searching
              ? const Center(child: CircularProgressIndicator())
              : state.searchResults.isEmpty
                  ? const Center(
                      child: Text('搜索卡名开始组卡',
                          style: TextStyle(color: Colors.white38)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 76,
                        childAspectRatio: 59 / 86,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: state.searchResults.length,
                      itemBuilder: (context, index) {
                        final info = state.searchResults[index];
                        return _PoolCard(
                          info: info,
                          inDeckCount: state.deck.countOf(info.code),
                          banlistStatus:
                              controller.banlistStatusOf(info.code),
                          onAdd: () => _addCard(controller, info),
                          onTap: () => setState(() {
                            _focusedCard = info;
                            _focusedFromDeck = false;
                            _focusedZone = null;
                            _detailLoading = false;
                          }),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _addCard(EditorController controller, CardInfo info) {
    final result = controller.addCard(info);
    if (result != AddCardResult.ok) {
      final message = switch (result) {
        AddCardResult.copyLimitExceeded => '同名卡最多 3 张',
        AddCardResult.zoneFull => '目标区域已满',
        AddCardResult.wrongZone => '该卡不能加入此区域',
        AddCardResult.ok => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  Future<void> _showCardInfo(int code, {DeckZone? zone}) async {
    final seq = ++_detailRequestSeq;
    final cached = ServiceSingleton.instance.dataService.getCardCached(code);
    setState(() {
      _focusedCard = cached;
      _focusedFromDeck = zone != null;
      _focusedZone = zone;
      _detailLoading = cached == null;
    });
    if (cached != null) return;
    // 缓存未命中（例如从卡池刚加进卡组的卡）：异步取卡并写缓存，下次点击即秒开。
    try {
      final info = await ServiceSingleton.instance.dataService.getCard(code);
      if (!mounted || seq != _detailRequestSeq) return;
      setState(() {
        _focusedCard = info;
        _detailLoading = false;
      });
    } catch (_) {
      if (mounted && seq == _detailRequestSeq) {
        setState(() => _detailLoading = false);
      }
    }
  }

  /// 搜索框 + 禁限卡环境（OCG/408）+ 禁限卡表选择 + 禁限卡表入口，同一行。
  Widget _buildSearchAndBanlistBar(
      EditorState state, EditorController controller) {
    final selectedHash = state.availableBanlists
            .any((t) => t.hash == state.selectedBanlistHash)
        ? state.selectedBanlistHash
        : null;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索卡名…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF14203A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => controller.search(v),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('OCG')),
              ButtonSegment(value: 1, label: Text('408')),
            ],
            selected: {state.environment},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (values) {
              if (values.isNotEmpty) controller.setEnvironment(values.first);
            },
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14203A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedHash,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: const Color(0xFF14203A),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Colors.white54, size: 18),
                  hint: Text(
                    state.loadingBanlists ? '加载禁限卡表中…' : '禁限卡表',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  items: state.availableBanlists
                      .map((t) => DropdownMenuItem<int>(
                            value: t.hash,
                            child: Text(
                              t.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: state.loadingBanlists
                      ? null
                      : (v) => controller.selectBanlist(v),
                ),
              ),
            ),
          ),
          // 查看禁限卡表弹窗入口
          IconButton(
            tooltip: '查看禁限卡表',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu_book,
                size: 18, color: Colors.white70),
            onPressed: state.selectedBanlistHash == null
                ? null
                : () {
                    final table = controller.selectedBanlist;
                    if (table == null) return;
                    BanlistDetailDialog.show(
                      context,
                      lfTable: table,
                      cardLoader:
                          ServiceSingleton.instance.dataService.getCard,
                    );
                  },
          ),
        ],
      ),
    );
  }

  /// 搜索筛选：四大类（怪兽/额外卡/魔法/陷阱）外露，各大类带子筛选项。
  Widget _buildFilterBar(EditorState state, EditorController controller) {
    final filter = state.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 四大类（可多选），子筛选项只作用于所属大类，不跨类。
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('怪兽', filter.monster, const Color(0xFFFFB300),
                  () => controller.toggleCategory(CardCategory.monster)),
              _chip('额外卡', filter.extra, const Color(0xFFB388FF),
                  () => controller.toggleCategory(CardCategory.extra)),
              _chip('魔法', filter.spell, const Color(0xFF4FC3F7),
                  () => controller.toggleCategory(CardCategory.spell)),
              _chip('陷阱', filter.trap, const Color(0xFFFF8A80),
                  () => controller.toggleCategory(CardCategory.trap)),
              if (!filter.isDefault)
                GestureDetector(
                  onTap: () => controller.clearFilters(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2230),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0xFF5A3A4A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: Color(0xFFE0A0B0)),
                        SizedBox(width: 2),
                        Text('重置',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFE0A0B0))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (filter.monster) ...[
            const SizedBox(height: 4),
            _subGroup('属性', _attributeOptions, filter.attributes,
                controller.toggleMonsterAttribute),
            _subGroup('种族', _raceOptions, filter.races,
                controller.toggleMonsterRace),
          ],
          if (filter.extra) ...[
            const SizedBox(height: 4),
            _subGroup('额外种类', _extraTypeOptions, filter.extraTypes,
                controller.toggleExtraType),
          ],
          if (filter.spell) ...[
            const SizedBox(height: 4),
            _subGroup('魔法种类', _spellTypeOptions, filter.spellTypes,
                controller.toggleSpellType),
          ],
          if (filter.trap) ...[
            const SizedBox(height: 4),
            _subGroup('陷阱种类', _trapTypeOptions, filter.trapTypes,
                controller.toggleTrapType),
          ],
        ],
      ),
    );
  }

  /// 大类/子类通用 chip。
  Widget _chip(String label, bool selected, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.25) : const Color(0xFF344555),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0xFF455A64),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? accent : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _subGroup(
    String title,
    List<(String, int)> options,
    Set<int> selected,
    Future<void> Function(int) onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.9,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: options
                  .map((o) => _chip(
                        o.$1,
                        selected.contains(o.$2),
                        const Color(0xFF1B7FA8),
                        () => onToggle(o.$2),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeck(EditorState state, EditorController controller) {
    final deck = state.deck;
    return Column(
      children: [
        // 校验错误条
        if (state.hasErrors)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x33FFD75A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              [...state.structuralErrors, ...state.banlistErrors]
                  .take(2)
                  .join('\n'),
              style: const TextStyle(color: Color(0xFFFFD75A), fontSize: 11),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              _buildZone(controller, deck, DeckZone.main, '主卡组'),
              _buildZone(controller, deck, DeckZone.extra, '额外卡组'),
              _buildZone(controller, deck, DeckZone.side, '副卡组'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZone(
    EditorController controller,
    DeckEditState deck,
    DeckZone zone,
    String title,
  ) {
    return DeckZoneGrid(
      title: title,
      cards: deck.zoneOf(zone),
      onCardTap: (code) => _showCardInfo(code, zone: zone),
      onRemove: (code) => controller.removeCard(code, zone),
      banlistStatusOf: controller.banlistStatusOf,
    );
  }

  Future<void> _copyCardCode(int code) async {
    await Clipboard.setData(ClipboardData(text: code.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('卡密已复制')),
    );
  }

  /// 详情栏「×」：从焦点卡所在分区移出一张。
  void _removeFocused(EditorController controller) {
    final card = _focusedCard;
    final zone = _focusedZone;
    if (card == null || zone == null) return;
    final removed = controller.removeCard(card.code, zone);
    // 全部移出后，焦点转为「卡池」语义，按钮切换为「+」。
    if (removed &&
        ref.read(editorControllerProvider).deck.countOf(card.code) == 0) {
      setState(() {
        _focusedFromDeck = false;
        _focusedZone = null;
      });
    }
  }

  Widget _buildDetail(EditorController controller) {
    final card = _focusedCard;
    if (card == null) {
      return Center(
        child: _detailLoading
            ? const CircularProgressIndicator()
            : const Text('单击卡片查看详情',
                style: TextStyle(color: Colors.white38)),
      );
    }
    final banlistStatus = controller.banlistStatusOf(card.code);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 卡图高度占详情栏可用高度的一半。
        final imageHeight = constraints.maxHeight * 0.5;
        final imageWidth = imageHeight * 59 / 86;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CardImage(
                  code: card.code,
                  width: imageWidth,
                  height: imageHeight,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (banlistStatus != null)
                  BanlistCornerBadge(status: banlistStatus),
                const SizedBox(width: 8),
                _DetailActionButton(
                  tooltip: _focusedFromDeck ? '移出卡组' : '加入卡组',
                  color: _focusedFromDeck
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF1B7FA8),
                  icon: _focusedFromDeck ? Icons.close : Icons.add,
                  onTap: _focusedFromDeck
                      ? () => _removeFocused(controller)
                      : () => _addCard(controller, card),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '卡密 ${card.code}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '复制卡密',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  iconSize: 15,
                  icon: const Icon(Icons.copy, color: Color(0xFF1B7FA8)),
                  onPressed: () => _copyCardCode(card.code),
                ),
              ],
            ),
            if (card.attack >= 0) ...[
              const SizedBox(height: 4),
              Text(
                'ATK ${card.attack} / DEF ${card.defense}',
                style: const TextStyle(color: Color(0xFFFFD75A), fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              card.desc,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, EditorController controller) async {
    final ok = await controller.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已保存' : '保存失败')),
      );
      if (ok) Navigator.of(context).maybePop();
    }
  }
}

class _DeckNameField extends StatefulWidget {
  const _DeckNameField({required this.name, required this.onSubmitted});

  final String name;
  final ValueChanged<String> onSubmitted;

  @override
  State<_DeckNameField> createState() => _DeckNameFieldState();
}

class _DeckNameFieldState extends State<_DeckNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant _DeckNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name &&
        _controller.text != widget.name) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({
    required this.info,
    required this.inDeckCount,
    this.banlistStatus,
    required this.onAdd,
    required this.onTap,
  });

  final CardInfo info;
  final int inDeckCount;
  final String? banlistStatus;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CardImage(code: info.code, width: 76, height: 110),
          ),
          // 禁限角标（左上）
          if (banlistStatus != null)
            Positioned(
              top: 2,
              left: 2,
              child: BanlistCornerBadge(status: banlistStatus!),
            ),
          // 已入组数量（右下）
          if (inDeckCount > 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B7FA8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$inDeckCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          // 加卡按钮（右上）
          Positioned(
            right: 2,
            top: 2,
            child: _AddButton(onTap: onAdd),
          ),
        ],
      ),
    );
  }
}

/// 右上角圆形「+」加卡按钮。
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF1B7FA8),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 12, color: Colors.white),
      ),
    );
  }
}

/// 详情栏卡片动作按钮：「+」加入卡组 / 「×」移出卡组。
class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.onTap,
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}
