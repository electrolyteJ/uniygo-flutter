/// console.log 门面 — 与 dart:developer 的 log() 同名同签名。
///
/// 项目内统一用法：
///
/// ```dart
/// import 'package:applog/console.dart' as console;
///
/// console.log('message', name: 'MyTag');
/// ```
///
/// 行为：始终转发到 dart:developer（保留控制台 / IDE 调试体验）；
/// 若 [DuelLogSession] 已挂接文件 sink，同步追加写入磁盘日志，
/// 供事后交给 AI 分析决斗房间会话。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'src/duel_log_session.dart';

export 'src/duel_log_session.dart' show DuelLogSession;

/// 与 dart:developer 的 log() 完全同签名，替换 import 后调用点零改动。
void log(
  String message, {
  DateTime? time,
  int? sequenceNumber,
  int level = 0,
  String name = '',
  Zone? zone,
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    zone: zone,
    error: error,
    stackTrace: stackTrace,
  );
  DuelLogSession.writeLine(
    message,
    name: name,
    level: level,
    error: error,
    stackTrace: stackTrace,
  );
}
