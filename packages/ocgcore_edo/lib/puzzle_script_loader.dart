import 'package:applog/console.dart' as console;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ocgcore/ocgcore.dart';

/// 残局脚本加载器 —— 多根目录解析的 [ScriptReader]。
///
/// 资产声明（pubspec.yaml）→ 资产 key：
/// - `../../vendor/CardScripts/constant.lua` → `vendor/CardScripts/constant.lua`
/// - `../../vendor/CardScripts/goat/`         → `vendor/CardScripts/goat/<name>.lua`
/// - `../../vendor/CardScripts/official/`     → `vendor/CardScripts/official/<name>.lua`
/// - `../../vendor/Puzzles/Duel Links/`       → `vendor/Puzzles/Duel Links/<name>.lua`
///
/// 解析规则：
/// - `puzzle/<path>`（残局脚本）→ vendor/Puzzles 资产包
/// - 根目录脚本（constant.lua, proc_*.lua 等）→ `vendor/CardScripts/<name>`
/// - 卡牌脚本（cXXXX.lua）→ 依次查找 goat/ → official/
///
/// 引擎调用链：
/// - `interpreter::load_card_script(code)` → `read_script("./script/c<code>.lua")`
/// - `_onScriptReader` 剥离 `./script/` 前缀 → `load("c<code>.lua")`
/// - `interpreter` 构造时加载 `./script/constant.lua` 等基础脚本
class PuzzleScriptLoader extends ScriptLoader {
  final _customCache = <String, Uint8List?>{};

  /// 卡牌脚本查找子目录（按优先级）。
  ///
  /// _onScriptReader 将 `./script/<name>` 规范化为 `<name>`，
  /// 因此传入的 name 就是纯文件名（如 `c10000.lua` 或 `constant.lua`）。
  static const _cardScriptDirs = ['goat', 'official'];

  @override
  Future<Uint8List?> load(String name) async {

    if (_customCache.containsKey(name)) return _customCache[name];

    // 残局脚本 → vendor/Puzzles
    if (name.startsWith('puzzle/')) {
      final data = await _tryPaths([
        'vendor/Puzzles/${name.substring('puzzle/'.length)}',
      ]);
      _customCache[name] = data;
      return data;
    }

    // 根目录脚本直接命中（constant.lua, proc_*.lua 等）
    final rootPath = 'vendor/CardScripts/$name';
    final rootData = await _tryPaths([rootPath]);
    if (rootData != null) {
      _customCache[name] = rootData;
      return rootData;
    }

    // 卡牌脚本：遍历子目录查找
    for (final dir in _cardScriptDirs) {
      final data = await _tryPaths(['vendor/CardScripts/$dir/$name']);
      if (data != null) {
        _customCache[name] = data;
        return data;
      }
    }

    _customCache[name] = null;
    console.log('PuzzleScriptLoader: script not found: $name');
    return null;
  }

  @override
  List<String> get bootstrapScriptNames => const [
    'constant.lua',
    'utility.lua',
    'cards_specific_functions.lua',
    'archetype_setcode_constants.lua',
    'card_counter_constants.lua',
    'chain.lua',
    'deprecated_functions.lua',
    'debug_utility.lua',
    'proc_equip.lua',
    'proc_fusion.lua',
    'proc_fusion_spell.lua',
    'proc_gemini.lua',
    'proc_link.lua',
    'proc_maximum.lua',
    'proc_normal.lua',
    'proc_pendulum.lua',
    'proc_persistent.lua',
    'proc_ritual.lua',
    'proc_rush.lua',
    'proc_skill.lua',
    'proc_spirit.lua',
    'proc_synchro.lua',
    'proc_union.lua',
    'proc_workaround.lua',
    'proc_xyz.lua',
  ];

  /// 按顺序尝试从资产包或文件系统读取，首个成功即返回。
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
