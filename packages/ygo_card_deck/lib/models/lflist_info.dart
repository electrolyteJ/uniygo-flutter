/// 禁限卡表条目
class LflistEntry {
  /// 卡牌编号
  final int code;

  /// 限制数量（0=禁止, 1=限制, 2=准限制, 3=无限制）
  final int limit;

  const LflistEntry({required this.code, required this.limit});

  bool get isForbidden => limit == 0;
  bool get isLimited => limit == 1;
  bool get isSemiLimited => limit == 2;

  /// 从 lflist.conf 行解析
  /// 格式: "code limit" 或 "code limit # comment"
  factory LflistEntry.fromLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw FormatException('Invalid lflist line: $line');
    }
    return LflistEntry(
      code: int.parse(parts[0]),
      limit: int.parse(parts[1]),
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'limit': limit};

  factory LflistEntry.fromJson(Map<String, dynamic> json) => LflistEntry(
        code: (json['code'] ?? 0) as int,
        limit: (json['limit'] ?? 3) as int,
      );

  @override
  String toString() => 'LflistEntry($code, limit=$limit)';
}

/// 禁限卡表
class LflistInfo {
  /// 卡表名称
  final String name;

  /// 生效日期
  final String date;

  /// 条目列表
  final List<LflistEntry> entries;

  const LflistInfo({
    this.name = '',
    this.date = '',
    this.entries = const [],
  });

  /// 从 lflist.conf 字符串解析
  factory LflistInfo.parse(String content) {
    final lines = content.split('\n');
    String name = '';
    String date = '';
    final entries = <LflistEntry>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#name')) {
        name = trimmed.replaceFirst('#name ', '').trim();
      } else if (trimmed.startsWith('#date')) {
        date = trimmed.replaceFirst('#date ', '').trim();
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#') && !trimmed.startsWith('!')) {
        try {
          entries.add(LflistEntry.fromLine(trimmed));
        } catch (_) {
          // 跳过格式错误的行
        }
      }
    }

    return LflistInfo(name: name, date: date, entries: entries);
  }

  /// 查询某张卡的限禁状态
  int getLimit(int code) {
    for (final entry in entries) {
      if (entry.code == code) return entry.limit;
    }
    return 3; // 默认无限制
  }

  /// 查询某张卡的限制文本
  String getLimitText(int code) {
    return switch (getLimit(code)) {
      0 => '禁止',
      1 => '限制',
      2 => '准限制',
      _ => '无限制',
    };
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory LflistInfo.fromJson(Map<String, dynamic> json) => LflistInfo(
        name: (json['name'] ?? '') as String,
        date: (json['date'] ?? '') as String,
        entries: (json['entries'] as List<dynamic>?)
                ?.map((e) => LflistEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  String toString() => 'LflistInfo($name, ${entries.length} entries)';
}
