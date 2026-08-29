import 'dart:developer' as console;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../ygo_card_mycard.dart';
import '../card_dao.dart';
import 'card_database.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> preDownloadDatabase() async {
  console.log('Web platform detected, using bundled database');
  await initDatabase('cards.cdb');
}

Future<void> ensureDao(EnvType envType) async {
  await initDatabase('cards.cdb');
}

Future<void> initDatabase(String dbPath) async {
  final _database = CardDatabase.instance;
  console.log('Opening database at $dbPath ${_database.rawdb?.isOpen}');
  if (_database.rawdb != null) return;
  databaseFactory = databaseFactoryFfiWeb;
  // 2. 检查并从 assets 复制数据库到虚拟文件系统
  console.log('Checking database file at $dbPath');
  if (!await databaseFactory.databaseExists(dbPath)) {
    ByteData data = await rootBundle.load(
      'packages/ygo_card_mycard/assets/$dbPath',
    );
    await databaseFactory.writeDatabaseBytes(
      dbPath,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
  _database.rawdb = await openDatabase(
    dbPath,
    readOnly: true,
    singleInstance: true,
  );

  _database.dao = CardDao(_database.rawdb!);
}
