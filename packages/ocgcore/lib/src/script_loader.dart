import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// ocgcore lua 脚本加载器 —— 带缓存的 [ScriptReader] 实现。
///
/// 脚本统一由 ocgcore 包内置（pubspec 资产声明 `../../vendor/scripts/`，
/// 打包后资产 key 规范化为 `vendor/scripts/<name>`）。
///
/// 解析顺序：
///  rootBundle `vendor/scripts/<name>`（App / 测试环境资产包）
class ScriptLoader {
  final _cache = <String, Uint8List>{};

  Future<Uint8List?> load(String name) async {
    if (_cache.containsKey(name)) return _cache[name];
    try {
      final data = await rootBundle.load('vendor/scripts/$name');
      final bytes = data.buffer.asUint8List();
      _cache[name] = bytes;
      return bytes;
    } catch (_) {}
    return null;
  }
}
