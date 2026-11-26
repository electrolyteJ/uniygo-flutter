import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/create_room/models/banlist_options.dart';
import 'package:resource_data/lf_table.dart';
import 'package:uniygopro/create_room/widgets/room_rule_panel.dart';

void main() {
  test('禁限卡表默认取最新，序号映射到对应 hash', () {
    final old = BanlistCatalog.options;
    addTearDown(() => BanlistCatalog.options = old);
    // 目录已按新→旧排好；0 即最新卡表，不再有「默认」项。
    BanlistCatalog.options = const [
      BanlistOption('2026.1', 0x11223344),
      BanlistOption('2025.10', 0x55667788),
    ];

    expect(BanlistCatalog.hashAt(0), 0x11223344);
    expect(BanlistCatalog.hashAt(1), 0x55667788);
  });

  test('233 卡表选项：LF 序号与 hash 一一对应', () {
    final tableA = LfTable(
      name: '2026.1',
      lfInfos: const {1: LfInfo(code: 1, limit: LfType.forbidden, name: '')},
    );
    final tableB = LfTable(
      name: '2025.10',
      lfInfos: const {2: LfInfo(code: 2, limit: LfType.limited, name: '')},
    );

    final options = buildMercury233BanlistOptions([tableA, tableB]);
    expect(options.length, 3);
    expect(options[0].lfTableIndex, 1);
    expect(options[0].lfTableHash, tableA.hash);
    expect(options[1].lfTableIndex, 2);
    expect(options[1].lfTableHash, tableB.hash);
    expect(options[2].lfTableIndex, 0); // 无禁限

    // 下拉索引 → 服务端卡表序号（1 起）：按 tables 顺序反查。
    final oldTables = BanlistCatalog.tables;
    final oldOptions = BanlistCatalog.options;
    addTearDown(() {
      BanlistCatalog.tables = oldTables;
      BanlistCatalog.options = oldOptions;
    });
    BanlistCatalog.tables = [tableA, tableB];
    BanlistCatalog.options = [
      BanlistOption('2025.10', tableB.hash), // 下拉按日期倒序
      BanlistOption('2026.1', tableA.hash),
    ];
    expect(BanlistCatalog.mercury233IndexAt(0), 2); // tableB → LF2
    expect(BanlistCatalog.mercury233IndexAt(1), 1); // tableA → LF1
    expect(BanlistCatalog.mercury233IndexAt(2), 0); // 无禁限 → NF
  });

  test('233 禁限下拉支持「无禁限」NF', () {
    final oldOptions = BanlistCatalog.options;
    final oldTables = BanlistCatalog.tables;
    addTearDown(() {
      BanlistCatalog.options = oldOptions;
      BanlistCatalog.tables = oldTables;
    });

    final tableA = LfTable(name: '2026.1', lfInfos: const {});
    BanlistCatalog.tables = [tableA];
    BanlistCatalog.options = [BanlistOption('2026.1', tableA.hash)];

    // 下拉标签：卡表 + 「无禁限」，NF 占最后一个索引。
    expect(BanlistCatalog.mercury233Labels, ['2026.1', '无禁限']);
    // 「无禁限」索引经 hashAt 归 0（noBanlistHash）。
    expect(BanlistCatalog.hashAt(0), tableA.hash);
    expect(BanlistCatalog.hashAt(1), BanlistCatalog.noBanlistHash);

    // 索引 → 序号：0 → LF1，末尾 → 0（NF）。
    expect(BanlistCatalog.mercury233IndexAt(0), 1);
    expect(BanlistCatalog.mercury233IndexAt(1), 0);


    // 卡表未加载：序号 -1（不写 token），hash 0。
    BanlistCatalog.options = const [];
    expect(BanlistCatalog.mercury233IndexAt(0), -1);
  });
}
