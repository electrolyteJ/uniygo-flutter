import 'dart:io' show Directory, Platform;

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/db/dao/card_dao.dart';
import 'package:uniygopro/db/models/card_info.dart';
import 'package:ocgcore/ocgcore.dart';

/// Direct-SQLite test reading `assets/data/cards.cdb` from the filesystem.
/// Uses [CardDao] for all queries — the same data-access layer used by the
/// app at runtime, just wired to a test-owned database handle.
///
/// NOTE: this cdb uses **Chinese** (zh-CN) card names.
void main() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  late CardDao dao;

  setUpAll(() async {
    final cdbPath = '${Directory.current.path}/assets/data/cards.cdb';
    final db = await openDatabase(cdbPath, readOnly: true, singleInstance: true);
    dao = CardDao(db);
  });

  // ---------------------------------------------------------------------------
  // 1. Database metadata
  // ---------------------------------------------------------------------------
  group('Database metadata', () {
    test('should have datas and texts tables', () async {
      final names = await dao.tableNames();
      expect(names.contains('datas'), isTrue);
      expect(names.contains('texts'), isTrue);
    });

    test('should have 10k+ cards', () async {
      expect(await dao.count(), greaterThan(10000));
    });

    test('min/max card IDs should be reasonable', () async {
      final (min, max) = await dao.minMaxIds();
      expect(min, greaterThan(0));
      expect(max, greaterThan(1000000));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Core card lookups (中文卡名)
  // ---------------------------------------------------------------------------
  group('Core card lookups', () {
    test('青眼白龙 (89631139)', () async {
      final card = await dao.getCard(89631139);
      expect(card, isNotNull);
      expect(card!.code, equals(89631139));
      expect(card.name, equals('青眼白龙'));
      expect(card.isMonster, isTrue);
      expect(card.isNormal, isTrue);
      expect(card.isEffect, isFalse);
      expect(card.atk, equals(3000));
      expect(card.def, equals(2500));
      expect(card.level, equals(8));
      expect(card.kindLabel, equals('Normal'));
    });

    test('黑魔术师 (46986414)', () async {
      final card = await dao.getCard(46986414);
      expect(card, isNotNull);
      expect(card!.name, equals('黑魔术师'));
      expect(card.isMonster, isTrue);
      expect(card.isNormal, isTrue);
      expect(card.atk, equals(2500));
      expect(card.def, equals(2100));
      expect(card.level, equals(7));
    });

    test('should return null for non-existent codes', () async {
      expect(await dao.getCard(0), isNull);
      expect(await dao.getCard(99999999), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Search
  // ---------------------------------------------------------------------------
  group('Search', () {
    test('should find by Chinese name', () async {
      final results = await dao.searchByName('青眼');
      expect(results, isNotEmpty);
      expect(results.any((c) => c.name == '青眼白龙'), isTrue);
    });

    test('should find by Chinese name (黑魔术)', () async {
      final results = await dao.searchByName('黑魔术师');
      expect(results.any((c) => c.name == '黑魔术师'), isTrue);
    });

    test('should respect maxResults', () async {
      expect((await dao.searchByName('龙', maxResults: 5)).length, lessThanOrEqualTo(5));
    });

    test('no match → empty list', () async {
      expect(await dao.searchByName('ZZZ_NONEXISTENT_999'), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Type filtering
  // ---------------------------------------------------------------------------
  group('Type filtering', () {
    test('LINK', () async {
      for (final c in await dao.getCardsByType(TYPE_LINK)) {
        expect(c.isLink, isTrue, reason: c.toString());
      }
    });

    test('XYZ', () async {
      for (final c in await dao.getCardsByType(TYPE_XYZ)) {
        expect(c.isXyz, isTrue, reason: c.toString());
      }
    });

    test('PENDULUM', () async {
      for (final c in await dao.getCardsByType(TYPE_PENDULUM)) {
        expect(c.isPendulum, isTrue, reason: c.toString());
      }
    });

    test('Tuner', () async {
      for (final c in await dao.getCardsByType(TYPE_TUNER)) {
        expect(c.isTuner, isTrue, reason: c.toString());
      }
    });

    test('Fusion', () async {
      for (final c in await dao.getCardsByType(TYPE_FUSION, maxResults: 10)) {
        expect(c.isFusion, isTrue, reason: c.toString());
      }
    });

    test('Synchro', () async {
      for (final c in await dao.getCardsByType(TYPE_SYNCHRO, maxResults: 10)) {
        expect(c.isSynchro, isTrue, reason: c.toString());
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Range queries
  // ---------------------------------------------------------------------------
  group('Range queries', () {
    test('should return cards in range starting from min ID (483)', () async {
      final cards = await dao.getCardsInRange(483, 500);
      expect(cards, isNotEmpty);
      for (final c in cards) {
        expect(c.code, inInclusiveRange(483, 500));
      }
    });

    test('empty range → empty', () async {
      expect(await dao.getCardsInRange(0, 0), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Aliases
  // ---------------------------------------------------------------------------
  group('Aliases', () {
    test('should return alt-arts for 青眼白龙 (89631139)', () async {
      final cards = await dao.getAliases(89631139);
      for (final c in cards) {
        expect(c.alias, equals(89631139));
        expect(c.code, isNot(equals(89631139)));
        expect(c.name, equals('青眼白龙'));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 7. CardInfo model
  // ---------------------------------------------------------------------------
  group('CardInfo model', () {
    test('kindLabel for diverse types', () async {
      final fiveHeaded = await dao.getCard(99267150);   // 五神龙
      if (fiveHeaded != null) {
        expect(fiveHeaded.isFusion, isTrue);
        expect(fiveHeaded.kindLabel, equals('Fusion'));
      }
      final stardust = await dao.getCard(44508094);     // 星尘龙
      if (stardust != null) {
        expect(stardust.isSynchro, isTrue);
        expect(stardust.kindLabel, equals('Synchro'));
      }
      final utopia = await dao.getCard(84013237);       // No.39 希望皇 霍普
      if (utopia != null) {
        expect(utopia.isXyz, isTrue);
        expect(utopia.kindLabel, equals('Xyz'));
      }
      final decodeTalker = await dao.getCard(1861629);  // 解码语者
      if (decodeTalker != null) {
        expect(decodeTalker.isLink, isTrue);
        expect(decodeTalker.kindLabel, equals('Link'));
      }
    });

    test('setcodeAt unpacks setcodes', () async {
      final card = await dao.getCard(89631139);
      expect(card, isNotNull);
      expect(
        List.generate(16, (i) => card!.setcodeAt(i)).any((sc) => sc != 0),
        isTrue,
        reason: '青眼白龙 should have at least one non-zero setcode',
      );
    });

    test('== / hashCode by code only', () {
      final a = CardInfo(
        code: 89631139, alias: 0, setcode: 0, type: 0,
        atk: 0, def: 0, level: 0, race: 1, attribute: 1,
        ot: 0, category: 0, name: 'A', desc: '', strings: List.filled(16, null),
      );
      final b = CardInfo(
        code: 89631139, alias: 1, setcode: 1, type: 1,
        atk: 100, def: 100, level: 1, race: 2, attribute: 2,
        ot: 1, category: 1, name: 'B', desc: 'X', strings: List.filled(16, null),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes code, name, kindLabel', () {
      final card = CardInfo(
        code: 89631139, alias: 0, setcode: 0,
        type: TYPE_MONSTER | TYPE_NORMAL, atk: 3000, def: 2500,
        level: 8, race: 1, attribute: 1,
        ot: 0, category: 0, name: '青眼白龙', desc: '',
        strings: List.filled(16, null),
      );
      final s = card.toString();
      expect(s, contains('89631139'));
      expect(s, contains('青眼白龙'));
      expect(s, contains('Normal'));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Data integrity
  // ---------------------------------------------------------------------------
  group('Data integrity', () {
    test('no card has negative level', () async {
      expect(await dao.countNegativeLevel(), equals(0));
    });

    test('every datas row has a matching texts row', () async {
      expect(await dao.allDatasHaveTexts(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. CRUD — in-memory database so writes don't touch the production CDB
  // ---------------------------------------------------------------------------
  group('CRUD operations', () {
    late CardDao crud;

    final sampleCard = CardInfo(
      code: 12345678,
      alias: 0,
      setcode: 0x1,
      type: TYPE_MONSTER | TYPE_NORMAL,
      atk: 3000,
      def: 2500,
      level: 8,
      race: 1,
      attribute: 1,
      ot: 0,
      category: 0,
      name: '测试卡',
      desc: '这是测试描述',
      strings: List.filled(16, null),
    );

    late Database _crudDb;

    setUp(() async {
      _crudDb = await openDatabase(
        inMemoryDatabasePath,
        readOnly: false,
        singleInstance: true,
      );
      // Use IF NOT EXISTS — in-memory DBs are shared within the same path.
      await _crudDb.execute('''
        CREATE TABLE IF NOT EXISTS datas (
          id INTEGER PRIMARY KEY,
          ot INTEGER,
          alias INTEGER,
          setcode INTEGER,
          type INTEGER,
          atk INTEGER,
          def INTEGER,
          level INTEGER,
          race INTEGER,
          attribute INTEGER,
          category INTEGER
        )
      ''');
      await _crudDb.execute('''
        CREATE TABLE IF NOT EXISTS texts (
          id INTEGER PRIMARY KEY,
          name TEXT,
          desc TEXT,
          str1 TEXT, str2 TEXT, str3 TEXT, str4 TEXT,
          str5 TEXT, str6 TEXT, str7 TEXT, str8 TEXT,
          str9 TEXT, str10 TEXT, str11 TEXT, str12 TEXT,
          str13 TEXT, str14 TEXT, str15 TEXT, str16 TEXT
        )
      ''');
      // Clean slate for each test.
      await _crudDb.delete('datas');
      await _crudDb.delete('texts');
      crud = CardDao(_crudDb);
    });

    // ---------- Create ----------

    test('insertCard → getCard round-trip', () async {
      await crud.insertCard(sampleCard);
      final fetched = await crud.getCard(12345678);
      expect(fetched, isNotNull);
      expect(fetched!.code, equals(12345678));
      expect(fetched.name, equals('测试卡'));
      expect(fetched.atk, equals(3000));
    });

    test('insertCards batch', () async {
      final cards = List.generate(5, (i) => CardInfo(
        code: 1000 + i,
        alias: 0, setcode: 0, type: TYPE_MONSTER | TYPE_NORMAL,
        atk: i * 500, def: i * 400, level: i + 1,
        race: 1, attribute: 1, ot: 0, category: 0,
        name: '批量卡 $i', desc: '', strings: List.filled(16, null),
      ));
      await crud.insertCards(cards);
      expect(await crud.count(), equals(5));
      final c = await crud.getCard(1002);
      expect(c!.name, equals('批量卡 2'));
    });

    test('insertCard duplicate code throws', () async {
      await crud.insertCard(sampleCard);
      expect(
        () => crud.insertCard(sampleCard),
        throwsA(isA<DatabaseException>()),
      );
    });

    // ---------- Upsert ----------

    test('upsertCard inserts new card', () async {
      await crud.upsertCard(sampleCard);
      final c = await crud.getCard(12345678);
      expect(c!.name, equals('测试卡'));
    });

    test('upsertCard overwrites existing card', () async {
      await crud.insertCard(sampleCard);
      final updated = CardInfo(
        code: 12345678,
        alias: 0, setcode: 0, type: TYPE_MONSTER | TYPE_EFFECT,
        atk: 4000, def: 3500, level: 10,
        race: 2, attribute: 2, ot: 1, category: 0,
        name: '修改卡', desc: '已修改', strings: List.filled(16, null),
      );
      await crud.upsertCard(updated);
      final c = await crud.getCard(12345678);
      expect(c!.name, equals('修改卡'));
      expect(c.atk, equals(4000));
      expect(c.isEffect, isTrue);
    });

    test('upsertCards batch', () async {
      final cards = List.generate(3, (i) => CardInfo(
        code: 2000 + i,
        alias: 0, setcode: 0, type: TYPE_MONSTER | TYPE_NORMAL,
        atk: 1000, def: 1000, level: 4,
        race: 1, attribute: 1, ot: 0, category: 0,
        name: 'upsert $i', desc: '', strings: List.filled(16, null),
      ));
      await crud.upsertCards(cards);
      expect(await crud.count(), equals(3));
    });

    // ---------- Update ----------

    test('updateCard changes existing fields', () async {
      await crud.insertCard(sampleCard);
      final modified = CardInfo(
        code: 12345678,
        alias: 999, setcode: 0xFF, type: TYPE_MONSTER | TYPE_EFFECT | TYPE_TUNER,
        atk: 1800, def: 1200, level: 4,
        race: 8, attribute: 4, ot: 2, category: 1,
        name: '修改过的卡', desc: '新描述', strings: List.filled(16, null),
      );
      final rows = await crud.updateCard(12345678, modified);
      expect(rows, equals(2)); // one datas + one texts

      final c = await crud.getCard(12345678);
      expect(c!.name, equals('修改过的卡'));
      expect(c.alias, equals(999));
      expect(c.isTuner, isTrue);
      expect(c.race, equals(8));
    });

    test('updateCard non-existent returns 0', () async {
      final rows = await crud.updateCard(99999999, sampleCard);
      expect(rows, equals(0));
    });

    test('updateCard only changes texts (name/desc)', () async {
      await crud.insertCard(sampleCard);
      final onlyTextChanged = CardInfo(
        code: 12345678,
        alias: 0, setcode: 0x1, type: TYPE_MONSTER | TYPE_NORMAL,
        atk: 3000, def: 2500, level: 8,
        race: 1, attribute: 1, ot: 0, category: 0,
        name: '改个名', desc: '新的描述而已', strings: List.filled(16, null),
      );
      await crud.updateCard(12345678, onlyTextChanged);
      final c = await crud.getCard(12345678);
      expect(c!.name, equals('改个名'));
      expect(c.desc, equals('新的描述而已'));
      expect(c.atk, equals(3000)); // unchanged
    });

    // ---------- Delete ----------

    test('deleteCard removes a single card', () async {
      await crud.insertCard(sampleCard);
      expect(await crud.count(), equals(1));

      final deleted = await crud.deleteCard(12345678);
      expect(deleted, equals(2)); // one datas + one texts
      expect(await crud.count(), equals(0));
      expect(await crud.getCard(12345678), isNull);
    });

    test('deleteCard non-existent returns 0', () async {
      expect(await crud.deleteCard(99999999), equals(0));
    });

    test('deleteAll clears everything', () async {
      await crud.insertCards(List.generate(10, (i) => CardInfo(
        code: 3000 + i,
        alias: 0, setcode: 0, type: TYPE_MONSTER | TYPE_NORMAL,
        atk: 1000, def: 1000, level: 4,
        race: 1, attribute: 1, ot: 0, category: 0,
        name: 'delete $i', desc: '', strings: List.filled(16, null),
      )));
      expect(await crud.count(), equals(10));
      expect(await crud.deleteAll(), equals(20)); // 10 datas + 10 texts
      expect(await crud.count(), equals(0));
    });

    test('delete then insert same code works', () async {
      await crud.insertCard(sampleCard);
      await crud.deleteCard(12345678);

      final newCard = CardInfo(
        code: 12345678,
        alias: 1, setcode: 0, type: TYPE_SPELL,
        atk: 0, def: 0, level: 0,
        race: 0, attribute: 0, ot: 0, category: 0,
        name: '新卡', desc: '', strings: List.filled(16, null),
      );
      await crud.insertCard(newCard);
      final c = await crud.getCard(12345678);
      expect(c!.name, equals('新卡'));
      expect(c.isSpell, isTrue);
    });

    // ---------- strings round-trip ----------

    test('strings field round-trips correctly', () async {
      final strings = List<String?>.generate(16, (i) => 'strval_$i');
      final card = CardInfo(
        code: 55555555,
        alias: 0, setcode: 0, type: TYPE_MONSTER | TYPE_PENDULUM,
        atk: 1500, def: 1500, level: 4,
        race: 1, attribute: 1, ot: 0, category: 0,
        name: '灵摆测试', desc: 'Pendulum strings test',
        strings: strings,
      );
      await crud.insertCard(card);
      final fetched = await crud.getCard(55555555);
      expect(fetched!.strings, equals(strings));
    });
  });
}
