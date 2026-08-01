import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SidePage extends StatelessWidget {
  const SidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('副卡组交换'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Side Deck')),
    );
  }
}
