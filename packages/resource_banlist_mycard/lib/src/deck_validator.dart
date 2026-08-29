import 'package:resource_data/card_info.dart';
import 'package:resource_data/lf_table.dart';

/// 卡组校验器
///
/// 负责在客户端侧校验卡组是否合规：
/// - 基础规则：主卡组 40-60 张、额外 0-15 张、副卡组 0-15 张
/// - 同名卡规则：同一卡牌（含别名）最多 3 张
/// - 禁限卡表规则：禁止/限制/准限制卡的持有数量
class DeckValidator {
  final Map<int, LfInfo> lfInfos;

  const DeckValidator({required this.lfInfos});

  /// 校验卡组。
  ///
  /// 收集所有违规项，一次性返回完整的 [DeckValidationResult]。
  List<String> validate(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    final errors = <String>[];

    // ── 构建别名映射和名称映射 ──
    final allCards = [...main, ...extra, ...side];
    final aliases = <int, int>{};
    final nameMap = <int, String>{};

    for (final card in allCards) {
      if (card.alias != 0) {
        aliases[card.code] = card.alias;
      }
    }

    int resolveCode(int code) {
      final alias = aliases[code];
      return alias != null && alias != 0 ? alias : code;
    }

    for (final card in allCards) {
      final canonical = resolveCode(card.code);
      if (!nameMap.containsKey(canonical)) {
        nameMap[canonical] = card.name;
      }
    }

    // ── 1. 基础卡组数量规则 ──
    if (main.length < 40) {
      errors.add('主卡组不足40张（当前${main.length}张）');
    }
    if (main.length > 60) {
      errors.add('主卡组超过60张（当前${main.length}张）');
    }
    if (extra.length > 15) {
      errors.add('额外卡组超过15张（当前${extra.length}张）');
    }
    if (side.length > 15) {
      errors.add('副卡组超过15张（当前${side.length}张）');
    }

    // ── 2. 同名卡规则 ──
    final countMap = <int, int>{};
    for (final card in allCards) {
      final canonical = resolveCode(card.code);
      countMap[canonical] = (countMap[canonical] ?? 0) + 1;
    }

    for (final entry in countMap.entries) {
      if (entry.value > 3) {
        final name = nameMap[entry.key];
        final label = name != null ? '$name(${entry.key})' : '${entry.key}';
        errors.add('$label 超过3张（当前${entry.value}张）');
      }
    }

    // ── 3. 禁限卡表规则 ──
    if (lfInfos.isNotEmpty) {
      for (final entry in countMap.entries) {
        final canonical = entry.key;
        final count = entry.value;
        final lfTable = lfInfos[canonical];
        if (lfTable == null) continue;

        final name = nameMap[canonical];
        final label = name != null ? '$name($canonical)' : '$canonical';

        switch (lfTable.limit) {
          case LfType.forbidden: // 禁止
            if (count >= 1) {
              errors.add('$label 是禁止卡');
            }
            break;
          case LfType.limited: // 限制
            if (count > 1) {
              errors.add('$label 是限制卡（最多1张，当前$count张）');
            }
            break;
          case LfType.semiLimited: // 准限制
            if (count > 2) {
              errors.add('$label 是准限制卡（最多2张，当前$count张）');
            }
            break;
          case LfType.unlimited:
            break; // 无限制
        }
      }
    }

    return errors;
  }
}
