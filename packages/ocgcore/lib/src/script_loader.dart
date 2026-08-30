import 'package:applog/console.dart' as console;

import 'package:flutter/services.dart';

/// ocgcore lua 脚本加载器 —— 带缓存的 [ScriptReader] 实现。
///
/// 脚本统一由 ocgcore 包内置（pubspec 资产声明 `../../vendor/scripts/`，
/// 在原生平台打包后资产 key 为 `vendor/scripts/<name>`，
/// 在 Web 平台资产 key 为 `packages/ocgcore/vendor/scripts/<name>`）。
class ScriptLoader {
  final _cache = <String, Uint8List>{};

  /// 需要在 createDuel 前预热到 Dart 缓存中的基础脚本名。
  List<String> get bootstrapScriptNames => const [
    'constant.lua',
    'utility.lua',
    'procedure.lua',
  ];

  /// 可选：返回需要在 createDuel 前全量预加载的脚本名。
  ///
  /// 默认只依赖 [bootstrapScriptNames]；子类可覆盖为更大的脚本集合。
  Future<List<String>> listPreloadScriptNames() async => const [

  ];

  Future<Uint8List?> load(String name) async {
    if (_cache.containsKey(name)) return _cache[name];
    // 依次尝试 Native 和 Web 的资产 key
    for (final prefix in const ['vendor/scripts/', 'packages/ocgcore/vendor/scripts/']) {
      try {
        final data = await rootBundle.load('$prefix$name');
        final bytes = data.buffer.asUint8List();
        _cache[name] = bytes;
        return bytes;
      } catch (_) {
        // 尝试下一个 key
      }
    }
    console.log('ScriptLoader: failed to load script: $name');
    return null;
  }
}
