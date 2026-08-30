import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// [临时诊断] 全局崩溃捕获：把 FlutterError / PlatformDispatcher 收到的
/// 原始异常追加写入「应用文档目录/logs/flutter_crash.log」。
///
/// 背景：路由 push 的过渡动画 future 以错误完成时，Flutter 的
/// whenCompleteOrCancel 错误路径会在 Navigator 锁定期触发
/// `!_debugLocked` 断言，原始异常被吞掉。装这个钩子后重跑一次，
/// 原始异常与完整栈会落盘。定位完成后应整体移除本文件与
/// main.dart 中的调用。
void installCrashLogHook() {
  if (kIsWeb) return;
  FlutterError.onError = (details) {
    _append('FlutterError', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _append('PlatformDispatcher', error, stack);
    // 返回 false：继续走默认上报，不改变现有控制台行为。
    return false;
  };
}

void _append(String source, Object error, StackTrace? stack) {
  unawaited(() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/logs/flutter_crash.log');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '\n===== ${DateTime.now().toIso8601String()} [$source] =====\n'
        '$error\n$stack\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // 日志系统绝不允许让应用崩溃。
    }
  }());
}
