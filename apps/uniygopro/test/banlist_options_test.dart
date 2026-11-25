import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/create_room/free/free_room_launch.dart';
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
    expect(roomOptionsOf(const RoomRuleConfig()).lfTableHash, 0x11223344);
    expect(
      roomOptionsOf(const RoomRuleConfig(banlist: 1)).lfTableHash,
      0x55667788,
    );
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
    expect(options[0].token, 'LF1');
    expect(options[0].lfTableHash, tableA.hash);
    expect(options[1].token, 'LF2');
    expect(options[1].lfTableHash, tableB.hash);
    expect(options[2].token, 'NF');

    final oldTables = BanlistCatalog.tables;
    addTearDown(() => BanlistCatalog.tables = oldTables);
    BanlistCatalog.tables = [tableA, tableB];
    expect(BanlistCatalog.mercury233TokenForHash(tableA.hash), 'LF1');
    expect(BanlistCatalog.mercury233TokenForHash(tableB.hash), 'LF2');
    expect(BanlistCatalog.mercury233TokenForHash(0), '');
  });
}
