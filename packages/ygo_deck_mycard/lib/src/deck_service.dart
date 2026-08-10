import 'dart:convert';
import 'dart:developer' as console;

import 'package:flutter/services.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_storage/ygo_storage.dart';

/// 本地卡组服务 — 实现 [IDeckService]
///
/// 使用 [YgoStorage] 做平台自适应持久化（原生文件系统 / Web SharedPreferences），
/// 内置卡组从 `packages/ygo_deck_mycard/assets/decks/*.ydk` 加载。
class DeckService implements IDeckService {
  static const String _deckDir = 'decks';

  final YgoStorage _storage = YgoStorage();

  @override
  Future<List<DeckInfo>> loadDeckList() async {
    final builtinDecks = <DeckInfo>[];
    for (final entry in _builtinDecks.entries) {
      final deck = await _loadBuiltinDeck(entry.key, entry.value);
      if (deck != null) {
        deck.isBuiltin = true;
        builtinDecks.add(deck);
      }
    }
    console.log('MycardDeckService: loaded ${builtinDecks.length} built-in decks');

    final userDecks = <DeckInfo>[];
    try {
      final fileNames = await _storage.list(_deckDir);
      for (final name in fileNames) {
        final jsonStr = await _storage.readString('$_deckDir/$name');
        if (jsonStr != null) {
          try {
            userDecks.add(
              DeckInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      console.log('MycardDeckService: failed to load deck list: $e');
      return [];
    }
    return _mergeDecks(builtinDecks, userDecks);
  }

  List<DeckInfo> _mergeDecks(
    List<DeckInfo> builtinDecks,
    List<DeckInfo> userDecks,
  ) {
    final merged = <String, DeckInfo>{};
    for (final deck in builtinDecks) {
      merged[deck.deckName] = deck;
    }
    for (final deck in userDecks) {
      merged[deck.deckName] = deck;
    }
    return merged.values.toList();
  }

  @override
  Future<DeckInfo?> loadDeck(String deckKey) async {
    // 1. 本地存储
    try {
      final jsonStr = await _storage.readString('$_deckDir/$deckKey.json');
      if (jsonStr != null) {
        return DeckInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}

    // 2. 内置 assets — deckKey 可能是显示名，也可能是文件名 key
    final key = _builtinDecks.containsKey(deckKey) ? deckKey : _findKeyByDisplayName(deckKey);
    if (key != null) {
      return _loadBuiltinDeck(key, _builtinDecks[key]!);
    }
    return null;
  }

  @override
  Future<bool> saveDeck(DeckInfo deck) async {
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
    try {
      await _storage.writeString(
        '$_deckDir/${deck.deckName}.json',
        jsonEncode(json),
      );
      return true;
    } catch (e) {
      console.log('DeckService: failed to save deck: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteDeck(String deckName) async {
    try {
      await _storage.delete('$_deckDir/$deckName.json');
      return true;
    } catch (e) {
      console.log('DeckService: failed to delete deck: $e');
      return false;
    }
  }

  @override
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

  @override
  Future<DeckInfo?> importFromYdk(String content, String deckName) async {
    try {
      return _parseYdk(content, deckName);
    } catch (e) {
      console.log('DeckService: failed to import YDK: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 内置卡组
  // ---------------------------------------------------------------------------

  /// 内置卡组：文件名 key（ASCII，不含 .ydk 扩展名）→ 显示名
  static const _builtinDecks = <String, String>{
    'cyber_dragon': '終撃竜サイバー・ドラゴン',
    'A Starter Deck': 'A Starter Deck',
    'Blackwing': 'Blackwing',
    'Blue Eyes': 'Blue Eyes',
    'Drytron': 'Drytron',
    'Hero': 'Hero',
    'Shaddoll': 'Shaddoll',
    'Shiranui': 'Shiranui',
    'Sky Striker Ace': 'Sky Striker Ace',
    'Speedroid-Windwitch': 'Speedroid-Windwitch',
    'evil_twin': '怪盗コンビEvil★Twin',
    'rescue_ace': '超骸裝部隊R－ACE',
    'eldlich': '征服王エルドリッチ',
    'exosister': '退魔天使エクソシスター',
  };

  /// 根据显示名反查文件名 key
  String? _findKeyByDisplayName(String displayName) {
    for (final entry in _builtinDecks.entries) {
      if (entry.value == displayName) return entry.key;
    }
    return null;
  }

  /// 从 ygo_deck_mycard 包的 assets 中加载单个内置卡组
  Future<DeckInfo?> _loadBuiltinDeck(String key, String displayName) async {
    try {
      final path = 'packages/ygo_deck_mycard/assets/decks/$key.ydk';
      final content = await rootBundle.loadString(path);
      final deck = _parseYdk(content, displayName);
      deck.isBuiltin = true;
      return deck;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // YDK 解析
  // ---------------------------------------------------------------------------

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
          case 1:
            extraMap[id] = (extraMap[id] ?? 0) + 1;
          case 2:
            sideMap[id] = (sideMap[id] ?? 0) + 1;
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
}
