import 'dart:developer' as console;

import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resource_data/deck_info.dart' show DeckSummary;

import '../deck_state/square_controller.dart';
import 'deck_detail_page.dart';

/// 卡组市场页：MDPro3 卡组广场（搜索 + 排序 + 分页卡片流）。
class DeckSquarePage extends ConsumerWidget {
  const DeckSquarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(squareControllerProvider);
    final controller = ref.read(squareControllerProvider.notifier);
    return Column(
      children: [
        // 搜索 + 排序工具条
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索卡组名 / 贡献者…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF14203A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (v) =>
                      controller.refresh(keyword: v.trim()),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<SquareSort>(
                segments: const [
                  ButtonSegment(value: SquareSort.latest, label: Text('最新')),
                  ButtonSegment(value: SquareSort.like, label: Text('点赞')),
                  ButtonSegment(value: SquareSort.rank, label: Text('天梯')),
                ],
                selected: {state.sort},
                showSelectedIcon: false,
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
                onSelectionChanged: (s) =>
                    controller.refresh(sort: s.first),
              ),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: _DeckList(state: state),
          ),
        ),
      ],
    );
  }
}

class _DeckList extends ConsumerWidget {
  const _DeckList({required this.state});

  final SquareState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.error != null && state.decks.isEmpty) {
      console.log('Error: ${state.error}');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!,
                style: const TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: () =>
                  ref.read(squareControllerProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.decks.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.decks.isEmpty) {
      return const Center(
        child: Text('暂无卡组', style: TextStyle(color: Colors.white54)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          ref.read(squareControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 动态列数：横屏手机视口较窄，固定 6 列会导致 tile 过小、
          // 文字列溢出（RenderFlex overflow）；按可用宽度降列。
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1200
              ? 6
              : width >= 900
                  ? 5
                  : width >= 600
                      ? 4
                      : 3;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: state.decks.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.decks.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _DeckSquareTile(deck: state.decks[index]);
            },
          );
        },
      ),
    );
  }
}

class _DeckSquareTile extends StatelessWidget {
  const _DeckSquareTile({required this.deck});

  final DeckSummary deck;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DeckDetailPage(deckId: deck.deckId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14203A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E3A55)),
        ),
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 封面高度取格子可用高度，宽度按实卡比例 59:86 缩放。
            final coverHeight = constraints.maxHeight;
            final coverWidth = coverHeight * 59 / 86;
            return Row(
              children: [
            // 封面卡图；无封面卡时显示占位（deckCase 卡套非卡牌，
            // 不再被当作卡图 code 渲染，避免 404 空白）。
            _DeckCover(
              code: deck.coverCode,
              width: coverWidth,
              height: coverHeight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    deck.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    deck.contributor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.favorite,
                          size: 14, color: Color(0xFFFF5A5A)),
                      const SizedBox(width: 3),
                      Text(
                        '${deck.likeCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      if (deck.rank > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.emoji_events,
                            size: 14, color: Color(0xFFFFD75A)),
                        const SizedBox(width: 3),
                        Text(
                          '${deck.rank}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    ),
  );
  }
}

/// 封面缩略图：有封面卡时渲染卡图；无封面（coverCode == null，只有卡套）
/// 时显示中性占位，避免把卡套编号当卡图 code 渲染出 404 空白。
class _DeckCover extends StatelessWidget {
  const _DeckCover({this.code, required this.width, required this.height});

  final int? code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = code;
    if (c == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A55), Color(0xFF0E1626)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.style, color: Colors.white24, size: 22),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CardImage(code: c, width: width, height: height),
    );
  }
}
