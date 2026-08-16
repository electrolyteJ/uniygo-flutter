import 'dart:math' as math;

import 'select_state.dart';

/// MSG_SELECT_SUM 引擎校验的纯函数移植，
/// 对应 ocgcore `field::select_with_sum_limit` 的回包检查
/// （packages/ocgcore/vendor/ocgcore/playerop.cpp:690-751）。
///
/// 参数语义与 [SelectState] 一致：
/// - [mustOptions]：必选段（msg.mustSelectCards），引擎回包中占位、不可勾选；
/// - [options]：可选段（msg.selectableCards）；
/// - [selectedIndices]：可选段内的下标集合（相对 [options]，升序参与校验）；
/// - [sumTarget]：目标合计（msg.levelSum，引擎 acc）；
/// - [sumExact]：msg.max == 0 的精确/溢出合计模式；
/// - [min]/[max]：msg.min / msg.max（仅非精确模式限制数量）。
///
/// 纯函数、无副作用，便于表驱动回归测试。
bool sumSelectionIsValid({
  required List<SelectOption> mustOptions,
  required List<SelectOption> options,
  required int sumTarget,
  required bool sumExact,
  required int min,
  required int max,
  required Set<int> selectedIndices,
}) {
  for (final index in selectedIndices) {
    if (index < 0 || index >= options.length) return false;
  }
  final orderedIndices = selectedIndices.toList()..sort();
  if (sumExact) {
    // max==0：无数量限制，窗口判定 `mx >= acc && sum - mn < acc`。
    // ms = min(o1, o2 with o2==0→o1)，mx = Σmax(o1, o2)，mn = min(ms)。
    var sum = 0;
    var mx = 0;
    var mn = 0x7fffffff;
    void accumulate(SelectOption option) {
      final (o1, o2) = sumParamsOf(option);
      final ms = (o2 != 0 && o2 < o1) ? o2 : o1;
      sum += ms;
      mx += math.max(o1, o2);
      if (ms < mn) mn = ms;
    }

    for (final option in mustOptions) {
      accumulate(option);
    }
    for (final index in orderedIndices) {
      accumulate(options[index]);
    }
    return mx >= sumTarget && sum - mn < sumTarget;
  }

  // max!=0：总数（含必选）须在 [min+mcount, max+mcount] 内，
  // 且递归 select_sum_check1 以 acc=sumTarget 通过。
  final mcount = mustOptions.length;
  final total = mcount + selectedIndices.length;
  if (total < min + mcount || total > max + mcount) return false;
  final params = <(int, int)>[
    for (final option in mustOptions) sumParamsOf(option),
    for (final index in orderedIndices) sumParamsOf(options[index]),
  ];
  return _selectSumCheck1(params, params.length, 0, sumTarget, 0xffff);
}

/// 把选项的 level/level2 还原为引擎 get_sum_params 的 (o1, o2)
/// （packages/ocgcore/vendor/ocgcore/field.cpp:2916-2923）。
///
/// level2 为 null/0 时等价 o2==0：只有 o1 生效。
(int, int) sumParamsOf(SelectOption option) {
  final o1 = option.level ?? 0;
  final raw = option.level2 ?? 0;
  return (o1, raw == 0 ? 0 : raw);
}

/// `select_sum_check1`（playerop.cpp:639-650）的逐行移植。
///
/// [oparam] 顺序与引擎一致：必选段在前，其后是响应提交的可选段顺序
/// （客户端按可选段下标升序提交，见 SelectWindowNotifier.respondSelectSum）。
bool _selectSumCheck1(
  List<(int, int)> oparam,
  int size,
  int index,
  int acc,
  int opmin,
) {
  if (acc == 0 || index == size) return false;
  final (o1, o2) = oparam[index];
  if (index == size - 1) {
    return (acc == o1 && acc + opmin > o1) ||
        (o2 != 0 && acc == o2 && acc + opmin > o2);
  }
  return (acc > o1 &&
          _selectSumCheck1(
            oparam,
            size,
            index + 1,
            acc - o1,
            math.min(o1, opmin),
          )) ||
      (o2 > 0 &&
          acc > o2 &&
          _selectSumCheck1(
            oparam,
            size,
            index + 1,
            acc - o2,
            math.min(o2, opmin),
          ));
}
