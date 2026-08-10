import 'dart:io';

import 'config.dart';

/// Emscripten 运行时方法的已知签名。`link.exported_runtime_methods` 中
/// 列出的方法若在此表内，会一并生成类型化声明；HEAP* 生成 typed-view getter；
/// 其余（如 ccall/cwrap）跳过并在注释里说明。
const _knownRuntimeMethods = <String, String>{
  'getValue':
      "@JS('Module.getValue')\nexternal JSNumber getValue(JSAny ptr, JSString type);",
  'setValue':
      "@JS('Module.setValue')\nexternal void setValue(JSAny ptr, JSAny value, JSString type);",
  'UTF8ToString':
      "@JS('Module.UTF8ToString')\nexternal JSString utf8ToString(int ptr);",
  'stringToUTF8OnStack':
      "@JS('Module.stringToUTF8OnStack')\nexternal int stringToUTF8OnStack(JSString s);",
  'addFunction':
      "@JS('Module.addFunction')\nexternal int addFunctionCC(JSAny callback, JSString sig);",
  'removeFunction':
      "@JS('Module.removeFunction')\nexternal void removeFunctionCC(int ptr);",
};

/// 生成 dart:js_interop 接口声明文件的内容。
///
/// 包含三部分：
/// 1. `Module` 全局对象 getter；
/// 2. `link.exported_runtime_methods` 中已知签名方法的类型化声明；
/// 3. `bindings.functions` 签名表里的 C API 声明（`Module._xxx`）。
String renderBindings(WasmBridgeConfig config) {
  final buf = StringBuffer()
    ..writeln(
        '/// GENERATED CODE - DO NOT EDIT. 由 wasm_bridge 根据 wasm_bridge.yaml 生成。')
    ..writeln('library;')
    ..writeln()
    ..writeln("import 'dart:js_interop';")
    ..writeln()
    ..write(renderBindingsDecls(config));
  return buf.toString();
}

/// 只生成声明部分（不含文件头/library/imports），供合并输出复用。
String renderBindingsDecls(WasmBridgeConfig config) {
  final bindings = config.bindings;
  if (bindings == null) {
    throw WasmBridgeException('配置里没有 bindings: 段');
  }
  final buf = StringBuffer()
    ..writeln('@JS()')
    ..writeln('external JSObject? get Module;')
    ..writeln();

  // 运行时方法：HEAP* -> JSObject getter，已知签名 -> 类型化声明。
  final skipped = <String>[];
  for (final method in config.link.exportedRuntimeMethods) {
    if (method.startsWith('HEAP')) {
      final dartName =
          'heap${method.substring(4)}'; // HEAPU8 -> heapU8
      buf
        ..writeln("@JS('Module.$method')")
        ..writeln('external JSObject get $dartName;')
        ..writeln();
      continue;
    }
    final decl = _knownRuntimeMethods[method];
    if (decl == null) {
      skipped.add(method);
      continue;
    }
    buf
      ..writeln(decl)
      ..writeln();
  }
  if (skipped.isNotEmpty) {
    buf
      ..writeln('// 以下运行时方法没有内置签名，未生成声明：${skipped.join(', ')}。')
      ..writeln('// 需要时请用 Module[...]（dart:js_interop_unsafe）动态访问。')
      ..writeln();
  }

  // C API：按签名表生成 `Module._xxx` 声明。
  final declared = <String>{};
  for (final fn in bindings.functions) {
    declared.add(fn.jsName);
    final params =
        fn.params.entries.map((e) => '${e.value} ${e.key}').join(', ');
    buf
      ..writeln("@JS('Module.${fn.jsName}')")
      ..writeln('external ${fn.returns} ${fn.dartName}($params);')
      ..writeln();
  }

  // 导出了但签名表未声明的函数：告警，提醒补签名。
  final missing = config.link.exportedFunctions
      .where((f) => !declared.contains(f))
      .toList();
  if (missing.isNotEmpty) {
    buf
      ..writeln('// WARNING: link.exported_functions 中以下函数未在')
      ..writeln('// bindings.functions 声明签名，未生成接口：')
      ..writeln('//   ${missing.join(', ')}');
  }

  return buf.toString();
}

/// 生成并落盘，返回写入的文件与缺失签名的函数列表（用于 CLI 告警）。
(File, List<String>) writeBindings(WasmBridgeConfig config) {
  final bindings = config.bindings!;
  final file = File(bindings.output);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(renderBindings(config));
  final declared = bindings.functions.map((f) => f.jsName).toSet();
  final missing = config.link.exportedFunctions
      .where((f) => !declared.contains(f))
      .toList();
  return (file, missing);
}
