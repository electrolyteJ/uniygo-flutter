import 'package:ygo_data/card_info.dart';

/// Yugipedia 卡片的完整解析结果（[info] 为主数据，其余为多语言名）。
class YugipediaCard {
  final CardInfo info;
  final String nameEn;
  final String? nameSc;
  final String? nameTc;

  const YugipediaCard({
    required this.info,
    required this.nameEn,
    this.nameSc,
    this.nameTc,
  });
}

/// CardTable2 模板（Yugipedia 卡页 wikitext）解析器。
///
/// 字段协议（2026-08 实测）：`| key = value` 逐行，值可跨行延续到下一个
/// `| key` 或 `}}`；卡密在 `password`（含前导零需剥除）；中文卡名/文本在
/// `sc_name`/`sc_text`（繁中为 tc_*）；魔法陷阱用 `card_type`+`property`，
/// 怪兽用 `types`（首段为种族）+ `attribute`。
///
/// 位掩码数值与 packages/ocgcore/lib/ocgcore.dart 同源（本包保持
/// 纯数据客户端定位，不依赖引擎插件；常量更新时需同步）。
class CardTable2Parser {
  CardTable2Parser._();

  /// 解析卡页 wikitext；非卡页（无 CardTable2/无 password）返回 null。
  ///
  /// [pageTitle]：页面标题（即英文名，CardTable2 不含 en_name 字段）。
  /// [preferChinese]：true 时 name/desc 优先简体中文（sc_*），
  /// 无中文回退英文；false 时直接英文。
  static YugipediaCard? parse(
    String wikitext, {
    String? pageTitle,
    bool preferChinese = true,
  }) {
    if (!wikitext.contains('{{CardTable2')) return null;
    final fields = _extractFields(wikitext);

    final password = int.tryParse(fields['password']?.trim() ?? '');
    if (password == null) return null;

    final nameSc = _blankToNull(fields['sc_name']);
    final nameTc = _blankToNull(fields['tc_name']);
    final nameEn = pageTitle ?? '';

    final cardType = fields['card_type']?.trim();
    final isSpell = cardType == 'Spell';
    final isTrap = cardType == 'Trap';
    final isMonster = !isSpell && !isTrap;

    // types：'Cyberse / Link / Effect' → 首段种族，其余类型修饰
    final typeParts = (fields['types'] ?? '')
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final race = isMonster && typeParts.isNotEmpty
        ? _ocgRaceOf(typeParts.first)
        : 0;

    final isLink = typeParts.contains('Link');
    final scale = int.tryParse(fields['pendulum_scale']?.trim() ?? '') ?? 0;

    // 三种语言的卡面文本都可能含 wiki 标记（[[链接]]/模板/斜体），统一清洗
    final enText = _cleanWikiText(fields['text'] ?? '');
    final scText = _cleanOrNull(fields['sc_text']);
    final tcText = _cleanOrNull(fields['tc_text']);

    final name = preferChinese ? (nameSc ?? nameTc ?? nameEn) : nameEn;
    final desc = preferChinese ? (scText ?? tcText ?? enText) : enText;

    return YugipediaCard(
      info: CardInfo(
        code: password,
        alias: 0,
        setcode: const [],
        type: _resolveType(
          cardType: cardType,
          property: fields['property'],
          typeParts: typeParts,
        ),
        level: int.tryParse(fields['level']?.trim() ?? '') ?? 0,
        attribute: isMonster ? _ocgAttributeOf(fields['attribute']) : 0,
        race: race,
        attack: int.tryParse(fields['atk']?.trim() ?? '') ?? 0,
        defense: int.tryParse(fields['def']?.trim() ?? '') ?? 0,
        lscale: scale,
        rscale: scale,
        linkMarker: isLink ? _ocgLinkMarkersOf(fields['link_arrows'] ?? '') : 0,
        name: name,
        desc: desc,
      ),
      nameEn: nameEn,
      nameSc: nameSc,
      nameTc: nameTc,
    );
  }

  // ── 字段提取（支持跨行值）──

  static Map<String, String> _extractFields(String wikitext) {
    final fields = <String, String>{};
    final fieldStart = RegExp(r'^\s*\|\s*([A-Za-z_][\w]*)\s*=\s*(.*)$');
    String? currentKey;
    final buf = StringBuffer();

    void flush() {
      if (currentKey != null) {
        fields[currentKey] = buf.toString().trim();
      }
    }

    for (final rawLine in wikitext.split('\n')) {
      final line = rawLine;
      // 模板结束符独占一行（CardTable2 惯例）；字段值内嵌套模板的
      // "}}"（如 ja_name 的 {{Ruby|...}}）不触发结束。
      if (line.trim() == '}}') {
        flush();
        break;
      }
      final m = fieldStart.firstMatch(line);
      if (m != null) {
        flush();
        currentKey = m.group(1)!;
        buf
          ..clear()
          ..write(m.group(2));
      } else if (currentKey != null) {
        buf.write('\n$line');
      }
    }
    flush();
    return fields;
  }

