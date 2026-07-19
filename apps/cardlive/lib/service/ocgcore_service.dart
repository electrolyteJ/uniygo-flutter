import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ocgcore/ocgcore.dart';
import 'package:path_provider/path_provider.dart';
import '../model/card_model.dart';

class OcgcoreService {
  static OcgcoreService? _instance;
  OcgCore? _ocgCore;
  int? _duel;
  final Map<int, CardData> _cardCache = {};
  bool _initialized = false;

  OcgcoreService._();

  factory OcgcoreService() {
    _instance ??= OcgcoreService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    _ocgCore = createOcgCore();
    if (_ocgCore == null) {
      throw Exception('不支持当前平台');
    }
    _ocgCore!.setScriptReader(_scriptReader);
    _ocgCore!.setCardReader(_cardReader);

    _initialized = true;
  }

  Future<void> initWithBinding() async {
    if (_initialized) return;

    _ocgCore = createOcgCore();
    if (_ocgCore == null) {
      throw Exception('不支持当前平台');
    }

    try {
      await _preloadScriptsWithBinding();
    } catch (e) {
      throw Exception('脚本预加载失败: $e');
    }

    _ocgCore!.setScriptReader(_scriptReader);
    _ocgCore!.setCardReader(_cardReader);

    _initialized = true;
  }

  Future<void> _preloadScriptsWithBinding() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  Future<void> _preloadDefaultScripts() async {
    final defaultScripts = [
      'constant.lua',
      'utility.lua',
      'procedure.lua',
      'c483.lua',
      'c2511.lua',
      'c35699.lua',
      'c73776643.lua',
      'c89226534.lua',
      'c31863912.lua',
      'c40005099.lua',
      'c10000.lua',
    ];

    for (final scriptName in defaultScripts) {
      try {
        final assetPath = 'assets/scripts/$scriptName';
        final byteData = await rootBundle.load(assetPath);
        _scriptCache[scriptName] = byteData.buffer.asUint8List();
      } catch (e) {
        print('Failed to load default script $scriptName: $e');
      }
    }
  }

  Map<String, dynamic> _parseManifest(String content) {
    try {
      final trimmed = content.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final pairs = <String, dynamic>{};
        final regex = RegExp(r'"([^"]+)":\s*\[([^\]]*)\]');
        for (final match in regex.allMatches(trimmed)) {
          pairs[match.group(1)!] = [];
        }
        return pairs;
      }
    } catch (_) {}
    return {};
  }

  Uint8List? _scriptReader(String scriptName, List<int> len)  {
    var name = scriptName;
    if (name.startsWith('./script/')) {
      name = name.substring('./script/'.length);
    }
    rootBundle.load('assets/scripts/$name').then((byteData) {
      return byteData.buffer.asUint8List();
    }).catchError((e) {
      print('Failed to load script $name: $e');
    });
    return null;
  }

  int _cardReader(int code, dynamic data) {
    if (_cardCache.containsKey(code)) {
      return OPERATION_SUCCESS;
    }
    return OPERATION_SUCCESS;
  }

  void cacheCard(CardData card) {
    _cardCache[card.code] = card;
  }

  Future<String> executeCardScript(int code) async {
    if (!_initialized) {
      await init();
    }

    if (_ocgCore == null) {
      return 'ocgcore 未初始化';
    }

    try {
      _duel = _ocgCore!.createDuel(0);
      _ocgCore!.setPlayerInfo(_duel!, 0, 8000, 0, 0);
      _ocgCore!.setPlayerInfo(_duel!, 1, 8000, 0, 0);

      _ocgCore!.newCard(_duel!, code, 0, 0, 1, 0, 0x100000);

      final result = _ocgCore!.process(_duel!);

      final msgBuffer = Uint8List(4096);
      final msgLen = _ocgCore!.getMessage(_duel!, msgBuffer);

      _ocgCore!.endDuel(_duel!);
      _duel = null;

      if (msgLen > 0) {
        return '脚本执行成功，消息长度: $msgLen，处理器状态: $result';
      }
      return '脚本执行成功，处理器状态: $result';
    } catch (e) {
      if (_duel != null) {
        try {
          _ocgCore!.endDuel(_duel!);
        } catch (_) {}
        _duel = null;
      }
      return '脚本执行失败: $e';
    }
  }
}