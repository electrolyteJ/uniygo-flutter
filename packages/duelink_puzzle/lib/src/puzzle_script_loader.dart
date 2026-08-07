import 'dart:developer' as console;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ocgcore/ocgcore.dart';

/// 残局脚本加载器 —— 多根目录解析的 [ScriptReader]。
///
/// 解析规则：
/// - `puzzle/<path>`（残局脚本）→ vendor/Puzzles 资产包
///   （App 资产 key 为 `vendor/Puzzles/<path>`；
/// - 其余（`constant.lua` / `utility.lua` / `cXXXX.lua`）→
///   委托 [ScriptLoader]（ocgcore 内置的 vendor/scripts 资产）
class PuzzleScriptLoader extends ScriptLoader {
  final _cache = <String, Uint8List?>{};

  @override
  Future<Uint8List?> load(String name) async {
    if (name.startsWith('puzzle/')) {
      if (_cache.containsKey(name)) return _cache[name];
      final data = await _tryPaths(['vendor/Puzzles/${name.substring('puzzle/'.length)}']);
      _cache[name] = data;
      return data;
    }
    return super.load(name);
  }

  Future<Uint8List?> _tryPaths(List<String> paths) async {
    for (final p in paths) {
      try {
        final data = await rootBundle.load(p);
        return data.buffer.asUint8List();
      } catch (_) {}
      try {
        final file = File(p);
        if (await file.exists()) return await file.readAsBytes();
      } catch (_) {}
    }
    return null;
  }
}
