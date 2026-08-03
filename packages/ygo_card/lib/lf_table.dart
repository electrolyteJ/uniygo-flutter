/// 限制数量（0=禁止, 1=限制, 2=准限制, 3=无限制）
enum LfType {
  forbidden,
  limited,
  semiLimited,
  unlimited;

  static LfType of(int value) {
    switch (value) {
      case 0:
        return LfType.forbidden;
      case 1:
        return LfType.limited;
      case 2:
        return LfType.semiLimited;
      default:
        return LfType.unlimited;
    }
  }
}

/// 禁限卡表条目
class LfInfo {
  /// 卡牌编号
  final int code;

  final LfType limit;
  final String name;

  const LfInfo({required this.code, required this.limit, required this.name});

  @override
  String toString() => 'LfInfo($code, limit=$limit name=$name)';
}

/// 禁限卡表
class LfTable {
  /// 卡表名称
  final String name;

  /// 卡表hash值，与 ygopro 的 Banlist.Hash 算法一致
  int get hash {
    int h = 0x7dfcee6a;
    for (final info in lfInfos.values) {
      h =
          (h ^
              ((info.code << 18) | (info.code >> 14)) ^
              ((info.code << (27 + info.limit.index)) |
                  (info.code >> (5 - info.limit.index)))) &
          0xFFFFFFFF;
    }
    return h;
  }

  /// 生效日期
  final String date;

  /// 条目列表
  final Map<int, LfInfo> lfInfos;

  const LfTable({this.name = '', this.date = '', this.lfInfos = const {}});

  /// 查询某张卡的限禁状态
  LfType getLimit(int code) {
    for (final entry in lfInfos.values) {
      if (entry.code == code) return entry.limit;
    }
    return LfType.unlimited; // 默认无限制
  }

  /// 查询某张卡的限制文本
  String getLimitText(int code) {
    return switch (getLimit(code)) {
      LfType.forbidden => '禁止',
      LfType.limited => '限制',
      LfType.semiLimited => '准限制',
      LfType.unlimited => '无限制',
    };
  }

  @override
  String toString() => 'LfTable($name, ${lfInfos.length} $lfInfos)';
}
