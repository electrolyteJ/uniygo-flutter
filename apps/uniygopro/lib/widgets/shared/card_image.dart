import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../pages/duel_room/duel/duel_field_store.dart';

class CardImage extends StatelessWidget {
  final int code;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showCodeFallback;

  const CardImage({
    super.key,
    required this.code,
    this.width = 65,
    this.height = 90,
    this.fit = BoxFit.cover,
    this.showCodeFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final duelStore = context
        .read<
          DuelFieldStore
        >(); // Ensure the widget rebuilds when the code changes
    final url = duelStore.getCardImageUrl(code);
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
          fit: fit,
          errorBuilder: (_, e, s) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
              ),
            ),
            child: showCodeFallback
                ? Center(
                    child: Text('$code', style: const TextStyle(fontSize: 8)),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
