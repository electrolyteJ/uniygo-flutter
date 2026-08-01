import 'package:flutter/material.dart';

class YesNoDialog extends StatelessWidget {
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const YesNoDialog({super.key, required this.message, required this.onYes, required this.onNo});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('确认'), content: Text(message),
    actions: [
      TextButton(onPressed: onNo, child: const Text('否')),
      ElevatedButton(onPressed: onYes, child: const Text('是')),
    ],
  );
}
