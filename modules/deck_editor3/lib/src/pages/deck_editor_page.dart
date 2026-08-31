import 'package:biz/service_singleton.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';

import '../deck_state/editor_controller.dart';
import '../deck_state/editor_rules.dart';
import '../widgets/deck_zone_grid.dart';

/// 全新组卡编辑器：三栏布局（卡池 | 卡组 | 详情），MDPro3 风格暗色科技风。
///
/// - 左栏卡池：搜索框 + 结果网格，点卡加卡（自动路由分区）
/// - 中栏卡组：主/额外/副三区网格，点卡减卡，计数与校验实时显示
/// - 右栏详情：当前选中卡大图 + 效果文本（点任意卡更新）
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

  @override
  void initState() {
    super.initState();
    final deck = widget.initialDeck;
    if (deck != null) {
      // 编辑器自带独立 ProviderScope，其 editorControllerProvider 与「我的卡组」
      // 页不在同一作用域，因此通过构造参数传入卡组，并在首帧后载入。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(editorControllerProvider.notifier).loadDeck(deck);
      });
    }
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
          Expanded(flex: 3, child: _buildDetail()),
        ],
      ),
    );
  }

  Widget _buildPool(EditorState state, EditorController controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
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
                          onTap: () => _addCard(controller, info),
                          onPreview: () =>
                              setState(() => _focusedCard = info),
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
      onCardTap: (code) => controller.removeCard(code, zone),
      onCardLongPress: (code) {
        final info = ServiceSingleton.instance.dataService.getCardCached(code);
        if (info != null) setState(() => _focusedCard = info);
      },
    );
  }

  Widget _buildDetail() {
    final card = _focusedCard;
    if (card == null) {
      return const Center(
        child: Text('长按卡片查看详情', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CardImage(code: card.code, width: 160, height: 233),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          card.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
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
    required this.onTap,
    required this.onPreview,
  });

  final CardInfo info;
  final int inDeckCount;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onPreview,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CardImage(code: info.code, width: 76, height: 110),
          ),
          if (inDeckCount > 0)
            Positioned(
              right: 2,
              top: 2,
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
        ],
      ),
    );
  }
}
