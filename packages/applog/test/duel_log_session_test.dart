import 'dart:io';

import 'package:applog/console.dart' as console;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late String logPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('applog_test');
    logPath = '${tmp.path}/logs/duel_latest.log';
  });

  tearDown(() async {
    await console.DuelLogSession.stop();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('start 创建文件并写会话头，log 落盘，stop 写会话尾', () async {
    await console.DuelLogSession.start(logPath);
    expect(console.DuelLogSession.isActive, isTrue);
    expect(console.DuelLogSession.currentFilePath, logPath);

    console.log('hello duel', name: 'Test');
    console.log('with error', error: 'boom', stackTrace: StackTrace.empty);
    await console.DuelLogSession.stop();

    final content = await File(logPath).readAsString();
    expect(content, contains('===== Duel session'));
    expect(content, contains('[Test] hello duel'));
    expect(content, contains('with error'));
    expect(content, contains('error: boom'));
    expect(content, contains('===== Session end'));
    expect(console.DuelLogSession.isActive, isFalse);
  });

  test('重复 start 覆盖重写同一份日志', () async {
    await console.DuelLogSession.start(logPath);
    console.log('first session line');
    await console.DuelLogSession.start(logPath);
    console.log('second session line');
    await console.DuelLogSession.stop();

    final content = await File(logPath).readAsString();
    expect(content, isNot(contains('first session line')));
    expect(content, contains('second session line'));
  });

  test('stop 幂等；未 start 时 log 不产生文件', () async {
    console.log('no session');
    await console.DuelLogSession.stop();
    expect(await File(logPath).exists(), isFalse);
  });

  test('路径父目录不存在时自动创建', () async {
    final deep = '${tmp.path}/a/b/c/duel_latest.log';
    await console.DuelLogSession.start(deep);
    console.log('nested');
    await console.DuelLogSession.stop();
    expect(await File(deep).exists(), isTrue);
  });
}
