import 'package:flutter/foundation.dart';

/// 规则面板的一行下拉条目。
///
/// 面板本身不认识具体业务字段，只按 [label]/[options]/[selected] 渲染；
/// 调用方按需组合条目（赛制、环境、禁限卡表……），便于外部扩展。
@immutable
class RuleRowSpec {
  const RuleRowSpec({
    required this.key,
    required this.label,
    required this.options,
    required this.selected,
    this.onSelected,
  });

  final String key;
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int>? onSelected;
}

/// 规则面板的一行勾选项。
@immutable
class RuleCheckSpec {
  const RuleCheckSpec({
    required this.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String key;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}
