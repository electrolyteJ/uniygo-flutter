import 'dart:io';

import 'package:args/args.dart';
import 'package:wasm_bridge/wasm_bridge.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addCommand(
        'build',
        ArgParser()
          ..addOption('config',
              abbr: 'c', defaultsTo: 'wasm_bridge.yaml', help: '配置文件路径')
          ..addFlag('skip-verify', defaultsTo: false, help: '构建后跳过导出符号校验'))
    ..addCommand(
        'verify',
        ArgParser()
          ..addOption('config',
              abbr: 'c', defaultsTo: 'wasm_bridge.yaml', help: '配置文件路径'))
    ..addCommand(
        'gen',
        ArgParser()
          ..addOption('config',
              abbr: 'c', defaultsTo: 'wasm_bridge.yaml', help: '配置文件路径'))
    ..addCommand(
        'doctor',
        ArgParser()
          ..addOption('config',
              abbr: 'c',
              defaultsTo: 'wasm_bridge.yaml',
              help: '配置文件路径（可选，用于读取 emsdk 配置）'))
    ..addCommand(
        'install',
        ArgParser()
          ..addOption('config',
              abbr: 'c',
              defaultsTo: 'wasm_bridge.yaml',
              help: '配置文件路径（可选，用于读取 emsdk/emsdk_version 配置）')
          ..addOption('dir', help: '安装目录（默认: ~/.cache/wasm_bridge/emsdk）')
          ..addOption('version', help: 'emsdk 版本（默认: 配置的 emsdk_version 或 latest）'))
    ..addFlag('help', abbr: 'h', negatable: false);

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    _printUsage(parser);
    exit(64);
  }

  if (args['help'] as bool || args.command == null) {
    _printUsage(parser);
    exit(args.command == null && !(args['help'] as bool) ? 64 : 0);
  }

  final command = args.command!;
  try {
    switch (command.name) {
      case 'build':
        final config = WasmBridgeConfig.load(command['config'] as String);
        final result = await buildWasm(config);
        stdout.writeln('built: ${result.jsFile.path}');
        stdout.writeln('built: ${result.wasmFile.path}');
        if (!(command['skip-verify'] as bool)) {
          final report = verifyArtifacts(config);
          stdout.writeln(report);
          if (!report.ok) {
            stderr.writeln('verify failed: 存在缺失的导出符号');
            exit(1);
          }
        }
        _runGen(config);
      case 'verify':
        final config = WasmBridgeConfig.load(command['config'] as String);
        final report = verifyArtifacts(config);
        stdout.writeln(report);
        if (!report.ok) exit(1);
      case 'gen':
        final config = WasmBridgeConfig.load(command['config'] as String);
        _runGen(config);
      case 'doctor':
        WasmBridgeConfig? config;
        final path = command['config'] as String;
        if (File(path).existsSync()) {
          config = WasmBridgeConfig.load(path);
        }
        final emxx = findEmCompiler(config);
        stdout.writeln('em++: ${emxx.path}');
        final version = await Process.run(emxx.path, ['--version']);
        stdout.writeln((version.stdout as String).split('\n').first);
      case 'install':
        WasmBridgeConfig? config;
        final path = command['config'] as String;
        if (File(path).existsSync()) {
          config = WasmBridgeConfig.load(path);
        }
        final emxx = await installEmsdk(
          dir: (command['dir'] as String?) ?? config?.emsdkDir,
          version: (command['version'] as String?) ??
              config?.emsdkVersion ??
              'latest',
        );
        stdout.writeln('doctor 验证:');
        final version = await Process.run(emxx.path, ['--version']);
        stdout.writeln((version.stdout as String).split('\n').first);
    }
  } on WasmBridgeException catch (e) {
    stderr.writeln('error: ${e.message}');
    exit(1);
  }
}

/// 按配置生成 Flutter web 插件与 dart 接口声明（未配置则跳过对应部分）。
void _runGen(WasmBridgeConfig config) {
  var generated = false;
  final plugin = config.plugin;
  final bindings = config.bindings;
  // plugin.output 与 bindings.output 同路径时生成单个合并文件。
  if (plugin != null && bindings != null && plugin.output == bindings.output) {
    final file = writeWebCombined(config);
    stdout.writeln('generated: ${file.path}');
    _warnMissingSignatures(config);
    return;
  }
  if (plugin != null) {
    final file = writeWebPlugin(plugin);
    stdout.writeln('generated: ${file.path}');
    generated = true;
  }
  if (bindings != null) {
    final (file, _) = writeBindings(config);
    stdout.writeln('generated: ${file.path}');
    _warnMissingSignatures(config);
    generated = true;
  }
  if (!generated) {
    stdout.writeln('配置中没有 plugin:/bindings: 段，无需生成。');
  }
}

void _warnMissingSignatures(WasmBridgeConfig config) {
  final bindings = config.bindings;
  if (bindings == null) return;
  final declared = bindings.functions.map((f) => f.jsName).toSet();
  final missing = config.link.exportedFunctions
      .where((f) => !declared.contains(f))
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
        'warning: 以下导出函数未在 bindings.functions 声明签名，未生成接口: '
        '${missing.join(', ')}');
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('用法: dart run wasm_bridge <command> [options]');
  stdout.writeln('');
  stdout.writeln('commands:');
  stdout.writeln('  build    编译 C/C++ 为 wasm/js 并校验导出符号');
  stdout.writeln('  verify   只校验已有产物是否包含配置的导出符号');
  stdout.writeln('  gen      生成 Flutter web 插件注入代码与 dart:js_interop 接口');
  stdout.writeln('  doctor   检查 Emscripten 工具链是否可用');
  stdout.writeln('  install  自动下载安装 emsdk（环境没有 em++ 时使用，需联网）');
  stdout.writeln('');
  stdout.writeln(parser.usage);
}
