import 'dart:io';

import 'config.dart';

/// Result of [verifyArtifacts].
class VerifyReport {
  VerifyReport({
    required this.missingSymbols,
    required this.jsBytes,
    required this.wasmBytes,
    required this.wasmMagicOk,
  });

  final List<String> missingSymbols;
  final int jsBytes;
  final int wasmBytes;
  final bool wasmMagicOk;

  bool get ok => missingSymbols.isEmpty && wasmMagicOk;

  @override
  String toString() {
    final buf = StringBuffer()
      ..writeln('verify: ${ok ? 'OK' : 'FAIL'}')
      ..writeln('  js:   $jsBytes bytes')
      ..writeln(
          '  wasm: $wasmBytes bytes${wasmMagicOk ? '' : '（magic 头不正确，可能不是 wasm 文件）'}');
    if (missingSymbols.isNotEmpty) {
      buf.writeln('  缺失符号: ${missingSymbols.join(', ')}');
    }
    return buf.toString().trimRight();
  }
}

/// Checks that the built artifacts contain every symbol declared in
/// [WasmBridgeConfig.link] (`exported_functions` / `exported_runtime_methods`)
/// and that the .wasm has the `\0asm` magic header.
///
/// Symbol presence is checked against the JS glue: Emscripten emits one
/// assignment per exported function (e.g. `Module["_malloc"] = _malloc = ...`)
/// and per exported runtime method.
VerifyReport verifyArtifacts(WasmBridgeConfig config) {
  final js = File(config.outputJs);
  final wasm = File(config.outputWasm);
  if (!js.existsSync() || !wasm.existsSync()) {
    throw WasmBridgeException('产物不存在: ${js.path} / ${wasm.path}');
  }
  final glue = js.readAsStringSync();

  final missing = <String>[];
  for (final fn in config.link.exportedFunctions) {
    final name = fn.startsWith('_') ? fn : '_$fn';
    if (!RegExp('(^|[^\\w])${RegExp.escape(name)}([^\\w]|\$)').hasMatch(glue)) {
      missing.add(fn);
    }
  }
  for (final method in config.link.exportedRuntimeMethods) {
    if (!RegExp('(^|[^\\w])${RegExp.escape(method)}([^\\w]|\$)')
        .hasMatch(glue)) {
      missing.add(method);
    }
  }

  final wasmBytes = wasm.readAsBytesSync();
  final magicOk = wasmBytes.length >= 4 &&
      wasmBytes[0] == 0x00 &&
      wasmBytes[1] == 0x61 &&
      wasmBytes[2] == 0x73 &&
      wasmBytes[3] == 0x6d;

  return VerifyReport(
    missingSymbols: missing,
    jsBytes: js.lengthSync(),
    wasmBytes: wasmBytes.length,
    wasmMagicOk: magicOk,
  );
}
