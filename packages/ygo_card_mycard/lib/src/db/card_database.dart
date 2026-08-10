import 'dart:developer' as console;

import 'package:sqflite/sqflite.dart' hide openDatabase;
import '../card_dao.dart';
export 'platform.web.dart' if (dart.library.io) 'platform.native.dart';
/// Singleton service that owns the bundled cards.cdb lifecycle — copies the
/// asset to a writable path, opens the SQLite database, and exposes a [dao]
/// for all card queries.
///
/// Usage:
/// ```dart
/// final db = CardDatabase.instance;
/// await db.initialize();
/// final blueEyes = await db.dao.getCard(89631139);
/// final results = await db.dao.searchByName('Blue-Eyes');
/// ```
class CardDatabase {
  CardDatabase._();

  static final CardDatabase instance = CardDatabase._();

  Database? rawdb;

  /// Public data-access object for card queries.  Valid after [initialize].
  CardDao? dao;

  /// Public data-access object for card queries.  Valid after [initialize].

  bool get isInitialized => rawdb != null;

  get isOpen => rawdb?.isOpen == true;

  /// Release the database handle.  Call when shutting down.
  Future<void> dispose() async {
    await rawdb?.close();
    rawdb = null;
  }
}
