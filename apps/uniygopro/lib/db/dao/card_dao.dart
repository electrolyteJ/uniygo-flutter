import 'package:sqflite/sqflite.dart';

import '../models/card_info.dart';

/// Pure data-access layer for card queries against a cards.cdb SQLite database.
///
/// Accepts an already-open [Database] in the constructor — it does **not** own
/// the database lifecycle.  This makes it trivial to test with any in-memory or
/// file-backed database without going through [CardDatabase]'s asset-copy flow.
class CardDao {
  final Database _db;

  const CardDao(this._db);

  // ---------------------------------------------------------------------------
  // Shared SQL fragment — avoids duplicating the column list everywhere.
  // ---------------------------------------------------------------------------

  static const String _cardColumns = '''
    d.*, t.name, t.desc,
    t.str1, t.str2, t.str3, t.str4, t.str5, t.str6, t.str7, t.str8,
    t.str9, t.str10, t.str11, t.str12, t.str13, t.str14, t.str15, t.str16
  ''';

  String _cardSql(String where) =>
      'SELECT $_cardColumns FROM datas d JOIN texts t ON d.id = t.id $where';

  // ---------------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------------

  CardInfo _rowToCard(Map<String, Object?> row) {
    return CardInfo(
      code: row['id'] as int,
      alias: row['alias'] as int,
      setcode: row['setcode'] as int,
      type: row['type'] as int,
      atk: row['atk'] as int,
      def: row['def'] as int,
      level: row['level'] as int,
      race: row['race'] as int,
      attribute: row['attribute'] as int,
      ot: row['ot'] as int,
      category: (row['category'] as int?) ?? 0,
      name: (row['name'] as String?) ?? '',
      desc: (row['desc'] as String?) ?? '',
      strings: List.generate(16, (i) => row['str${i + 1}'] as String?),
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Get a single card by its 8-digit [code] (passcode).
  /// Returns null when no card with that code exists.
  Future<CardInfo?> getCard(int code) async {
    final rows = await _db.rawQuery(
      _cardSql('WHERE d.id = ?'),
      [code],
    );
    return rows.isEmpty ? null : _rowToCard(rows.first);
  }

  /// Search cards whose name contains [query] (case-insensitive substring
  /// match).  Sorted by id.  Limit with [maxResults] (default 50).
  Future<List<CardInfo>> searchByName(String query, {int maxResults = 50}) async {
    final rows = await _db.rawQuery(
      _cardSql('WHERE t.name LIKE ? ORDER BY d.id LIMIT ?'),
      ['%$query%', maxResults],
    );
    return rows.map(_rowToCard).toList();
  }

  /// Get all cards of a given [type] (bitmask).
  Future<List<CardInfo>> getCardsByType(int type, {int maxResults = 100}) async {
    final rows = await _db.rawQuery(
      _cardSql('WHERE (d.type & ?) != 0 ORDER BY d.id LIMIT ?'),
      [type, maxResults],
    );
    return rows.map(_rowToCard).toList();
  }

  /// Count total cards.
  Future<int> count() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS c FROM datas');
    return r.first['c'] as int;
  }

  /// Get cards within a code range (useful for pagination).
  Future<List<CardInfo>> getCardsInRange(int startId, int endId) async {
    final rows = await _db.rawQuery(
      _cardSql('WHERE d.id >= ? AND d.id <= ? ORDER BY d.id'),
      [startId, endId],
    );
    return rows.map(_rowToCard).toList();
  }

  /// Get all aliases for a given original [code].
  Future<List<CardInfo>> getAliases(int originalCode) async {
    final rows = await _db.rawQuery(
      _cardSql('WHERE d.alias = ? ORDER BY d.id'),
      [originalCode],
    );
    return rows.map(_rowToCard).toList();
  }

  // ---------------------------------------------------------------------------
  // Write operations (Create / Update / Delete)
  // ---------------------------------------------------------------------------

  /// Insert a single card into both [datas] and [texts] in a transaction.
  /// Throws if a card with the same [CardInfo.code] already exists.
  Future<void> insertCard(CardInfo card) async {
    await _db.transaction((txn) async {
      await txn.insert('datas', _cardToRow(card));
      await txn.insert('texts', _cardToTextsRow(card));
    });
  }

  /// Insert or replace a single card (upsert) in both tables.
  Future<void> upsertCard(CardInfo card) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'datas',
        _cardToRow(card),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'texts',
        _cardToTextsRow(card),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Batch-insert [cards] in a single transaction.  Uses INSERT (not replace)
  /// — call [upsertCards] if you need upsert semantics.
  Future<void> insertCards(List<CardInfo> cards) async {
    await _db.transaction((txn) async {
      for (final card in cards) {
        await txn.insert('datas', _cardToRow(card));
        await txn.insert('texts', _cardToTextsRow(card));
      }
    });
  }

  /// Batch upsert [cards] in a single transaction.
  Future<void> upsertCards(List<CardInfo> cards) async {
    await _db.transaction((txn) async {
      for (final card in cards) {
        await txn.insert(
          'datas',
          _cardToRow(card),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'texts',
          _cardToTextsRow(card),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Update an existing card by [code].  Returns the number of rows changed
  /// (0 if no matching card existed).
  Future<int> updateCard(int code, CardInfo card) async {
    return _db.transaction((txn) async {
      final d = await txn.update(
        'datas',
        _cardToRow(card),
        where: 'id = ?',
        whereArgs: [code],
      );
      final t = await txn.update(
        'texts',
        _cardToTextsRow(card),
        where: 'id = ?',
        whereArgs: [code],
      );
      return d + t;
    });
  }

  /// Delete a card (and its texts row) by [code].
  /// Returns the total number of rows deleted.
  Future<int> deleteCard(int code) async {
    return _db.transaction((txn) async {
      final d = await txn.delete('datas', where: 'id = ?', whereArgs: [code]);
      final t = await txn.delete('texts', where: 'id = ?', whereArgs: [code]);
      return d + t;
    });
  }

  /// Delete all rows from [datas] and [texts].
  Future<int> deleteAll() async {
    return _db.transaction((txn) async {
      final d = await txn.delete('datas');
      final t = await txn.delete('texts');
      return d + t;
    });
  }

  // ---------------------------------------------------------------------------
  // Row encoding (CardInfo → DB row maps)
  // ---------------------------------------------------------------------------

  Map<String, Object?> _cardToRow(CardInfo c) => {
        'id': c.code,
        'alias': c.alias,
        'setcode': c.setcode,
        'type': c.type,
        'atk': c.atk,
        'def': c.def,
        'level': c.level,
        'race': c.race,
        'attribute': c.attribute,
        'ot': c.ot,
        'category': c.category,
      };

  Map<String, Object?> _cardToTextsRow(CardInfo c) => {
        'id': c.code,
        'name': c.name,
        'desc': c.desc,
        for (int i = 0; i < 16; i++) 'str${i + 1}': i < c.strings.length ? c.strings[i] : null,
      };

  // ---------------------------------------------------------------------------
  // Metadata / integrity helpers (exposed for tests)
  // ---------------------------------------------------------------------------

  /// List table names present in the database.
  Future<Set<String>> tableNames() async {
    final rows = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toSet();
  }

  /// Return (minId, maxId) from the datas table.
  Future<(int, int)> minMaxIds() async {
    final r = await _db.rawQuery('SELECT MIN(id) AS mn, MAX(id) AS mx FROM datas');
    final row = r.first;
    return (row['mn'] as int, row['mx'] as int);
  }

  /// Count records where level < 0 (should be zero for valid data).
  Future<int> countNegativeLevel() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS c FROM datas WHERE level < 0');
    return r.first['c'] as int;
  }

  /// Whether every [datas] row has a matching [texts] row.
  Future<bool> allDatasHaveTexts() async {
    final r = await _db.rawQuery('''
      SELECT COUNT(*) AS c FROM datas d
      LEFT JOIN texts t ON d.id = t.id
      WHERE t.id IS NULL
    ''');
    return (r.first['c'] as int) == 0;
  }
}
