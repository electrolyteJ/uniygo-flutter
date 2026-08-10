import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'deck_editor_store.dart';
import 'deck_editor_session.dart';
import '../../service_singleton.dart';
import '../../widgets/deck_editor/deck_list_panel.dart';
import '../../widgets/deck_editor/deck_edit_panel.dart';
import '../../widgets/deck_editor/card_search_bar.dart';
import '../../widgets/deck_editor/card_grid_view.dart';
import '../../widgets/deck_editor/card_list_view.dart';

class DeckEditorPage extends StatefulWidget {
  const DeckEditorPage({super.key, this.args});

  final DeckEditorRouteArgs? args;

  @override
  State<DeckEditorPage> createState() => _DeckEditorPageState();
}

class _DeckEditorPageState extends State<DeckEditorPage> {
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<DeckEditorStore>();
      await store.initialize();
      await store.loadDecks();
      await store.configureSession(widget.args);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canPop = Navigator.of(context).canPop();
    return PopScope<Object?>(
      canPop: !canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !canPop) {
          return;
        }
        final store = context.read<DeckEditorStore>();
        context.pop(store.lastSaveResult);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E2A38),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text("卡组编辑器"),
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
        ),
        body: _buildResponsiveLayout(theme),
      ),
    );
  }

  Widget _buildResponsiveLayout(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout(theme);
        } else {
          return _buildDesktopLayout(theme);
        }
      },
    );
  }

  // ── 桌面版布局 ──
  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // 左侧：卡组列表 (240px)
        const SizedBox(width: 240, child: DeckListPanel()),
        // 中间：搜索 + 结果
        Expanded(child: _buildMainContent(theme)),
        // 右侧：卡组编辑区 (380px)
        const SizedBox(width: 380, child: DeckEditPanel()),
      ],
    );
  }

  // ── 主内容区 ──
  Widget _buildMainContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部栏
        _buildAppBar(theme),
        // 搜索栏
        const CardSearchBar(),
        // 搜索结果
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  // ── 顶部栏 ──
  Widget _buildAppBar(ThemeData theme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A4A),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            '卡组编辑',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          // 卡组名输入框
          const _DeckNameInput(),
          const Spacer(),
          // 操作按钮
          _AppBarActions(),
        ],
      ),
    );
  }

  // ── 搜索结果 ──
  Widget _buildSearchResults() {
    return Consumer<DeckEditorStore>(
      builder: (context, store, child) {
        if (store.searchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '输入关键词搜索卡牌',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return store.isGridView ? const CardGridView() : const CardListView();
      },
    );
  }

  // ── 手机版布局 ──
  Widget _buildMobileLayout(ThemeData theme) {
    return Column(
      children: [
        // 顶部栏
        _buildMobileAppBar(theme),
        // 搜索栏
        const CardSearchBar(),
        // 搜索结果
        Expanded(child: _buildSearchResults()),
        // 底部卡组信息栏
        _buildMobileDeckBar(theme),
      ],
    );
  }

  // ── 手机版顶部栏 ──
  Widget _buildMobileAppBar(ThemeData theme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A4A),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(child: _DeckNameInput()),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveDeckAndNotify(context),
          ),
        ],
      ),
    );
  }

  // ── 手机版底部卡组栏 ──
  Widget _buildMobileDeckBar(ThemeData theme) {
    final store = context.watch<DeckEditorStore>();
    final deck = store.editingDeck;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A4A),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deck.deckName.isEmpty ? '未命名卡组' : deck.deckName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '主卡组 ${deck.mainCount} · 额外 ${deck.extraCount} · 备牌 ${deck.sideCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _isDrawerOpen = !_isDrawerOpen);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF1E2A38),
            ),
            child: const Text('展开编辑'),
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    ServiceSingleton.instance.uiSoundService.playBackNavigation();
    final store = context.read<DeckEditorStore>();
    if (Navigator.of(context).canPop()) {
      context.pop(store.lastSaveResult);
      return;
    }
    context.go('/');
  }
}

