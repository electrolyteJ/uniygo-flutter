import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

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
    return ResponsivePanel(
      maxWidth: 520,
      maxHeight: 560,
      header: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < options.length; i++)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: FilledButton(
                    onPressed: () => onSelect(i),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111D2A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(88, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0x5500F0FF)),
                      ),
                    ),
                    child: Text(
                      options[i].label ?? '${options[i].code}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
