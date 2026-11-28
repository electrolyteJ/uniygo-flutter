/// 禁限卡表选项：从 MyCard 卡表服务加载，供规则面板下拉使用。
library;

import 'dart:developer' as console;

import 'package:biz/service_singleton.dart';
import 'package:resource_data/lf_table.dart';

/// 卡表目录：全局缓存一份，规则面板与建房参数共用。
///
/// 不提供「默认」占位：列表按卡表名里的日期倒序，第一项即最新卡表，
/// 未选择时直接使用最新卡表的 hash。
class BanlistUtil {
  /// 卡表 map（hash → LfTable）；服务未注册/未加载时返回空表，避免崩。
  static Map<int, LfTable> getTableMap() {
    try {
      return ServiceSingleton.instance.dataService.getAllLfTable();
    } catch (_) {
      return const {};
    }
  }

  /// 下拉索引 → lfTableHash（参数为卡表选项下标，不含「无禁限」）。
  static int hashAt(int index) {
    final options = getTableMap().values.toList();
    if (options.isEmpty) return 0;
    if (index >= options.length) return 0;
    return options[index.clamp(0, options.length - 1)].hash;
  }

  /// 非 233 下拉的卡表名（服务端顺序，不含「无禁限」）。
  static List<String> getOptionNames() =>
      [for (final option in getTableMap().values) option.name];

  /// 233 禁限下拉的标签：卡表名 + 「无禁限」。
  static List<String> getMercury233Labels() =>
      [...getOptionNames(), '无禁限'];

  /// 默认选中「无禁限」（下拉最后一项）。
  static int get noBanlistIndex => getMercury233Labels().length - 1;

  /// 233 卡片表序号（服务端列表顺序，1 起）：
  ///
  /// * > 0：服务器第 n 个卡表 → 房间串 LFn；
  /// * 0：不使用禁限卡表 → NF；
  /// * -1：卡表未加载 / 未知，不写禁限 token，走服务端默认卡表。
  static int mercury233IndexAt(int index) {
    final tableMap = getTableMap();
    console.log(" mercury233IndexAt $index ${tableMap.length}");
    final options = tableMap.values.toList();
    final tables = tableMap.keys.toList();
    if (options.isEmpty) return -1;
    if (index >= options.length) return 0;
    final hash = options[index].hash;
    for (var i = 0; i < tables.length; i++) {
      if (tables[i] == hash) return i + 1;
    }
    return -1;
  }
}
