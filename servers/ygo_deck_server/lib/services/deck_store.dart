/// 卡组文件系统存储：data/decks/{deckName}.json，
/// 文件格式与 packages/ygo_deck_mycard DeckService.saveDeck 完全一致，
/// 本地 ↔ 云端可直接互通。
library;

import 'dart:convert';
import 'dart:io';

import '../models/deck_dto.dart';

/// 卡组 key（即 deckName）非法。
class InvalidDeckKeyException implements Exception {
  InvalidDeckKeyException(this.key);
  final String key;
  @override
  String toString() => 'Invalid deck key: $key';
}

class DeckStore {
  DeckStore(this.dir);

  /// 存储目录（如 data/decks）。
  final String dir;

  /// 解码路由参数 key：dart_frog 不做 URL 解码，真实请求里中文卡组名是
  /// 百分号编码的；解码失败（已是明文）时原样返回。
  static String decodeRouteKey(String key) {
    try {
      return Uri.decodeComponent(key);
    } catch (_) {
      return key;
    }
  }

  /// 校验卡组 key：拒绝空值与路径穿越。
  static void validateKey(String key) {
    if (key.isEmpty ||
        key.contains('/') ||
        key.contains(r'\') ||
        key.contains('..')) {
      throw InvalidDeckKeyException(key);
    }
  }

  File _file(String key) {
    validateKey(key);
    return File('$dir/$key.json');
  }

  /// 全部卡组列表（对应 IDeckService.loadDeckList）。
  Future<List<DeckDto>> list() async {
    final d = Directory(dir);
    if (!d.existsSync()) return [];
    final decks = <DeckDto>[];
    await for (final entity in d.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is Map<String, dynamic>) {
            decks.add(DeckDto.fromJson(json));
          }
        } catch (_) {
          // 跳过损坏文件
        }
      }
    }
    return decks;
  }

  /// 读取单个卡组；不存在返回 null（对应 IDeckService.loadDeck）。
  Future<DeckDto?> read(String key) async {
    final f = _file(key);
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(await f.readAsString());
      if (json is Map<String, dynamic>) return DeckDto.fromJson(json);
    } catch (_) {
      // 损坏文件按不存在处理
    }
    return null;
  }

  /// 保存卡组（对应 IDeckService.saveDeck）：写入 updatedAt 后落盘。
  Future<DeckDto> save(DeckDto deck) async {
    validateKey(deck.deckName);
    await Directory(dir).create(recursive: true);
    deck.updatedAt = DateTime.now().toIso8601String();
    await _file(deck.deckName).writeAsString(jsonEncode(deck.toJson()));
    return deck;
  }

  /// 删除卡组（对应 IDeckService.deleteDeck）；返回是否确实存在过。
  Future<bool> delete(String key) async {
    final f = _file(key);
    if (!f.existsSync()) return false;
    await f.delete();
    return true;
  }

  // ── YDK 导入导出（复刻 DeckService.exportToYdk / importFromYdk） ──

  /// 导出 YDK 文本（#created by / #main / #extra / !side 段）。
  String exportYdk(DeckDto deck) {
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

  /// 解析 YDK 文本为卡组（不落盘，落盘由调用方 save）。
  DeckDto importYdk(String content, String deckName) {
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

    return DeckDto(
      deckName: deckName,
      mainDeck: mainMap.entries
          .map((e) => DeckCardDto(code: e.key, count: e.value))
          .toList(),
      extraDeck: extraMap.entries
          .map((e) => DeckCardDto(code: e.key, count: e.value))
          .toList(),
      sideDeck: sideMap.entries
          .map((e) => DeckCardDto(code: e.key, count: e.value))
          .toList(),
    );
  }
}
