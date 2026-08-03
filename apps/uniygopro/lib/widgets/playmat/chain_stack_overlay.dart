import 'package:flutter/material.dart';
import '../../models/ChainLink.dart';

class ChainStackOverlay extends StatelessWidget {
  final List<ChainLink> chains;

  const ChainStackOverlay({super.key, required this.chains});

  @override
  Widget build(BuildContext context) {
    if (chains.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: chains.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final link = entry.value;
          
          const goldGlow = Color(0xFFFFD700);
          const cyanGlow = Color(0xFF00F0FF);
          final color = index % 2 != 0 ? goldGlow : cyanGlow;

          return _PulseChainBadge(
            index: index,
            name: 'Card #${link.code}', // 实际应从 cardInfo 获取
            color: color,
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

  const _PulseChainBadge({required this.index, required this.name, required this.color});

  @override
  State<_PulseChainBadge> createState() => _PulseChainBadgeState();
}

class _PulseChainBadgeState extends State<_PulseChainBadge> with SingleTickerProviderStateMixin {
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
      scale: Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xEB0A101A), // rgba(10, 16, 26, 0.95)
          border: Border.all(color: widget.color, width: 1.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.7),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          'CHAIN ${widget.index}: ${widget.name}',
          style: TextStyle(
            color: widget.color,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
