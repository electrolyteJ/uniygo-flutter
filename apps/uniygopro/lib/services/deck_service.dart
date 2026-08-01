import 'dart:convert';
import 'dart:developer' as console;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ygo_card/card_info.dart';
import '../models/deck_model.dart';
import '../service_singleton.dart';

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
  Future<List<DeckMeta>> loadDeckList() async {
    final deckDir = await _getDeckDir();
    final dir = Directory(deckDir);
    final files = await dir.list().toList();

    final decks = <DeckMeta>[];
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          decks.add(DeckMeta.fromJson(json));
        } catch (e) {
          // 跳过损坏的文件
          console.log('Failed to load deck from ${file.path}: $e');
        }
      }
    }

    return decks;
  }

  /// 加载卡组内容
  Future<EditingDeck?> loadDeck(String deckName) async {
    // 1. 先从本地存储加载
    final deckDir = await _getDeckDir();
    File file = File(p.join(deckDir, '$deckName.json'));
    String content ;
    if (await file.exists()) {
      try {
        content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        final main = (json['main'] as List?)
            ?.map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [];
        final extra = (json['extra'] as List?)
            ?.map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [];
        final side = (json['side'] as List?)
            ?.map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [];

        return EditingDeck(
          deckName: deckName,
          main: main,
          extra: extra,
          side: side,
        );
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
        return importFromYdk(content, deckName);
      }
    } catch (e) {
      // 加载失败返回 null
    }

    return null;
  }

  /// 保存卡组
  Future<bool> saveDeck(EditingDeck deck) async {
    try {
      final deckDir = await _getDeckDir();
      final file = File(p.join(deckDir, '${deck.deckName}.json'));

      final json = {
        'deckName': deck.deckName,
        'mainCount': deck.mainCount,
        'extraCount': deck.extraCount,
        'sideCount': deck.sideCount,
        'updatedAt': DateTime.now().toIso8601String(),
        'main': deck.main.map((c) => c.toJson()).toList(),
        'extra': deck.extra.map((c) => c.toJson()).toList(),
        'side': deck.side.map((c) => c.toJson()).toList(),
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
  Future<EditingDeck?> importFromYdk(String content, String deckName) async {
    try {
      final lines = content.split('\n').map((l) => l.trim()).toList();

      final mainIds = <int>[];
      final extraIds = <int>[];
      final sideIds = <int>[];

      var currentSection = 0; // 0: main, 1: extra, 2: side

      for (final line in lines) {
        if (line.startsWith('#')) {
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
              mainIds.add(id);
              break;
            case 1:
              extraIds.add(id);
              break;
            case 2:
              sideIds.add(id);
              break;
          }
        }
      }

      final main = await _cardsFromIds(mainIds);
      final extra = await _cardsFromIds(extraIds);
      final side = await _cardsFromIds(sideIds);

      return EditingDeck(
        deckName: deckName,
        main: main,
        extra: extra,
        side: side,
      );
    } catch (e) {
      console.log('Failed to import deck from YDK: $e');
      return null;
    }
  }

  /// 根据卡牌ID列表查询卡牌信息
  Future<List<CardInfo>> _cardsFromIds(List<int> ids) async {
    final cards = <CardInfo>[];
    for (final id in ids) {
      final c = await ServiceSingleton.instance.cardService.getCard(id);
      if (c != null) {
        cards.add(c);
      }
    }
    return cards;
  }

  /// 加载内置的默认卡组（从 assets/decks/*.ydk）
  Future<List<DeckMeta>> loadBuiltinDecks() async {
    final decks = <DeckMeta>[];

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      // 找出所有 assets/decks/ 下的 .ydk 文件
      final ydkFiles = assets
          .where((key) => key.startsWith('assets/decks/') && key.endsWith('.ydk'))
          .toList();
      console.log('Found ${ydkFiles.length} built-in decks in assets/decks/');
      for (final path in ydkFiles) {
        final content = await rootBundle.loadString(path);
        final fileName = p.basenameWithoutExtension(path);
        final deck = await importFromYdk(content, fileName);
        console.log('Loaded built-in deck: $fileName, cards: ${deck?.mainCount ?? 0} main, ${deck?.extraCount ?? 0} extra, ${deck?.sideCount ?? 0} side');
        if (deck != null) {
          decks.add(deck.toMeta().copyWith(isBuiltin: true));
        }
      }
    } catch (e) {
      // 加载内置卡组失败不影响使用
      console.log('assetMap: $e');
    }

    return decks;
  }

  /// 导出为 YDK 格式
  String exportToYdk(EditingDeck deck) {
    final buffer = StringBuffer();
    buffer.writeln('#created by uniygopro');
    buffer.writeln('#main');
    for (final card in deck.main) {
      buffer.writeln(card.code);
    }
    buffer.writeln('#extra');
    for (final card in deck.extra) {
      buffer.writeln(card.code);
    }
    buffer.writeln('!side');
    for (final card in deck.side) {
      buffer.writeln(card.code);
    }
    return buffer.toString();
  }
}
