import 'package:flutter/material.dart';

class ChainIndicator extends StatelessWidget {
  final int chainCount;
  const ChainIndicator({super.key, required this.chainCount});

  @override
  Widget build(BuildContext context) {
    if (chainCount == 0) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(8)),
        child: Text('Chain $chainCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
  }
}
