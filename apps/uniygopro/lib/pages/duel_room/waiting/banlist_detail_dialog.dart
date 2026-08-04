import 'package:flutter/material.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card/lf_table.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import '../../../widgets/deck_editor/card_detail_dialog.dart';

/// 禁限卡表详情弹窗
///
/// 展示禁限卡表的完整内容：元数据（表名、日期）、统计摘要（各限制类型数量）、
/// 按限制类型分组的卡片列表。支持 TabBar 和垂直堆叠两种视图模式。
class BanlistDetailDialog extends StatefulWidget {
  final LfTable lfTable;

  const BanlistDetailDialog({super.key, required this.lfTable});

  /// 显示禁限卡表详情弹窗
  static Future<void> show(BuildContext context, {required LfTable lfTable}) {
    return showDialog(
      context: context,
      builder: (context) => BanlistDetailDialog(lfTable: lfTable),
    );
  }

  @override
  State<BanlistDetailDialog> createState() => _BanlistDetailDialogState();
}

class _BanlistDetailDialogState extends State<BanlistDetailDialog>
    with SingleTickerProviderStateMixin {
  bool _isTabMode = true;
  late final TabController _tabController;
  final _tabColors = <Color>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabColors
      ..clear()
      ..addAll([
        Theme.of(context).colorScheme.error,
        Colors.orange,
        Colors.yellow.shade700,
      ]);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  List<LfInfo> _filterByType(LfType type) {
    return widget.lfTable.lfInfos.values
        .where((info) => info.limit == type)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final forbidden = _filterByType(LfType.forbidden);
    final limited = _filterByType(LfType.limited);
    final semiLimited = _filterByType(LfType.semiLimited);
    final total = forbidden.length + limited.length + semiLimited.length;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.75,
          maxHeight: screenSize.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme),
            // 统计摘要栏
            _buildStatsBar(theme, forbidden, limited, semiLimited, total),
            // 卡片列表
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isTabMode
                    ? _buildTabView(forbidden, limited, semiLimited)
                    : _buildStackedView(theme, forbidden, limited, semiLimited),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lfTable.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.lfTable.date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '生效日期: ${widget.lfTable.date}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isTabMode ? Icons.view_list : Icons.tab),
            tooltip: _isTabMode ? '切换为列表视图' : '切换为标签视图',
            onPressed: () => setState(() => _isTabMode = !_isTabMode),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(
    ThemeData theme,
    List<LfInfo> forbidden,
    List<LfInfo> limited,
    List<LfInfo> semiLimited,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _StatChip(
            label: '禁止',
            count: forbidden.length,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          const Text('·', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 4),
          _StatChip(label: '限制', count: limited.length, color: Colors.orange),
          const SizedBox(width: 4),
          const Text('·', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 4),
          _StatChip(
            label: '准限制',
            count: semiLimited.length,
            color: Colors.yellow.shade700,
          ),
          const Spacer(),
          Text(
            '总计: $total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(
    List<LfInfo> forbidden,
    List<LfInfo> limited,
    List<LfInfo> semiLimited,
  ) {
    final index = _tabController.index;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '禁止 (${forbidden.length})'),
            Tab(text: '限制 (${limited.length})'),
            Tab(text: '准限制 (${semiLimited.length})'),
          ],
          indicatorColor: _tabColors[index],
          labelColor: _tabColors[index],
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
        ),
        Flexible(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CardGrid(items: forbidden),
              _CardGrid(items: limited),
              _CardGrid(items: semiLimited),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedView(
    ThemeData theme,
    List<LfInfo> forbidden,
    List<LfInfo> limited,
    List<LfInfo> semiLimited,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forbidden.isNotEmpty) ...[
            _SectionHeader(
              label: '禁止',
              count: forbidden.length,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 8),
            _CardWrap(items: forbidden),
            const SizedBox(height: 16),
          ],
          if (limited.isNotEmpty) ...[
            _SectionHeader(
              label: '限制',
              count: limited.length,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _CardWrap(items: limited),
            const SizedBox(height: 16),
          ],
          if (semiLimited.isNotEmpty) ...[
            _SectionHeader(
              label: '准限制',
              count: semiLimited.length,
              color: Colors.yellow.shade700,
            ),
            const SizedBox(height: 8),
            _CardWrap(items: semiLimited),
            const SizedBox(height: 16),
          ],
          if (widget.lfTable.lfInfos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('暂无禁限卡数据', style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}

// -- 子组件 --

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CardGrid extends StatelessWidget {
  final List<LfInfo> items;

  const _CardGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('此分类暂无卡片', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.55,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _CardTile(info: items[index], allItems: items, index: index),
      ),
    );
  }
}

class _CardWrap extends StatelessWidget {
  final List<LfInfo> items;

  const _CardWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const maxCardWidth = 120.0;
        const aspectRatio = 0.55;
        final crossAxisCount = (constraints.maxWidth / maxCardWidth)
            .ceil()
            .clamp(2, 6);
        final width =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount.clamp(0, maxCardWidth);
        final height = width / aspectRatio;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(items.length, (i) {
            return SizedBox(
              width: width,
              height: height,
              child: _CardTile(info: items[i], allItems: items, index: i),
            );
          }),
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final LfInfo info;
  final List<LfInfo> allItems;
  final int index;

  const _CardTile({
    required this.info,
    required this.allItems,
    required this.index,
  });

  static const _imageBaseUrl =
      'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: () {
              _CardDetailNavigator.show(
                context,
                allItems: allItems,
                startIndex: index,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                '$_imageBaseUrl/${info.code}.jpg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          info.name,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// -- 卡片详情导航弹窗 --

class _CardDetailNavigator extends StatefulWidget {
  final List<LfInfo> allItems;
  final int startIndex;

  const _CardDetailNavigator({
    required this.allItems,
    required this.startIndex,
  });

  static void show(
    BuildContext context, {
    required List<LfInfo> allItems,
    required int startIndex,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) =>
          _CardDetailNavigator(allItems: allItems, startIndex: startIndex),
    );
  }

  @override
  State<_CardDetailNavigator> createState() => _CardDetailNavigatorState();
}

class _CardDetailNavigatorState extends State<_CardDetailNavigator> {
  late int _currentIndex;
  final _cardService = ServiceFactory.create<CardService>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
  }

  void _goPrevious() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _goNext() {
    if (_currentIndex < widget.allItems.length - 1)
      setState(() => _currentIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.allItems[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   automaticallyImplyLeading: false,
      //   title: Text(
      //     '${info.name}  (${_currentIndex + 1}/${widget.allItems.length})',
      //     style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
      //   ),
      //   centerTitle: true,
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.close),
      //       onPressed: () => Navigator.pop(context),
      //     ),
      //   ],
      // ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder(
              future: _cardService.getCard(info.code),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final card = snapshot.data;
                if (card == null) {
                  return Center(
                    child: Text(
                      '无法加载卡片数据',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  );
                }
                return CardDetailDialog(card: card, showAddButton: false);
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  icon: Icons.chevron_left,
                  enabled: _currentIndex > 0,
                  onTap: _goPrevious,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentIndex + 1}/${widget.allItems.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                _ArrowButton(
                  icon: Icons.chevron_right,
                  enabled: _currentIndex < widget.allItems.length - 1,
                  onTap: _goNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Center(
        child: IconButton(
          icon: Icon(
            icon,
            size: 36,
            color: enabled ? Colors.white : Colors.white24,
          ),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }
}
