import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pages/duel_room/field/duel_board_store.dart';

class CardImage extends StatelessWidget {
  final int code;
  final double width;
  final double height;

  const CardImage({super.key, required this.code, this.width = 65, this.height = 90});

  @override
  Widget build(BuildContext context) {
    final duelBoardStore = context.read<DuelBoardStore>(); // Ensure the widget rebuilds when the code changes
    final url = duelBoardStore.getCardImageUrl(code);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => Container(
            color: Colors.brown.shade300,
            child: Center(
              child: Text('$code', style: const TextStyle(fontSize: 8)),
            ),
          ),
        ),
      ),
    );
  }
}
