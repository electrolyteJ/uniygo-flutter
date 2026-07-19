import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../config/env_config.dart';
import '../model/card_model.dart';
import '../model/lflist_model.dart';

class CardService {
  static CardService? _instance;
  Database? _database;
  Lflist? _lflist;
  EnvConfig _envConfig;
  late http.Client _httpClient;

  CardService._(this._envConfig) {
    _httpClient = _createHttpClient();
  }

  factory CardService(EnvConfig envConfig) {
    _instance ??= CardService._(envConfig);
    return _instance!;
  }

  http.Client _createHttpClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return http_io.IOClient(ioClient);
  }

  EnvType get envType => _envConfig.type;

  void switchEnv(EnvConfig config) {
    _envConfig = config;
    _database = null;
    _lflist = null;
  }

  Future<void> init() async {
    await _initDatabase();
    await _loadLflist();
  }

  Future<void> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/cards.cdb';
    final file = File(dbPath);

    if (!await file.exists()) {
      try {
        final response = await _httpClient.get(Uri.parse(_envConfig.cardDatabaseUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('下载数据库失败: $e');
      }
    }

    _database = await openDatabase(dbPath);
  }

  Future<void> _loadLflist() async {
    try {
      final response = await _httpClient.get(Uri.parse(_envConfig.lflistUrl));
      if (response.statusCode == 200) {
        final content = response.body;
        final lines = content.split('\n');
        String name = '';
        String date = '';
        final cards = <LflistCard>[];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('#')) {
            if (trimmed.startsWith('#name')) {
              name = trimmed.replaceAll('#name ', '');
            } else if (trimmed.startsWith('#date')) {
              date = trimmed.replaceAll('#date ', '');
            }
          } else if (trimmed.isNotEmpty) {
            try {
              cards.add(LflistCard.fromLine(trimmed));
            } catch (_) {}
          }
        }

        _lflist = Lflist(name: name, date: date, cards: cards);
      }
    } catch (_) {}
  }

  Future<CardData?> getCard(int code) async {
    if (_database == null) await _initDatabase();

    final dataResults = await _database!.query(
      'datas',
      where: 'id = ?',
      whereArgs: [code],
    );

    if (dataResults.isEmpty) return null;

    final textResults = await _database!.query(
      'texts',
      where: 'id = ?',
      whereArgs: [code],
    );

    final dataRow = dataResults.first;
    final textRow = textResults.isNotEmpty ? textResults.first : {};

    return CardData(
      code: dataRow['id'] as int,
      alias: dataRow['alias'] as int? ?? 0,
      name: textRow['name'] as String? ?? '',
      desc: textRow['desc'] as String? ?? '',
      type: dataRow['type'] as int? ?? 0,
      level: dataRow['level'] as int? ?? 0,
      attribute: dataRow['attribute'] as int? ?? 0,
      race: dataRow['race'] as int? ?? 0,
      attack: dataRow['atk'] as int? ?? 0,
      defense: dataRow['def'] as int? ?? 0,
      lscale: dataRow['lscale'] as int? ?? 0,
      rscale: dataRow['rscale'] as int? ?? 0,
      linkMarker: dataRow['link_marker'] as int? ?? 0,
      setcode: [dataRow['setcode'] as int? ?? 0],
    );
  }

  Future<List<CardData>> searchCards(String keyword) async {
    if (_database == null) await _initDatabase();

    final results = await _database!.rawQuery('''
      SELECT d.*, t.name, t.desc 
      FROM datas d 
      LEFT JOIN texts t ON d.id = t.id 
      WHERE t.name LIKE ? OR t.desc LIKE ? 
      LIMIT 50
    ''', ['%$keyword%', '%$keyword%']);

    return results.map((row) {
      return CardData(
        code: row['id'] as int,
        alias: row['alias'] as int? ?? 0,
        name: row['name'] as String? ?? '',
        desc: row['desc'] as String? ?? '',
        type: row['type'] as int? ?? 0,
        level: row['level'] as int? ?? 0,
        attribute: row['attribute'] as int? ?? 0,
        race: row['race'] as int? ?? 0,
        attack: row['atk'] as int? ?? 0,
        defense: row['def'] as int? ?? 0,
        lscale: row['lscale'] as int? ?? 0,
        rscale: row['rscale'] as int? ?? 0,
        linkMarker: row['link_marker'] as int? ?? 0,
        setcode: [row['setcode'] as int? ?? 0],
      );
    }).toList();
  }

  String getCardImageUrl(int code) {
    return _envConfig.getCardImageUrl(code);
  }

  String getCardLimitText(int code) {
    return _lflist?.getCardLimitText(code) ?? '无限制';
  }

  int getCardLimit(int code) {
    return _lflist?.getCardLimit(code) ?? 3;
  }
}