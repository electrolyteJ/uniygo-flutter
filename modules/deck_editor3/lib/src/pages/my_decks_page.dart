import 'package:account_mycard/account_mycard.dart';
import 'package:biz/service_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:resource_data/deck_info.dart';
import 'package:resource_deck_mdpro3/services/deck_api_client.dart';

import '../deck_state/editor_controller.dart';
import '../deck_state/my_decks_controller.dart';
import 'deck_editor_page.dart';

/// 我的卡组页：本地卡组 CRUD + YDK 导入导出 + 发布到市场。
class MyDecksPage extends ConsumerWidget {
  const MyDecksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(myDecksControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: '导入 YDK',
            backgroundColor: const Color(0xFF14203A),
            onPressed: () => _importYdk(context, ref),
            child: const Icon(Icons.download, size: 18),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'new',
            tooltip: '新建卡组',
            backgroundColor: const Color(0xFF1B7FA8),
            onPressed: () => _newDeck(context, ref),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败：$e',
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (decks) {
          if (decks.isEmpty) {
            return const Center(
              child: Text('暂无卡组，点右下角新建或导入',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: decks.length,
            itemBuilder: (context, index) =>
                _DeckListTile(deck: decks[index]),
          );
        },
      ),
    );
  }

  Future<void> _newDeck(BuildContext context, WidgetRef ref) async {
    final name = await _askText(context, '新建卡组', '卡组名');
    if (name == null || name.trim().isEmpty) return;
    final editor = ref.read(editorControllerProvider.notifier);
    editor.newDeck();
    editor.rename(name.trim());
    if (context.mounted) _openEditor(context);
  }

  Future<void> _importYdk(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14203A),
        title: const Text('导入 YDK', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            hintText: '粘贴 YDK 文本…',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (content == null || content.trim().isEmpty) return;
    if (!context.mounted) return;
    final name = await _askText(context, '导入为', '卡组名');
    if (name == null || name.trim().isEmpty) return;
    final deck = await ref
        .read(myDecksControllerProvider.notifier)
        .importYdk(content, name.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deck != null ? '导入成功' : '导入失败：格式错误')),
      );
    }
  }

  static void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderScope(child: DeckEditor3Page()),
      ),
    );
  }

  static Future<String?> _askText(
    BuildContext context,
    String title,
    String hint,
  ) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14203A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _DeckListTile extends ConsumerWidget {
  const _DeckListTile({required this.deck});

  final DeckInfo deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: const Color(0xFF14203A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.style, color: Color(0xFF37E2FF)),
        title: Text(
          deck.deckName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '主 ${deck.mainCount} · 额外 ${deck.extraCount} · 副 ${deck.sideCount}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: const Color(0xFF14203A),
          onSelected: (action) =>
              _onAction(context, ref, action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Text('重命名',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Text('导出 YDK',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'publish',
              child: Text('发布到卡组市场',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
        onTap: () {
          ref.read(editorControllerProvider.notifier).loadDeck(deck);
          MyDecksPage._openEditor(context);
        },
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final decks = ref.read(myDecksControllerProvider.notifier);
    switch (action) {
      case 'rename':
        final name = await MyDecksPage._askText(
          context,
          '重命名',
          '新卡组名',
        );
        if (name == null || name.trim().isEmpty) return;
        await decks.saveDeck(deck.toDeckInfoCopy(rename: name.trim()));
      case 'export':
        final ydk =
            ServiceSingleton.instance.dataService.exportToYdk(deck);
        await Clipboard.setData(ClipboardData(text: ydk));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('YDK 已复制到剪贴板')),
          );
        }
      case 'publish':
        await _publish(context, ref);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF14203A),
            title: const Text('删除卡组',
                style: TextStyle(color: Colors.white)),
            content: Text('确定删除「${deck.deckName}」吗？',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed == true) await decks.deleteDeck(deck.deckName);
    }
  }

  /// 发布到 MDPro3 卡组市场（二期）：需 MyCard 登录态。
  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final accountApi = context.read<MyCardAccountApi>();
    final account = accountApi.account;
    if (!accountApi.isLoggedIn || account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在首页登录 MyCard 账号再发布')),
      );
      return;
    }
    try {
      final api = DeckApiClient();
      final deckId = await api.generateDeckId();
      await api.uploadDeck(
        deck: MdPro3DeckInfo(
          deckId: deckId,
          name: deck.deckName,
          contributor: account.username,
          userId: account.id,
          mainDeck: deck.mainDeck,
          extraDeck: deck.extraDeck,
          sideDeck: deck.sideDeck,
        ),
        userId: account.id,
        contributor: account.username,
        token: account.token,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已发布到卡组市场')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败：$e')),
        );
      }
    }
  }
}
