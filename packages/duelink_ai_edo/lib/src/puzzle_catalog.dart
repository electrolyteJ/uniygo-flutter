import 'dart:convert';
import 'package:applog/console.dart' as console;
import 'dart:io';

import 'package:flutter/services.dart';

/// 残局元数据 —— 描述一个残局脚本（EDOPro/ProjectIgnis 格式）。
class PuzzleInfo {
  /// 引擎加载名：`puzzle/<category>/<file>.lua`
  final String scriptName;

  /// 分类（仓库顶层目录名，如 `World Championship`）
  final String category;

  /// 文件名（不含扩展名，如 `[WCS2006]01_Warriors of Darkness`）
  final String fileName;

  /// 残局说明（`--[[message ... ]]` 块内容，未解析时为 null）
  final String? description;

  /// 解法（`--[[ Solution: ... ]]` 块内容，未解析时为 null）
  final String? solution;

  const PuzzleInfo({
    required this.scriptName,
    required this.category,
    required this.fileName,
    this.description,
    this.solution,
  });

  /// 展示名：下划线转空格。
  String get displayName => fileName.replaceAll('_', ' ');

  @override
  String toString() => 'PuzzleInfo($scriptName)';
}

/// 残局目录 —— 枚举并解析资产包（根 vendor/Puzzles，
/// ProjectIgnis 残局合集 submodule）。
///
/// 两阶段使用：
/// 1. [list] 轻量枚举（仅路径/分类/文件名，不读文件内容）；
/// 2. [detail] 按需读取脚本并解析说明/解法注释块。
class PuzzleCatalog {
  /// 枚举全部残局（不含说明/解法）。
  Future<List<PuzzleInfo>> list() async {
    final paths = await _listAssetPaths();
    final puzzles = <PuzzleInfo>[];
    for (final p in paths) {
      final info = _infoFromPath(p);
      if (info != null) puzzles.add(info);
    }
    puzzles.sort((a, b) => a.scriptName.compareTo(b.scriptName));
    return puzzles;
  }

  /// 读取脚本全文并解析说明/解法。
  Future<PuzzleInfo?> detail(PuzzleInfo info) async {
    final text = await _loadScriptText(info.scriptName);
    if (text == null) return null;
    return parse(info.scriptName, text);
  }

  /// 解析残局脚本文本（纯函数，便于测试）。
  static PuzzleInfo parse(String scriptName, String text) {
    final rel = scriptName.startsWith('puzzle/')
        ? scriptName.substring('puzzle/'.length)
        : scriptName;
    final parts = rel.split('/');
    final fileName =
        parts.last.endsWith('.lua') ? parts.last.substring(0, parts.last.length - 4) : parts.last;
    final category = parts.length > 1 ? parts.first : '';
    return PuzzleInfo(
      scriptName: scriptName,
      category: category,
      fileName: fileName,
      description: _extractBlock(text, 'message'),
      solution: _extractBlock(text, 'Solution'),
    );
  }

  /// 提取 `--[[<tag> ... ]]` 注释块内容。
  static String? _extractBlock(String text, String tag) {
    final re = RegExp('--\\[\\[\\s*$tag\\s*:?(.*?)\\]\\]', dotAll: true);
    final m = re.firstMatch(text);
    final content = m?.group(1)?.trim();
    return (content == null || content.isEmpty) ? null : content;
  }

  // ── 路径枚举 ──

  /// App 运行时：从资产清单枚举。
  /// key 形如 `vendor/Puzzles/<category>/<file>.lua`（App 端归一化）
  Future<List<String>> _listAssetPaths() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest
          .listAssets()
          .where((k) =>
              k.contains('vendor/Puzzles/') && k.endsWith('.lua'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 资产 key → [PuzzleInfo]（仅路径信息）。
  PuzzleInfo? _infoFromPath(String path) {
    const marker = 'vendor/Puzzles/';
    final i = path.indexOf(marker);
    if (i < 0) return null;
    final rel = path.substring(i + marker.length);
    final parts = rel.split('/');
    final file = parts.last;
    if (!file.endsWith('.lua')) return null;
    return PuzzleInfo(
      scriptName: 'puzzle/$rel',
      category: parts.length > 1 ? parts.first : '',
      fileName: file.substring(0, file.length - 4),
    );
  }

  Future<String?> _loadScriptText(String scriptName) async {
    final rel = scriptName.startsWith('puzzle/')
        ? scriptName.substring('puzzle/'.length)
        : scriptName;
      // App 运行时：包资产归一化后的 key（即 _listAssetPaths 枚举到的 key）。
    for (final p in ['vendor/Puzzles/$rel']) {
      try {
        final data = await rootBundle.load(p);
        return utf8.decode(data.buffer.asUint8List(), allowMalformed: true);
      } catch (_) {}
      try {
        final file = File(p);
        if (await file.exists()) {
          return utf8.decode(await file.readAsBytes(), allowMalformed: true);
        }
      } catch (_) {}
    }
    return null;
  }
}
