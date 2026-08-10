/// Web 平台存储 — 基于 SharedPreferences（浏览器 localStorage）
///
/// 仅在 dart:io 不可用时编译（Web）。
///
/// ## 适用场景
/// 适合**中小型 K/V 数据**（卡组 JSON、配置、缓存），上限约 **5 MB**。
/// Web 没有真正的文件系统，文件路径映射为 SharedPreferences 的 key，
/// 字节数据以 base64 编码存储。
///
/// ## 不适用场景
/// 大型二进制数据（如 SQLite `cards.cdb` 100MB+）**不能**用此存储。
/// 这类场景应在 web 端走 WASM SQLite + OPFS（Origin Private File System），
/// 原生端仍走文件系统。调用方可通过 [documentsPath] 是否为空来判断平台
/// 并选择不同的数据加载策略。

import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// 平台自适应本地存储 — Web 实现
class YgoStorage {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // 路径
  // ---------------------------------------------------------------------------

  /// Web 端没有真实的文件系统目录，返回空字符串。
  /// 调用方可用此判断是否为 web 平台，走不同的 SQLite / 文件读取策略。
  Future<String> get documentsPath async => '';

  // ---------------------------------------------------------------------------
  // 字符串
  // ---------------------------------------------------------------------------

  Future<String?> readString(String path) async {
    final prefs = await _p;
    return prefs.getString(_key(path));
  }

  Future<void> writeString(String path, String content) async {
    final prefs = await _p;
    await prefs.setString(_key(path), content);
  }

  // ---------------------------------------------------------------------------
  // 字节
  // ---------------------------------------------------------------------------

  Future<Uint8List?> readBytes(String path) async {
    final prefs = await _p;
    final b64 = prefs.getString(_bytesKey(path));
    if (b64 == null) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBytes(String path, List<int> data) async {
    final prefs = await _p;
    await prefs.setString(_bytesKey(path), base64Encode(data));
  }

  // ---------------------------------------------------------------------------
  // 文件 / 目录操作
  // ---------------------------------------------------------------------------

  Future<bool> exists(String path) async {
    final prefs = await _p;
    return prefs.containsKey(_key(path)) ||
        prefs.containsKey(_bytesKey(path));
  }

  Future<void> delete(String path) async {
    final prefs = await _p;
    await prefs.remove(_key(path));
    await prefs.remove(_bytesKey(path));
  }

  /// 列举目录下的所有"文件"（即 key 以 `dirPath/` 为前缀的条目）。
  Future<List<String>> list(String dirPath) async {
    final prefs = await _p;
    final prefix = '$_storagePrefix${dirPath.isEmpty ? '' : '$dirPath/'}';
    return prefs
        .getKeys()
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Web 端不需要创建目录（SharedPreferences 是扁平的 key-value 存储）。
  Future<void> createDir(String dirPath) async {
    // no-op on web
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  static const String _storagePrefix = 'ygo_storage/';
  static const String _bytesPrefix = 'ygo_storage_bytes/';

  /// 字符串数据的 key。
  String _key(String path) => '$_storagePrefix$path';

  /// 字节数据的 key（独立前缀避免与字符串 key 冲突）。
  String _bytesKey(String path) => '$_bytesPrefix$path';
}
