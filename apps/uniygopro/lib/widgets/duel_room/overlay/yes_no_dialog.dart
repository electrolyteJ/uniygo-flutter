import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../../image/card_image.dart';

class YesNoDialog extends StatelessWidget {
  final String message;
  final int? cardCode;
  final void Function(int code)? onInspectCard;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const YesNoDialog({
    super.key,
    required this.message,
    this.cardCode,
    this.onInspectCard,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final code = cardCode;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '确认',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (code != null && code > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onInspectCard == null ? null : () => onInspectCard!(code),
              child: CardImage(
                code: code,
                width: 120,
                height: 172,
                showCodeFallback: false,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onNo,
                child: const Text('否', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onYes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('是'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

@Preview(name: 'YesNoDialog', size: Size(360, 280))
Widget yesNoDialogPreview() => const YesNoDialog(
  message: '是否发动效果？',
  cardCode: 46986414,
  onYes: _noop,
  onNo: _noop,
);

void _noop() {}
