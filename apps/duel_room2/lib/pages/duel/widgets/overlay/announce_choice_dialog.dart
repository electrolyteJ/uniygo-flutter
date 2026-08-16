import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../models/select_state.dart';

/// 宣言数值/属性/种族的通用选择弹窗：从给定选项列表中选一项。
///
/// 选项由 [SelectOption.label] 展示文本、[SelectOption.code] 存原始值；
/// 点击后回传该选项的下标（引擎按下标解析宣言结果）。
class AnnounceChoiceDialog extends StatelessWidget {
  final String title;
  final List<SelectOption> options;
  final void Function(int index) onSelect;

  const AnnounceChoiceDialog({
    super.key,
    required this.title,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF09111A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x5500F0FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < options.length; i++)
                        FilledButton(
                          onPressed: () => onSelect(i),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111D2A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(88, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0x5500F0FF),
                              ),
                            ),
                          ),
                          child: Text(
                            options[i].label ?? '${options[i].code}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'AnnounceChoiceDialog',
  size: Size(480, 320),
  brightness: Brightness.dark,
)
Widget previewAnnounceChoiceDialog() => AnnounceChoiceDialog(
  title: '宣言属性',
  options: const [
    SelectOption(code: 0x01, label: '地'),
    SelectOption(code: 0x02, label: '水'),
    SelectOption(code: 0x04, label: '炎'),
    SelectOption(code: 0x10, label: '光'),
    SelectOption(code: 0x20, label: '暗'),
  ],
  onSelect: (_) {},
);
