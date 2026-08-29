/// 原生平台存储 — 基于 path_provider + dart:io
///
/// 仅在 dart:io 可用时编译（Android / iOS / macOS / Windows / Linux）。

import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 平台自适应本地存储 — 原生实现
class YgoStorage {
  String? _docsPath;

  /// 应用文档目录的绝对路径
  Future<String> get documentsPath async {
    _docsPath ??= (await getApplicationDocumentsDirectory()).path;
    return _docsPath!;
  }

  // ---------------------------------------------------------------------------
  // 字符串
  // ---------------------------------------------------------------------------

  Future<String?> readString(String path) async {
    try {
      final file = io.File(await _fullPath(path));
      if (!file.existsSync()) return null;
      return file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeString(String path, String content) async {
    final file = io.File(await _fullPath(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  // ---------------------------------------------------------------------------
  // 字节
  // ---------------------------------------------------------------------------

  Future<List<int>?> readBytes(String path) async {
    try {
      final file = io.File(await _fullPath(path));
      if (!file.existsSync()) return null;
      return file.readAsBytesSync().toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBytes(String path, List<int> data) async {
    final file = io.File(await _fullPath(path));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data);
  }

  // ---------------------------------------------------------------------------
  // 文件 / 目录操作
  // ---------------------------------------------------------------------------

  Future<bool> exists(String path) async {
    return io.File(await _fullPath(path)).exists();
  }

  Future<void> delete(String path) async {
    final f = io.File(await _fullPath(path));
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<List<String>> list(String dirPath) async {
    try {
      final dir = io.Directory(await _fullPath(dirPath));
      if (!dir.existsSync()) return [];
      return dir
          .listSync()
          .whereType<io.File>()
          .map((f) => p.basename(f.path))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> createDir(String dirPath) async {
    final dir = io.Directory(await _fullPath(dirPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  Future<String> _fullPath(String relative) async {
    return p.join(await documentsPath, relative);
  }
}
