import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../stores/duel_room_state.dart';
import '../widgets/duel_room/chain_indicator.dart';
import '../widgets/duel_room/duel_overlay.dart';
import '../widgets/playmat/playmat.dart';

class DuelFieldPage extends StatelessWidget {
  final DuelRoomState state;

  const DuelFieldPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Playmat(duel: state),
          if (state.isWaitingForInput) DuelOverlay(state: state),
          if (state.chains.isNotEmpty)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: ChainIndicator(chainCount: state.chains.length),
              ),
            ),
          Positioned(top: 8, left: 8, child: _buildBackButton(context)),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _confirmBack(context),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _confirmBack(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出决斗'),
        content: const Text('确定要退出当前决斗吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              state.reset();
              Navigator.of(ctx).pop();
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
