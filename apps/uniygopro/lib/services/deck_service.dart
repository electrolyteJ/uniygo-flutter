import 'dart:convert';
import 'dart:developer' as console;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ygo_deck/deck_info.dart';

/// 卡组服务 - 负责卡组的本地存储和导入导出
class DeckService {
  static const String _deckFolder = 'decks';

  /// 获取卡组存储目录
  Future<String> _getDeckDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final deckDir = p.join(appDir.path, _deckFolder);
    final dir = Directory(deckDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return deckDir;
  }

  /// 加载所有卡组元数据
  Future<List<DeckInfo>> loadDeckList() async {
    final deckDir = await _getDeckDir();
    final dir = Directory(deckDir);
    final files = await dir.list().toList();

    final decks = <DeckInfo>[];
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          decks.add(DeckInfo.fromJson(json));
        } catch (e) {
          console.log('Failed to load deck from ${file.path}: $e');
        }
      }
    }

    return decks;
  }

  /// 加载卡组内容
  Future<DeckInfo?> loadDeck(String deckName) async {
    // 1. 先从本地存储加载
    final deckDir = await _getDeckDir();
    final file = File(p.join(deckDir, '$deckName.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return DeckInfo.fromJson(json);
      } catch (e) {
        return null;
      }
    }

    // 2. 从内置 assets 加载
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();

      final assetPath = 'assets/decks/$deckName.ydk';
      if (assets.contains(assetPath)) {
        final content = await rootBundle.loadString(assetPath);
        return _parseYdk(content, deckName);
      }
    } catch (e) {
      // 加载失败返回 null
    }

    return null;
  }

  /// 保存卡组
  Future<bool> saveDeck(DeckInfo deck) async {
    try {
      final deckDir = await _getDeckDir();
      final file = File(p.join(deckDir, '${deck.deckName}.json'));

      final json = {
        'deckName': deck.deckName,
        'mainCount': deck.mainCount,
        'extraCount': deck.extraCount,
        'sideCount': deck.sideCount,
        'updatedAt': DateTime.now().toIso8601String(),
        'mainDeck': deck.mainDeck.map((c) => c.toJson()).toList(),
        'extraDeck': deck.extraDeck.map((c) => c.toJson()).toList(),
        'sideDeck': deck.sideDeck.map((c) => c.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(json));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除卡组
  Future<bool> deleteDeck(String deckName) async {
    try {
      final deckDir = await _getDeckDir();
      final file = File(p.join(deckDir, '$deckName.json'));
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从 YDK 格式导入卡组
  Future<DeckInfo?> importFromYdk(String content, String deckName) async {
    try {
      return _parseYdk(content, deckName);
    } catch (e) {
      console.log('Failed to import deck from YDK: $e');
      return null;
    }
  }

  /// 解析 YDK 格式内容为 DeckInfo
  DeckInfo _parseYdk(String content, String deckName) {
    final lines = content.split('\n').map((l) => l.trim()).toList();

    final mainMap = <int, int>{};
    final extraMap = <int, int>{};
    final sideMap = <int, int>{};

    var currentSection = 0; // 0: main, 1: extra, 2: side

    for (final line in lines) {
      if (line.startsWith('#') || line.startsWith('!')) {
        if (line.toLowerCase().contains('extra')) {
          currentSection = 1;
        } else if (line.toLowerCase().contains('side')) {
          currentSection = 2;
        }
        continue;
      }

      final id = int.tryParse(line);
      if (id != null && id > 0) {
        switch (currentSection) {
          case 0:
            mainMap[id] = (mainMap[id] ?? 0) + 1;
            break;
          case 1:
            extraMap[id] = (extraMap[id] ?? 0) + 1;
            break;
          case 2:
            sideMap[id] = (sideMap[id] ?? 0) + 1;
            break;
        }
      }
    }

    return DeckInfo(
      deckName: deckName,
      mainDeck: mainMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
      extraDeck: extraMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
      sideDeck: sideMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
    );
  }

  /// 加载内置的默认卡组（从 assets/decks/*.ydk）
  Future<List<DeckInfo>> loadBuiltinDecks() async {
    final decks = <DeckInfo>[];

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      final ydkFiles = assets
          .where(
            (key) => key.startsWith('assets/decks/') && key.endsWith('.ydk'),
          )
          .toList();
      console.log('Found ${ydkFiles.length} built-in decks in assets/decks/');
      for (final path in ydkFiles) {
        final content = await rootBundle.loadString(path);
        final fileName = p.basenameWithoutExtension(path);
        final deck = _parseYdk(content, fileName);
        deck.isBuiltin = true;
        console.log(
          'Loaded built-in deck: $fileName, cards: ${deck.mainCount} main, ${deck.extraCount} extra, ${deck.sideCount} side',
        );
        decks.add(deck);
      }
    } catch (e) {
      console.log('Failed to load built-in decks: $e');
    }

    return decks;
  }

  /// 导出为 YDK 格式
  String exportToYdk(DeckInfo deck) {
    final buffer = StringBuffer();
    buffer.writeln('#created by uniygopro');
    buffer.writeln('#main');
    for (final card in deck.mainDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    buffer.writeln('#extra');
    for (final card in deck.extraDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    buffer.writeln('!side');
    for (final card in deck.sideDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    return buffer.toString();
  }
}
