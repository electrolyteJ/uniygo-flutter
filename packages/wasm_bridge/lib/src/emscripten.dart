import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';

/// Result of a successful build.
class BuildResult {
  BuildResult(this.jsFile, this.wasmFile);
  final File jsFile;
  final File wasmFile;
}

/// wasm_bridge 自举安装 emsdk 的持久缓存目录。
///
/// 不用 `/tmp`（重启会被清理）。遵循 XDG：`$XDG_CACHE_HOME/wasm_bridge/emsdk`，
/// 未设置时 `~/.cache/wasm_bridge/emsdk`。
String defaultEmsdkCacheDir() {
  final home = Platform.environment['HOME'] ?? '/';
  final xdg = Platform.environment['XDG_CACHE_HOME'];
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : p.join(home, '.cache');
  return p.join(base, 'wasm_bridge', 'emsdk');
}

/// Locates the em++ compiler.
///
/// Search order: `EMSDK_DIR` env var -> config `emsdk` ->
/// [defaultEmsdkCacheDir]（`wasm_bridge install` 的安装位置）->
/// `/tmp/emsdk` -> `~/emsdk` -> `em++` on PATH.
File findEmCompiler(WasmBridgeConfig? config) {
  final candidates = <String>[
    if (Platform.environment['EMSDK_DIR'] != null)
      Platform.environment['EMSDK_DIR']!,
    if (config?.emsdkDir != null) config!.emsdkDir!,
    defaultEmsdkCacheDir(),
    '/tmp/emsdk',
    p.join(Platform.environment['HOME'] ?? '/', 'emsdk'),
  ];
  for (final dir in candidates) {
    final emxx = File(p.join(dir, 'upstream', 'emscripten', 'em++'));
    if (emxx.existsSync()) return emxx;
  }
  final pathEnv = Platform.environment['PATH'] ?? '';
  for (final dir in pathEnv.split(':')) {
    final emxx = File(p.join(dir, 'em++'));
    if (emxx.existsSync()) return emxx;
  }
  throw WasmBridgeException(
      '找不到 em++。可运行以下命令让 wasm_bridge 自动安装 emsdk（需联网）：\n'
      '  dart run wasm_bridge install\n'
      '或通过 EMSDK_DIR 环境变量 / 配置项 emsdk 指定已有 emsdk 路径。');
}

/// Bootstraps an emsdk checkout so the tool works on machines without one.
///
/// Clones the emsdk repo (shallow) into [dir] when missing, then runs
/// `emsdk install <version>` + `emsdk activate <version>`. [version] defaults
/// to `latest`; pin it via the `emsdk_version` config key for reproducible
/// builds. Requires network access and may download several GB.
Future<File> installEmsdk({String? dir, String version = 'latest'}) async {
  final target = dir ??
      Platform.environment['EMSDK_DIR'] ??
      defaultEmsdkCacheDir();
  final emsdkDir = Directory(target);

  if (!File(p.join(target, 'emsdk')).existsSync()) {
    stdout.writeln('克隆 emsdk 到 $target ...');
    emsdkDir.parent.createSync(recursive: true);
    await _runChecked('git', [
      'clone',
      '--depth',
      '1',
      'https://github.com/emscripten-core/emsdk.git',
      target,
    ]);
  } else {
    stdout.writeln('emsdk 仓库已存在: $target（跳过克隆）');
  }

  final emsdkBin = p.join(target, 'emsdk');
  stdout.writeln('emsdk install $version ...（下载量较大，请耐心等待）');
  await _runChecked(emsdkBin, ['install', version]);
  stdout.writeln('emsdk activate $version ...');
  await _runChecked(emsdkBin, ['activate', version]);

  final emxx = File(p.join(target, 'upstream', 'emscripten', 'em++'));
  if (!emxx.existsSync()) {
    throw WasmBridgeException('安装完成但未找到 em++: ${emxx.path}');
  }
  stdout.writeln('安装完成: ${emxx.path}');
  return emxx;
}

Future<void> _runChecked(String executable, List<String> args) async {
  final process = await Process.start(executable, args,
      mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) {
    throw WasmBridgeException('命令失败（exit $code）: $executable ${args.join(' ')}');
  }
}

/// Composes the em++ argument list for [config] (exposed for testing).
List<String> composeEmccArgs(WasmBridgeConfig config) {
  final args = <String>[];
  args.addAll(config.compileFlags);

  for (final entry in config.defines.entries) {
    args.add(entry.value == null
        ? '-D${entry.key}'
        : '-D${entry.key}=${entry.value}');
  }
  for (final dir in config.includeDirs) {
    args.add('-I$dir');
  }

  // Source groups, honouring per-group language overrides (-x c++ / -x c).
  for (final group in config.sources) {
    final files = group.resolveFiles();
    if (group.language != null) {
      args.addAll(['-x', group.language!]);
    }
    args.addAll(files.map((f) => f.path));
    if (group.language != null) {
      args.addAll(['-x', 'none']);
    }
  }

  final link = config.link;
  if (link.exceptions) args.add('-fwasm-exceptions');
  if (link.noEntry) args.add('--no-entry');
  if (link.allowMemoryGrowth) args.add('-sALLOW_MEMORY_GROWTH');
  if (link.initialMemory != null) {
    args.add('-sINITIAL_MEMORY=${link.initialMemory}');
  }
  if (link.allowTableGrowth) args.add('-sALLOW_TABLE_GROWTH');
  if (link.exportedFunctions.isNotEmpty) {
    args.add('-sEXPORTED_FUNCTIONS=${link.exportedFunctions.join(',')}');
  }
  if (link.exportedRuntimeMethods.isNotEmpty) {
    args.add(
        '-sEXPORTED_RUNTIME_METHODS=${link.exportedRuntimeMethods.join(',')}');
  }
  if (link.environment.isNotEmpty) {
    args.add('-sENVIRONMENT=${link.environment.join(',')}');
  }
  args.addAll(link.extraFlags);

  args.addAll(['-o', config.outputJs]);
  return args;
}

/// Runs the em++ build for [config].
Future<BuildResult> buildWasm(WasmBridgeConfig config) async {
  final emxx = findEmCompiler(config);
  final args = composeEmccArgs(config);

  Directory(p.dirname(config.outputJs)).createSync(recursive: true);

  stdout.writeln('> ${emxx.path} ${args.join(' ')}');
  final process = await Process.start(emxx.path, args,
      workingDirectory: config.configDir, mode: ProcessStartMode.inheritStdio);
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw WasmBridgeException('em++ 构建失败（exit $exitCode）');
  }

  final js = File(config.outputJs);
  final wasm = File(config.outputWasm);
  if (!js.existsSync() || !wasm.existsSync()) {
    throw WasmBridgeException('构建结束但产物缺失: ${js.path} / ${wasm.path}');
  }
  return BuildResult(js, wasm);
}
