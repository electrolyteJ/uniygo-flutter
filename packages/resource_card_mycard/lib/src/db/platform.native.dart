import 'package:applog/console.dart' as console;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../ygo_card_mycard.dart';
import '../card_dao.dart';
import 'card_database.dart';
import '../httper.dart';

Future<File> _dbPath() async {
  console.log('Getting database path...');
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/cards.cdb';
  return File(path);
}

Future<File> _test_dbPath() async {
  final path =
      '${(await getApplicationDocumentsDirectory()).path}/test_cards.cdb';
  return File(path);
}

Future<void> preDownloadDatabase() async {
  final productionFile = await _dbPath();
  console.log('Checking database file at ${productionFile.path}');
  if (!await productionFile.exists() || await productionFile.length() == 0) {
    final response = await fetch(EnvConfig.production.cardDatabaseUrl);
    final bodyBytes = response.bodyBytes;
    console.log('Database file not found, downloading...');
    if (bodyBytes.isNotEmpty) {
      console.log('Database downloaded, saving to ${productionFile.path}');
      await productionFile.writeAsBytes(bodyBytes);
    } else {
      throw Exception('HTTP error');
    }
  }
  await initDatabase(productionFile.path);
  final stagingFile = await _test_dbPath();
  console.log('Checking test database file at ${stagingFile.path}');
  if (!await stagingFile.exists() || await stagingFile.length() == 0) {
    final response = await fetch(EnvConfig.staging.cardDatabaseUrl);
    final bodyBytes = response.bodyBytes;
    console.log('Database file not found, downloading...');
    if (bodyBytes.isNotEmpty) {
      console.log('Database downloaded, saving to ${stagingFile.path}');
      await stagingFile.writeAsBytes(bodyBytes);
    } else {
      throw Exception('HTTP error');
    }
  }
}
/// Copy the bundled cards.cdb from assets to a writable path, then open
/// it as a read-only SQLite database.  Safe to call multiple times;
/// subsequent calls are a no-op.
Future<void> initDatabase(String dbPath) async {
  final _database = CardDatabase.instance;
  console.log('Opening database at $dbPath ${_database.rawdb?.isOpen}');
  if (_database.rawdb != null) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _database.rawdb = await openDatabase(
    dbPath,
    readOnly: true,
    singleInstance: true,
  );

  _database.dao = CardDao(_database.rawdb!);
}

Future<void> ensureDao(EnvType envType) async {
  final file = envType == EnvType.staging
      ? await _test_dbPath()
      : await _dbPath();
  await initDatabase(file.path);
}
