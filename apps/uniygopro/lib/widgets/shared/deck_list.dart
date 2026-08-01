import 'package:flutter/material.dart';

class DeckListWidget extends StatelessWidget {
  final List<int> codes;
  final bool vertical;
  final void Function(int code)? onTap;
  const DeckListWidget({super.key, required this.codes, this.vertical = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final builder = ListView.builder(
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal, itemCount: codes.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => onTap?.call(codes[i]),
        child: Container(width: 45, height: 64, margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.brown)),
            child: Center(child: Text('${codes[i]}', style: const TextStyle(fontSize: 8)))),
      ),
    );
    return SizedBox(height: vertical ? null : 70, width: vertical ? 200 : null, child: builder);
  }
}
