import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// ocgcore lua 脚本加载器 —— 带缓存的 [ScriptReader] 实现。
///
/// 优先从 Flutter asset（assets/scripts/）读取，失败时退到文件系统
/// 相对路径（测试环境 flutter_tester 无 asset bundle）。
class ScriptLoader {
  final _cache = <String, Uint8List>{};

  Future<Uint8List?> load(String name) async {
    if (_cache.containsKey(name)) return _cache[name];
    try {
      final data = await rootBundle.load('assets/scripts/$name');
      final bytes = data.buffer.asUint8List();
      _cache[name] = bytes;
      return bytes;
    } catch (_) {
      try {
        final file = File('assets/scripts/$name');
        final bytes = await file.readAsBytes();
        _cache[name] = bytes;
        return bytes;
      } catch (_) {
        return null;
      }
    }
  }
}
