/// 平台自适应本地存储
///
/// 使用条件导出按编译时平台选择实现：
/// - 原生平台（dart:io 可用）→ 文件系统（path_provider）
/// - Web 平台（dart:io 不可用）→ SharedPreferences（浏览器存储）
///
/// 用法：
/// ```dart
/// final storage = YgoStorage();
///
/// // 获取文档目录路径（原生返回真实路径，web 返回 ''）
/// final base = await storage.documentsPath;
///
/// // 读写字符串
/// await storage.writeString('decks/mydeck.json', jsonStr);
/// final json = await storage.readString('decks/mydeck.json');
///
/// // 读写字节
/// await storage.writeBytes('data/cache.bin', bytes);
/// final bytes = await storage.readBytes('data/cache.bin');
///
/// // 枚举目录
/// final files = await storage.list('decks');
/// ```
export 'src/storage_web.dart'
    if (dart.library.io) 'src/storage_io.dart';
