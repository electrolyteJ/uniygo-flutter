import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 决斗房间会话的文件日志 sink。
///
/// 会话边界 = 整个房间会话：进房（DuelService.connect）时 [start]，
/// 离房（disconnect）时 [stop]。每次 [start] 以覆盖模式重写同一份
/// 日志文件——只保留最近一次房间会话的日志，不做轮转。
///
/// 写盘为行缓冲 + fire-and-forget，且任何写失败都被静默吞掉：
/// 日志系统绝不允许让决斗逻辑崩溃。Web 平台整体退化为仅控制台。
class DuelLogSession {
  DuelLogSession._();

  static IOSink? _sink;

  /// 当前日志文件绝对路径；未开启会话或 Web 平台时为 null。
  static String? currentFilePath;

  /// 写失败后置位，后续写入直接丢弃，避免反复撞同一个错误。
  static bool _writeFailed = false;

  /// 是否已挂接文件 sink。
  static bool get isActive => _sink != null;

  /// 以覆盖模式打开 [filePath] 开始新会话；已在会话中则先结束旧会话。
  static Future<void> start(String filePath) async {
    if (kIsWeb) return;
    await stop();
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      _sink = file.openWrite(mode: FileMode.write);
      currentFilePath = filePath;
      _writeFailed = false;
      _sink!.writeln(
        '===== Duel session ${_fmtTs(DateTime.now())} '
        '(${Platform.operatingSystem}) =====',
      );
    } catch (_) {
      _sink = null;
      currentFilePath = null;
    }
  }

  /// 结束会话：写会话尾、flush 并关闭文件。幂等。
  static Future<void> stop() async {
    final sink = _sink;
    _sink = null;
    currentFilePath = null;
    if (sink == null) return;
    try {
      sink.writeln('===== Session end ${_fmtTs(DateTime.now())} =====');
      await sink.flush();
      await sink.close();
    } catch (_) {
      // 日志失败静默吞掉。
    }
  }

  /// 追加一行日志；未开启会话或已写失败时为 no-op。
  static void writeLine(
    String message, {
    String name = '',
    int level = 0,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final sink = _sink;
    if (sink == null || _writeFailed) return;
    final ts = _fmtTime(DateTime.now());
    final tag = name.isEmpty ? '' : ' [$name]';
    try {
      sink.writeln('$ts$tag $message');
      if (error != null) sink.writeln('$ts$tag   error: $error');
      if (stackTrace != null) sink.writeln(stackTrace.toString());
    } catch (_) {
      _writeFailed = true;
    }
  }

  static String _fmtTs(DateTime t) =>
      '${t.year}-${_p2(t.month)}-${_p2(t.day)} '
      '${_p2(t.hour)}:${_p2(t.minute)}:${_p2(t.second)}';

  static String _fmtTime(DateTime t) =>
      '${_p2(t.hour)}:${_p2(t.minute)}:${_p2(t.second)}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _p2(int v) => v.toString().padLeft(2, '0');
}
