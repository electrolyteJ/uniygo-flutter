@JS()
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:ocgcore/src/ocgcore_bindings_generated.web.dart';

/// 空 Registrar —— [OcgCoreWebPlugin.registerWith] 只注入脚本，
/// 不使用 registrar 上的任何成员。
class _NoopRegistrar extends Fake implements Registrar {}

@JS('document')
external JSObject get _document;

@JS('window.Module')
external JSObject? get _module;

@JS('window.fetch')
external JSPromise<JSObject> _fetch(JSString url);

extension type _Response(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

JSObject _newScript(String textOrSrc, {required bool isSrc}) {
  final el =
      _document.callMethod('createElement'.toJS, 'script'.toJS) as JSObject;
  if (isSrc) {
    el['src'] = textOrSrc.toJS;
  } else {
    el['textContent'] = textOrSrc.toJS;
  }
  return el;
}

void _appendToHead(JSObject el) {
  (_document['head']! as JSObject).callMethod('appendChild'.toJS, el);
}

/// Web 平台：在 `flutter test --platform chrome` 环境下装配 ocgcore WASM。
///
/// 与真实 App 的差异（测试服务器的限制）：
/// 1. flutter test 的 web server 不提供 `assets/...` 资产路由，
///    生成代码里写死的 `assets/packages/ocgcore/web/libs/libocgcore.{js,wasm}`
///    会 404。这里在插件注入后改写 `Module.locateFile`，并额外注入指向
///    `/web_assets/`（test/web_assets 下的符号链接，由测试服务器静态目录
///    提供）的 <script>。
/// 2. web 测试中 rootBundle 无资产后端（永远收不到应答），卡牌脚本
///    （ScriptLoader 经 rootBundle 读取 `vendor/scripts/<name>`）改为通过
///    `flutter/assets` mock handler 从 `/web_assets/scripts/<name>` fetch。
void ensureOcgCoreWebScripts() {
  OcgCoreWebPlugin.registerWith(_NoopRegistrar());

  final module = _module;
  if (module == null) {
    throw StateError('ocgcore prelude did not create window.Module');
  }
  module['locateFile'] = ((JSString path) {
    return '/web_assets/libocgcore.wasm'.toJS;
  }).toJS;
  _appendToHead(_newScript('/web_assets/libocgcore.js', isSrc: true));

  _installAssetMessageHandler();
}

bool _assetHandlerInstalled = false;

void _installAssetMessageHandler() {
  if (_assetHandlerInstalled) return;
  _assetHandlerInstalled = true;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final key = utf8.decode(
      message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );
    const prefixes = ['packages/ocgcore/vendor/scripts/'];
    for (final prefix in prefixes) {
      if (key.startsWith(prefix)) {
        final name = key.substring(prefix.length);
        return _fetchAssetBytes('/web_assets/scripts/$name');
      }
    }
    // 其它资产在 web 测试服务器上不存在；直接返回 null 让 rootBundle
    // 快速报 "asset does not exist"，避免默认实现永久挂起。
    return null;
  });
}

Future<ByteData?> _fetchAssetBytes(String url) async {
  try {
    final resp = _Response(await _fetch(url.toJS).toDart);
    if (!resp.ok) return null;
    final buf = await resp.arrayBuffer().toDart;
    return buf.toDart.asByteData();
  } catch (_) {
    return null;
  }
}
