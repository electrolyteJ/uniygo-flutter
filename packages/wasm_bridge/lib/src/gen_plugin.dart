import 'dart:io';

import 'config.dart';
import 'gen_bindings.dart';

/// 生成 Flutter web 插件：向页面注入一个 `<script src="assets/...js">`，
/// 并前置一段内联 prelude 定义 `Module`：
/// - `locateFile` 指向 wasm 的资产 URL——动态注入的脚本里
///   `document.currentScript` 为 null，Emscripten 默认推导不出 .wasm 路径；
/// - `onRuntimeInitialized`/`onAbort` 把状态写到
///   `window.__<debugPrefix>PluginStatus`，供 Dart 侧做健康检查。
String renderWebPlugin(PluginGenConfig config) {
  return _render(_header + _classTemplate, config);
}

/// 当 plugin.output 与 bindings.output 指向同一文件时，生成合并文件：
/// 统一的 import 块 + dart:js_interop 绑定声明 + 插件类。
String renderWebCombined(WasmBridgeConfig config) {
  final plugin = config.plugin;
  if (plugin == null) {
    throw WasmBridgeException('配置里没有 plugin: 段');
  }
  final decls = renderBindingsDecls(config);
  return _render(_header + decls + _classTemplate, plugin);
}

String _render(String template, PluginGenConfig config) {
  return template
      .replaceAll('__CLASS__', config.className)
      .replaceAll('__PACKAGE__', config.package)
      .replaceAll('__JS_URL__', 'assets/${config.jsAsset}')
      .replaceAll('__WASM_URL__', 'assets/${config.wasmAsset}')
      .replaceAll('@PREFIX_PASCAL@', _pascal(config.debugPrefix))
      .replaceAll('@PREFIX@', config.debugPrefix)
      .trimLeft();
}

/// 生成并落盘，返回写入的文件。
File writeWebPlugin(PluginGenConfig config) {
  final file = File(config.output);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(renderWebPlugin(config));
  return file;
}

/// 合并模式落盘，返回写入的文件。
File writeWebCombined(WasmBridgeConfig config) {
  final file = File(config.plugin!.output);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(renderWebCombined(config));
  return file;
}

String _pascal(String name) =>
    name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

const _header = r'''
/// GENERATED CODE - DO NOT EDIT. 由 wasm_bridge 根据 wasm_bridge.yaml 生成。
///
/// Web platform plugin for __PACKAGE__.
///
/// 向页面注入 <script src="assets/...js"> 加载 Emscripten glue；
/// 前置内联脚本定义 Module.locateFile 指向 wasm 资产 URL（动态注入的
/// 脚本里 document.currentScript 为 null，默认推导会失败）。
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

''';

const _classTemplate = r'''
@JS()
external JSObject get document;

extension type _HTMLScriptElement(JSObject _) implements JSObject {
  external set textContent(JSString value);
  external set src(JSString value);
}

class __CLASS__ {
  static bool _injected = false;

  static void registerWith(Registrar registrar) {
    if (_injected) return;
    final window = document['defaultView'] as JSObject?;
    if (window != null && window['__@PREFIX@ScriptInjected'] == true.toJS) {
      _injected = true;
      return;
    }
    _injected = true;

    final head = document['head'] as JSObject;
    final prelude = _newScript()
      ..textContent = ('var Module=window.Module||{};'
              'Module.locateFile=function(p){return "__WASM_URL__";};'
              'Module.onRuntimeInitialized=function(){'
              'window.__@PREFIX@PluginStatus="runtime_initialized";};'
              'Module.onAbort=function(what){'
              'window.__last@PREFIX_PASCAL@Error=String(what);'
              'window.__@PREFIX@PluginStatus="runtime_abort:"+String(what);};')
          .toJS;
    head.callMethod('appendChild'.toJS, prelude);
    final script = _newScript()..src = '__JS_URL__'.toJS;
    head.callMethod('appendChild'.toJS, script);
    window?['__@PREFIX@ScriptInjected'] = true.toJS;
  }

  static _HTMLScriptElement _newScript() {
    return _HTMLScriptElement(
        document.callMethod('createElement'.toJS, 'script'.toJS) as JSObject);
  }
}
''';