  // ── wiki 文本清洗 ──

  static final _linkWithText = RegExp(r'\[\[[^\]|]*\|([^\]]*)\]\]');
  static final _linkPlain = RegExp(r'\[\[([^\]]*)\]\]');
  static final _template = RegExp(r'\{\{[^{}]*\}\}');

  static String _cleanWikiText(String text) {
    var out = text;
    // [[目标|显示]] → 显示；[[目标]] → 目标
    out = out.replaceAllMapped(_linkWithText, (m) => m.group(1)!);
    out = out.replaceAllMapped(_linkPlain, (m) => m.group(1)!);
    // 简单模板剥除（{{Ruby|a|b}} 等多层嵌套由循环处理）
    while (_template.hasMatch(out)) {
      out = out.replaceAllMapped(_template, (m) {
        final inner = m.group(0)!;
        final body = inner.substring(2, inner.length - 2);
        final parts = body.split('|');
        // Ruby 类模板取正文段（第二段，若无则第一段）
        return parts.length > 1 ? parts[1] : parts.first;
      });
    }
    // 斜体/粗体标记
    out = out.replaceAll("'''", '').replaceAll("''", '');
    return out.trim();
  }

  // ── 类型/属性/种族/Link 标记映射（与 ocgcore.dart 同源）──

  static int _resolveType({
    String? cardType,
    String? property,
    List<String> typeParts = const [],
  }) {
    if (cardType == 'Spell') return 0x2 | _propertyBit(property);
    if (cardType == 'Trap') return 0x4 | _propertyBit(property);
    var bits = 0x1; // TYPE_MONSTER
    for (final part in typeParts) {
      bits |= _typeKeywordBit(part);
    }
    return bits;
  }

  static int _propertyBit(String? property) => switch (property) {
    'Quick-Play' => 0x10000,
    'Continuous' => 0x20000,
    'Equip' => 0x40000,
    'Field' => 0x80000,
    'Counter' => 0x100000,
    'Ritual' => 0x80,
    _ => 0,
  };

  static int _typeKeywordBit(String part) => switch (part) {
    'Normal' => 0x10,
    'Effect' => 0x20,
    'Fusion' => 0x40,
    'Ritual' => 0x80,
    'Spirit' => 0x200,
    'Union' => 0x400,
    'Gemini' => 0x800,
    'Tuner' => 0x1000,
    'Synchro' => 0x2000,
    'Token' => 0x4000,
    'Flip' => 0x200000,
    'Toon' => 0x400000,
    'Xyz' || 'XYZ' => 0x800000,
    'Pendulum' => 0x1000000,
    'Link' => 0x4000000,
    _ => 0,
  };

  static int _ocgAttributeOf(String? value) => switch (value?.trim()) {
    'EARTH' => 0x01,
    'WATER' => 0x02,
    'FIRE' => 0x04,
    'WIND' => 0x08,
    'LIGHT' => 0x10,
    'DARK' => 0x20,
    'DIVINE' => 0x40,
    _ => 0,
  };

  static int _ocgRaceOf(String? value) => switch (value?.trim()) {
    'Warrior' => 0x1,
    'Spellcaster' => 0x2,
    'Fairy' => 0x4,
    'Fiend' => 0x8,
    'Zombie' => 0x10,
    'Machine' => 0x20,
    'Aqua' => 0x40,
    'Pyro' => 0x80,
    'Rock' => 0x100,
    'Winged Beast' => 0x200,
    'Plant' => 0x400,
    'Insect' => 0x800,
    'Thunder' => 0x1000,
    'Dragon' => 0x2000,
    'Beast' => 0x4000,
    'Beast-Warrior' => 0x8000,
    'Dinosaur' => 0x10000,
    'Fish' => 0x20000,
    'Sea Serpent' => 0x40000,
    'Reptile' => 0x80000,
    'Psychic' => 0x100000,
    'Divine-Beast' => 0x200000,
    'Creator God' => 0x400000,
    'Wyrm' => 0x800000,
    'Cyberse' => 0x1000000,
    'Illusion' => 0x2000000,
    _ => 0,
  };

  static const _linkArrowBits = <String, int>{
    'Bottom-Left': 0x001,
    'Bottom': 0x002,
    'Bottom-Right': 0x004,
    'Left': 0x008,
    'Right': 0x020,
    'Top-Left': 0x040,
    'Top': 0x080,
    'Top-Right': 0x100,
  };

  static int _ocgLinkMarkersOf(String linkArrows) {
    var bits = 0;
    for (final raw in linkArrows.split(',')) {
      final key = raw.trim();
      bits |= _linkArrowBits[key] ?? 0;
    }
    return bits;
  }

  static String? _blankToNull(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 空白归 null，非空则清洗 wiki 标记。
  static String? _cleanOrNull(String? value) {
    final v = _blankToNull(value);
    return v == null ? null : _cleanWikiText(v);
  }
}
