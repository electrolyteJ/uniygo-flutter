import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/ChainLink.dart';
import '../../../pages/duel_room/duel/duel_field_store.dart';

class ChainStackOverlay extends StatelessWidget {
  final List<ChainLink> chains;

  const ChainStackOverlay({super.key, required this.chains});

  @override
  Widget build(BuildContext context) {
    if (chains.isEmpty) return const SizedBox.shrink();
    // watch：卡信息异步加载完成后能刷新出卡名
    final duelStore = context.watch<DuelFieldStore>();

    // v10 .chain：屏幕中心横向排列的金色连锁胶囊
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: chains.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final link = entry.value;
          final name =
              duelStore.getCardInfo(link.code)?.name ?? 'Card #${link.code}';

          return _PulseChainBadge(
            index: index,
            name: name,
            color: const Color(0xFFFFD700),
          );
        }).toList(),
      ),
    );
  }
}

class _PulseChainBadge extends StatefulWidget {
  final int index;
  final String name;
  final Color color;

  const _PulseChainBadge({
    required this.index,
    required this.name,
    required this.color,
  });

  @override
  State<_PulseChainBadge> createState() => _PulseChainBadgeState();
}

class _PulseChainBadgeState extends State<_PulseChainBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 1.06,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xC70A101A), // rgba(10, 16, 26, 0.78)
          border: Border.all(color: widget.color, width: 1.5),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.24),
              blurRadius: 20,
            ),
          ],
        ),
        child: Text(
          'CHAIN ${widget.index}: ${widget.name}',
          style: TextStyle(
            color: widget.color,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
