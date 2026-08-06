import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class YesNoDialog extends StatelessWidget {
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const YesNoDialog({
    super.key,
    required this.message,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('确认'),
    content: Text(message),
    actions: [
      TextButton(onPressed: onNo, child: const Text('否')),
      ElevatedButton(onPressed: onYes, child: const Text('是')),
    ],
  );
}

@Preview(name: 'YesNoDialog', size: Size(320, 180))
Widget yesNoDialogPreview() =>
    const YesNoDialog(message: '确定要结束这个回合吗？', onYes: _noop, onNo: _noop);

void _noop() {}