Future<void> _saveDeckAndNotify(BuildContext context) async {
  final store = context.read<DeckEditorStore>();
  final result = await store.saveDeck();
  if (!context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  if (!result.saved) {
    if (store.editingDeck.isDirty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(store.errorMessage ?? '卡组保存失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  final errors = result.validationErrors;
  final message = errors == null
      ? '卡组已保存'
      : errors.isEmpty
      ? '卡组已保存，当前卡组合规'
      : '卡组已保存，但仍不合规：${errors.first}';
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: errors == null || errors.isEmpty
          ? null
          : Colors.orange.shade800,
    ),
  );
}

// ── 卡组名输入框 ──
class _DeckNameInput extends StatefulWidget {
  const _DeckNameInput();

  @override
  State<_DeckNameInput> createState() => _DeckNameInputState();
}

class _DeckNameInputState extends State<_DeckNameInput> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeckEditorStore>();
    final deckName = store.editingDeck.deckName;
    final canRename = !store.lockDeckName;
    if (!_isEditing && _controller.text != deckName) {
      _controller.value = _controller.value.copyWith(
        text: deckName,
        selection: TextSelection.collapsed(offset: deckName.length),
        composing: TextRange.empty,
      );
    }

    if (!canRename) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          deckName.isEmpty ? '未命名卡组' : deckName,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _isEditing = true);
      },
      child: _isEditing
          ? SizedBox(
              width: 180,
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '输入卡组名称',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFFFB300)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFFFB300)),
                  ),
                ),
                onSubmitted: (value) {
                  final name = value.trim();
                  if (name.isNotEmpty && name != deckName) {
                    store.renameEditingDeck(name);
                  }
                  setState(() => _isEditing = false);
                },
                onTapOutside: (_) {
                  final name = _controller.text.trim();
                  if (name.isNotEmpty && name != deckName) {
                    store.renameEditingDeck(name);
                  }
                  setState(() => _isEditing = false);
                },
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                deckName.isEmpty ? '未命名卡组' : deckName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
    );
  }
}

// ── 操作按钮组 ──
class _AppBarActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeckEditorStore>();
    final sound = ServiceSingleton.instance.uiSoundService;

    return Row(
      children: [
        // 洗切
        _ActionIconButton(
          icon: Icons.shuffle,
          tooltip: '洗切',
          onPressed: store.editingDeck.totalCount > 0
              ? () {
                  sound.playButtonTap();
                  store.shuffleDeck();
                }
              : null,
        ),
        // 排序
        _ActionIconButton(
          icon: Icons.sort_by_alpha,
          tooltip: '排序',
          onPressed: store.editingDeck.totalCount > 0
              ? () {
                  sound.playButtonTap();
                  store.sortDeck();
                }
              : null,
        ),
        // 清空
        _ActionIconButton(
          icon: Icons.delete_outline,
          tooltip: '清空',
          onPressed: store.editingDeck.totalCount > 0
              ? () => _confirmClear(context, store)
              : null,
        ),
        // 撤销
        _ActionIconButton(
          icon: Icons.undo,
          tooltip: '撤销',
          onPressed: null, // TODO: 实现撤销
        ),
        const SizedBox(width: 8),
        // 导入
        _ActionTextButton(
          icon: Icons.file_download_outlined,
          label: '导入',
          onPressed: () => _importDeck(context, store),
        ),
        // 导出
        _ActionTextButton(
          icon: Icons.file_upload_outlined,
          label: '导出',
          onPressed: store.editingDeck.totalCount > 0
              ? () => _exportDeck(context, store)
              : null,
        ),
        // 保存
        _ActionTextButton(
          icon: Icons.save,
          label: '保存',
          isPrimary: true,
          onPressed: store.editingDeck.isDirty
              ? () => _saveDeckAndNotify(context)
              : null,
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context, DeckEditorStore store) {
    ServiceSingleton.instance.uiSoundService.playDialogOpen();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A4A),
        title: const Text('清空卡组'),
        content: const Text('确定要清空所有卡牌吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              store.clearDeck();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _importDeck(BuildContext context, DeckEditorStore store) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A4A),
        title: const Text('导入 YDK 卡组'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请粘贴 YDK 格式的卡组内容:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: '#created by ...\n#main\n23456789\n...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF455A64)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFB300)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E2A38),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isEmpty) return;

              await store.importDeckFromYdk(content, '导入的卡组');
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('导入成功')));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF1E2A38),
            ),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _exportDeck(BuildContext context, DeckEditorStore store) {
    final ydk = store.exportToYdk();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A4A),
        title: const Text('导出 YDK 卡组'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('卡组: ${store.editingDeck.deckName}'),
              const SizedBox(height: 8),
              Text(
                '主卡组: ${store.editingDeck.mainCount} | 额外: ${store.editingDeck.extraCount} | 备牌: ${store.editingDeck.sideCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF455A64)),
                ),
                child: SelectableText(
                  ydk,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ydk));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF1E2A38),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 图标按钮 ──
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: onPressed != null
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.3),
        hoverColor: const Color(0xFF344555),
      ),
    );
  }
}

// ── 文字按钮 ──
class _ActionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ActionTextButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: isPrimary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF1E2A38),
              ),
            )
          : TextButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: TextButton.styleFrom(
                foregroundColor: onPressed != null
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
    );
  }
}
