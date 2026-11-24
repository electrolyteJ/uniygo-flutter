import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deck_square/deck_square_page.dart';
import 'my_decks/my_decks_controller.dart';
import 'my_decks/my_decks_page.dart';

/// 卡组中心：市场 / 我的卡组 / 组卡器 三段，**卡组分区的唯一 UI 实现**。
///
/// 消费方：
/// - 宿主 uniygopro 大厅「卡组」Tab（[embedded] 内嵌，宿主提供 Scaffold）；
/// - 宿主 `/deck-hub` 独立路由（非内嵌，自带 Scaffold + AppBar）；
/// - apps/debug 的卡组中心入口（非内嵌，无组卡器注入时自动降为两段）。
///
/// 响应式档位由宿主注入而非模块读取：`AppLayout` 属于宿主应用层概念，
/// 模块反向依赖宿主会形成环，因此以 [pagePadding] / [editorBuilder] 参数传递。
class DeckHubPage extends StatelessWidget {
  const DeckHubPage({
    super.key,
    this.embedded = false,
    this.pagePadding = 12,
    this.editorBuilder,
  });

  /// 内嵌模式：不自建 Scaffold / AppBar（宿主已有外壳，避免双 AppBar）。
  final bool embedded;

  /// 页面外边距，由宿主按 AppLayout 档位注入（compact 12 / regular 20 / wide 28）。
  final double pagePadding;

  /// 第三段「组卡器」内容构建器。
  ///
  /// 组卡器来自 deck_editor1（[DeckEditorPage]），其依赖的 `DeckEditorStore`
  /// 由宿主在 app 级 provider 注册；模块不擅自引入该依赖，故由宿主注入。
  /// 为空时（如 apps/debug 未注册 store）自动降为「市场 / 我的卡组」两段，
  /// 不展示无法打开的入口。
  final WidgetBuilder? editorBuilder;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _DeckHubView(
        embedded: embedded,
        pagePadding: pagePadding,
        editorBuilder: editorBuilder,
      ),
    );
  }
}

class _DeckHubView extends ConsumerStatefulWidget {
  const _DeckHubView({
    required this.embedded,
    required this.pagePadding,
    this.editorBuilder,
  });

  final bool embedded;
  final double pagePadding;
  final WidgetBuilder? editorBuilder;

  @override
  ConsumerState<_DeckHubView> createState() => _DeckHubViewState();
}

class _DeckHubViewState extends ConsumerState<_DeckHubView> {
  int _segment = 0;

  /// 已访问过的分段：懒构建。组卡器首次打开才实例化 deck_editor1 的编辑器
  /// （其 initState 会加载禁限卡表并预搜索卡池），避免进卡组分区就拉全量数据。
  final Set<int> _visited = {0};

  int get _segmentCount => widget.editorBuilder == null ? 2 : 3;

  void _select(int index) {
    if (index == _segment || index >= _segmentCount) return;
    setState(() {
      _segment = index;
      _visited.add(index);
    });
    // 切到「我的卡组」时刷新列表，确保刚使用/新建/导入的卡组立即显示。
    if (index == 1) {
      ref.read(myDecksControllerProvider.notifier).refresh();
    }
  }

  Widget _segmentContent(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const DeckSquarePage(),
      1 => const MyDecksPage(),
      _ => widget.editorBuilder?.call(context) ?? const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<int>>[
      const ButtonSegment(
        value: 0,
        icon: Icon(Icons.storefront_outlined, size: 18),
        label: Text('卡组市场'),
      ),
      const ButtonSegment(
        value: 1,
        icon: Icon(Icons.folder_special_outlined, size: 18),
        label: Text('我的卡组'),
      ),
      if (_segmentCount > 2)
        const ButtonSegment(
          value: 2,
          icon: Icon(Icons.dashboard_customize_outlined, size: 18),
          label: Text('组卡器'),
        ),
    ];

    final body = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.pagePadding,
            widget.pagePadding * 0.6,
            widget.pagePadding,
            8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: segments,
              selected: {_segment},
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (values) {
                if (values.isNotEmpty) _select(values.first);
              },
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              for (var i = 0; i < _segmentCount; i++) _segmentContent(i),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF0C1220), child: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      appBar: AppBar(
        title: const Text('卡组中心'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}
