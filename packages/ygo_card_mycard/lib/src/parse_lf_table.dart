import 'dart:developer' as console;

import 'package:ygo_card/lf_table.dart';

/// 禁限卡表缓存，按 hash 索引: hash → LfTable
Map<int, LfTable> lflistHashToTable = {};

/// 通过 hash 获取卡表名称。
String getLflistName(int hash) {
  if (hash == 0) return 'N/A';
  return lflistHashToTable[hash]?.name ?? '未知';
}

/// 通过 hash 获取完整的卡表对象。
LfTable? getLflist(int hash) => lflistHashToTable[hash];

/// 解析 lflist.conf 全文，填充 [lflistHashToTable]。
///
/// 文件格式：以 `!卡表名称` 开头的节，每节内含 `code limit` 条目行。
/// hash 值由 [LfTable.hash] 按 ygopro Banlist.Hash 算法自动计算。
void parseLflistConf(String content) {
  lflistHashToTable = {};

  final lines = content.split('\n');
  String? currentName;
  final List<LfInfo> currentInfos = [];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    if (trimmed.startsWith('!')) {
      // 保存上一节
      if (currentName != null && currentInfos.isNotEmpty) {
        _commitSection(currentName, currentInfos);
      }
      // 开始新节
      currentName = trimmed.substring(1).trim();
      currentInfos.clear();
      continue;
    }

    // 解析条目行: "code limit [--comment]"
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final code = int.tryParse(parts[0]);
    final limit = int.tryParse(parts[1]);
    final name = parts[2];
    if (code == null || limit == null) continue;
    currentInfos.add(LfInfo(code: code, limit: LfType.of(limit), name: name));
  }

  // 保存最后一个节
  if (currentName != null && currentInfos.isNotEmpty) {
    _commitSection(currentName, currentInfos);
  }

  console.log(
    '禁限卡表已加载: ${lflistHashToTable.length} 个卡表',
    name: 'DuelRoomStore',
  );
}

void _commitSection(String name, List<LfInfo> infos) {
  final table = LfTable(name: name, lfInfos: {for (var info in infos) info.code: info});
  lflistHashToTable[table.hash] = table;
}
