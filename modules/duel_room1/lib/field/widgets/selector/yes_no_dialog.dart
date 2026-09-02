import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

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
    return ResponsivePanel(
      maxWidth: 320,
      maxHeight: 480,
      header: const Text(
        '确认',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (code != null && code > 0) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 172),
                child: AspectRatio(
                  aspectRatio: 59 / 86,
                  child: InkWell(
                    onTap: onInspectCard == null
                        ? null
                        : () => onInspectCard!(code),
                    child: LayoutBuilder(
                      builder: (context, constraints) => CardImage(
                        code: code,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        showCodeFallback: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: onNo,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text('否', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onYes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('是'),
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
