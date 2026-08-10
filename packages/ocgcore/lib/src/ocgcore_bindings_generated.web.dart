/// GENERATED CODE - DO NOT EDIT. 由 wasm_bridge 根据 wasm_bridge.yaml 生成。
///
/// Web platform plugin for ocgcore.
///
/// 向页面注入 <script src="assets/...js"> 加载 Emscripten glue；
/// 前置内联脚本定义 Module.locateFile 指向 wasm 资产 URL（动态注入的
/// 脚本里 document.currentScript 为 null，默认推导会失败）。
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS()
external JSObject? get Module;

@JS('Module.getValue')
external JSNumber getValue(JSAny ptr, JSString type);

@JS('Module.setValue')
external void setValue(JSAny ptr, JSAny value, JSString type);

@JS('Module.UTF8ToString')
external JSString utf8ToString(int ptr);

@JS('Module.stringToUTF8OnStack')
external int stringToUTF8OnStack(JSString s);

@JS('Module.HEAPU8')
external JSObject get heapU8;

@JS('Module.addFunction')
external int addFunctionCC(JSAny callback, JSString sig);

@JS('Module.removeFunction')
external void removeFunctionCC(int ptr);

// 以下运行时方法没有内置签名，未生成声明：ccall, cwrap。
// 需要时请用 Module[...]（dart:js_interop_unsafe）动态访问。

@JS('Module._set_script_reader')
external void setScriptReaderCC(JSAny callback);

@JS('Module._set_card_reader')
external void setCardReaderCC(JSAny callback);

@JS('Module._set_message_handler')
external void setMessageHandlerCC(JSAny callback);

@JS('Module._default_script_reader')
external int defaultScriptReaderCC(int namePtr, int lenPtr);

@JS('Module._create_duel')
external int createDuelC(int seed);

@JS('Module._create_duel_v2')
external int createDuelV2C(JSAny seedSequence);

@JS('Module._start_duel')
external void startDuelC(int pduel, int options);

@JS('Module._end_duel')
external void endDuelC(int pduel);

@JS('Module._set_player_info')
external void setPlayerInfoC(int pduel, int playerid, int lp, int startCount, int drawCount);

@JS('Module._get_log_message')
external void getLogMessageC(int pduel, int bufPtr);

@JS('Module._get_message')
external int getMessageC(int pduel, int bufPtr);

@JS('Module._process')
external int processC(int pduel);

@JS('Module._new_card')
external void newCardC(int pduel, int code, int owner, int playerid, int location, int sequence, int position);

@JS('Module._new_tag_card')
external void newTagCardC(int pduel, int code, int owner, int location);

@JS('Module._query_card')
external int queryCardC(int pduel, int playerid, int location, int sequence, int queryFlag, int bufPtr, int useCache);

@JS('Module._query_field_count')
external int queryFieldCountC(int pduel, int playerid, int location);

@JS('Module._query_field_card')
external int queryFieldCardC(int pduel, int playerid, int location, int queryFlag, int bufPtr, int useCache);

@JS('Module._query_field_info')
external int queryFieldInfoC(int pduel, int bufPtr);

@JS('Module._set_responsei')
external void setResponseiC(int pduel, int value);

@JS('Module._set_responseb')
external void setResponsebC(int pduel, int bufPtr);

@JS('Module._preload_script')
external int preloadScriptC(int pduel, int namePtr);

@JS('Module._malloc')
external int wasmMalloc(int size);

@JS('Module._free')
external void wasmFree(int ptr);

@JS()
external JSObject get document;

extension type _HTMLScriptElement(JSObject _) implements JSObject {
  external set textContent(JSString value);
  external set src(JSString value);
}

class OcgCoreWebPlugin {
  static bool _injected = false;

  static void registerWith(Registrar registrar) {
    if (_injected) return;
    final window = document['defaultView'] as JSObject?;
    if (window != null && window['__ocgcoreScriptInjected'] == true.toJS) {
      _injected = true;
      return;
    }
    _injected = true;

    final head = document['head'] as JSObject;
    final prelude = _newScript()
      ..textContent = ('var Module=window.Module||{};'
              'Module.locateFile=function(p){return "assets/packages/ocgcore/web/libs/libocgcore.wasm";};'
              'Module.onRuntimeInitialized=function(){'
              'window.__ocgcorePluginStatus="runtime_initialized";};'
              'Module.onAbort=function(what){'
              'window.__lastOcgcoreError=String(what);'
              'window.__ocgcorePluginStatus="runtime_abort:"+String(what);};')
          .toJS;
    head.callMethod('appendChild'.toJS, prelude);
    final script = _newScript()..src = 'assets/packages/ocgcore/web/libs/libocgcore.js'.toJS;
    head.callMethod('appendChild'.toJS, script);
    window?['__ocgcoreScriptInjected'] = true.toJS;
  }

  static _HTMLScriptElement _newScript() {
    return _HTMLScriptElement(
        document.callMethod('createElement'.toJS, 'script'.toJS) as JSObject);
  }
}
