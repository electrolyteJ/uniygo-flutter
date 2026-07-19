import 'dart:io' show Platform, File;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
// Desktop / FFI helper — only imported when needed.
// ignore_for_file: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dao/card_dao.dart';

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

  Database? _db;

  /// Public data-access object for card queries.  Valid after [initialize].
  CardDao? _dao;

  /// Public data-access object for card queries.  Valid after [initialize].
  CardDao get dao => _dao!;

  bool get isInitialized => _db != null;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  /// Copy the bundled cards.cdb from assets to a writable path, then open
  /// it as a read-only SQLite database.  Safe to call multiple times;
  /// subsequent calls are a no-op.
  Future<void> initialize() async {
    if (_db != null) return;

    // On desktop platforms sqflite needs the ffi backend.
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _copyAssetToWritable('assets/data/cards.cdb');

    _db = await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: true,
    );

    _dao = CardDao(_db!);
  }

  /// Release the database handle.  Call when shutting down.
  Future<void> dispose() async {
    await _db?.close();
    _dao = null;
    _db = null;
  }

  /// Copy a bundled Flutter asset to a real file so sqflite can open it.
  /// Returns the destination path.
  Future<String> _copyAssetToWritable(String assetKey) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destPath = p.join(appDir.path, 'cards.cdb');

    // Only copy if not already present (or stale).
    final destFile = File(destPath);
    final assetData = await rootBundle.load(assetKey);

    // Always overwrite during development so the bundled cdb matches.
    if (await destFile.exists()) {
      await destFile.delete();
    }
    await destFile.writeAsBytes(assetData.buffer.asUint8List());

    return destPath;
  }
}
