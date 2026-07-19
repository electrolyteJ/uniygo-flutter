/// Web (WASM) platform adapter for ocgcore.
///
/// On the web platform ocgcore is compiled to WebAssembly via Emscripten and
/// exposed through the `Module` global defined by `libocgcore.js`.  This class
/// implements the shared [OcgCore] interface using `dart:js_interop` so the
/// same ocgcore C API can be called from Dart web code.
///
/// **Usage:**
/// ```dart
/// // 1. Ensure <script src="libs/libocgcore.js"> is in web/index.html
/// // 2. Wait for the WASM runtime:
/// final wasm = await OcgCoreWasmAdapter.initialize();
/// // 3. Use as any OcgCore:
/// final pduel = wasm.createDuel(42);
/// wasm.setPlayerInfo(pduel, 0, 8000, 5, 1);
/// // ...
/// wasm.endDuel(pduel);
/// ```
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'ocgcore.dart';

// ---------------------------------------------------------------------------
// JS global type declarations
// ---------------------------------------------------------------------------

@JS()
external JSObject? get Module;

// Emscripten heap helpers (always present once runtime is loaded).
@JS('Module.HEAPU8')
external JSObject get heapU8;

@JS('Module.getValue')
external JSNumber getValue(JSAny ptr, JSString type);

@JS('Module.setValue')
external void setValue(JSAny ptr, JSAny value, JSString type);

// ocgcore C API — exported as `Module._functionName` by Emscripten.

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

@JS('Module._end_duel')
external void endDuelC(int pduel);

@JS('Module._start_duel')
external void startDuelC(int pduel, int options);

@JS('Module._set_player_info')
external void setPlayerInfoC(int pduel, int playerid, int lp, int startCount, int drawCount);

@JS('Module._new_card')
external void newCardC(int pduel, int code, int owner, int playerid, int location, int sequence, int position);

@JS('Module._new_tag_card')
external void newTagCardC(int pduel, int code, int owner, int location);

@JS('Module._process')
external int processC(int pduel);

@JS('Module._get_message')
external int getMessageC(int pduel, int bufPtr);

@JS('Module._get_log_message')
external void getLogMessageC(int pduel, int bufPtr);

@JS('Module._query_field_count')
external int queryFieldCountC(int pduel, int playerid, int location);

@JS('Module._query_card')
external int queryCardC(int pduel, int playerid, int location, int sequence, int queryFlag, int bufPtr, int useCache);

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

// Emscripten memory management.

@JS('Module._malloc')
external int wasmMalloc(int size);

@JS('Module._free')
external void wasmFree(int ptr);

@JS('Module.stringToUTF8OnStack')
external int stringToUTF8OnStack(JSString s);

@JS('Module.UTF8ToString')
external JSString utf8ToString(int ptr);

// ---------------------------------------------------------------------------
// WASM adapter
// ---------------------------------------------------------------------------

class OcgCoreWasmAdapter implements OcgCore {
  OcgCoreWasmAdapter._();

  static OcgCoreWasmAdapter? _instance;

  static OcgCoreWasmAdapter get instance {
    _instance ??= OcgCoreWasmAdapter._();
    return _instance!;
  }

  bool _ready = false;
  bool get isReady => _ready;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  static Future<OcgCoreWasmAdapter> initialize() async {
    final w = instance;
    if (w._ready) return w;

    final mod = Module;
    if (mod == null) {
      await _waitFor(() => Module != null, timeoutMs: 30000);
    }

    await _waitFor(
      () {
        try {
          final m = Module;
          if (m == null) return false;
          return (m['_create_duel'] != null);
        } catch (_) {
          return false;
        }
      },
      timeoutMs: 30000,
    );

    w._ready = true;
    return w;
  }

  static Future<void> _waitFor(
    bool Function() predicate, {
    int timeoutMs = 30000,
  }) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Timed out waiting for ocgcore WASM runtime.');
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // ---------------------------------------------------------------------------
  // Memory helpers
  // ---------------------------------------------------------------------------

  /// Read [n] bytes from WASM heap at [ptr] into a Dart list.
  List<int> _wasmReadBytes(int ptr, int n) {
    final result = <int>[];
    for (var i = 0; i < n; i++) {
      result.add(getValue((ptr + i).toJS, 'i8'.toJS).toDartInt);
    }
    return result;
  }

  /// Copy [data] bytes into WASM heap at [ptr].
  void _wasmWriteBytes(int ptr, Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      setValue((ptr + i).toJS, data[i].toJS, 'i8'.toJS);
    }
  }

  /// Read a NUL-terminated C string from WASM memory.
  String _wasmReadString(int ptr) => utf8ToString(ptr).toDart;

  // ---------------------------------------------------------------------------
  // OcgCore: Duel lifecycle
  // ---------------------------------------------------------------------------

  @override
  int createDuel(int seed) => createDuelC(seed);

  @override
  int createDuelV2(Uint32List seeds) {
    assert(seeds.length == 8, 'Seed sequence must have exactly 8 elements.');
    final buf = wasmMalloc(8 * 4); // 8 × uint32
    try {
      for (var i = 0; i < 8; i++) {
        setValue((buf + i * 4).toJS, seeds[i].toJS, 'i32'.toJS);
      }
      return createDuelV2C(buf.toJS);
    } finally {
      wasmFree(buf);
    }
  }

  @override
  void startDuel(int pduel, int options) => startDuelC(pduel, options);

  @override
  void endDuel(int pduel) => endDuelC(pduel);

  // ---------------------------------------------------------------------------
  // OcgCore: Player setup
  // ---------------------------------------------------------------------------

  @override
  void setPlayerInfo(
    int pduel,
    int playerid,
    int lp,
    int startCount,
    int drawCount,
  ) {
    setPlayerInfoC(pduel, playerid, lp, startCount, drawCount);
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Cards
  // ---------------------------------------------------------------------------

  @override
  void newCard(
    int pduel,
    int code,
    int owner,
    int playerid,
    int location,
    int sequence,
    int position,
  ) {
    newCardC(pduel, code, owner, playerid, location, sequence, position);
  }

  @override
  void newTagCard(int pduel, int code, int owner, int location) {
    newTagCardC(pduel, code, owner, location);
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Game loop
  // ---------------------------------------------------------------------------

  @override
  int process(int pduel) => processC(pduel);

  @override
  int getMessage(int pduel, Uint8List out) {
    final buf = wasmMalloc(out.length);
    try {
      final ret = getMessageC(pduel, buf);
      if (ret > 0) {
        final bytes = _wasmReadBytes(buf, ret);
        for (var i = 0; i < ret; i++) {
          out[i] = bytes[i];
        }
      }
      return ret;
    } finally {
      wasmFree(buf);
    }
  }

  @override
  String getLogMessage(int pduel) {
    const bufSize = 1024;
    final buf = wasmMalloc(bufSize);
    try {
      getLogMessageC(pduel, buf);
      return _wasmReadString(buf);
    } finally {
      wasmFree(buf);
    }
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Query
  // ---------------------------------------------------------------------------

  @override
  int queryFieldCount(int pduel, int playerid, int location) =>
      queryFieldCountC(pduel, playerid, location);

  @override
  int queryCard(
    int pduel,
    int playerid,
    int location,
    int sequence,
    int queryFlag,
    Uint8List out,
    int useCache,
  ) {
    final buf = wasmMalloc(out.length);
    try {
      final ret = queryCardC(pduel, playerid, location, sequence, queryFlag, buf, useCache);
      if (ret > 0) {
        final bytes = _wasmReadBytes(buf, ret);
        for (var i = 0; i < ret; i++) {
          out[i] = bytes[i];
        }
      }
      return ret;
    } finally {
      wasmFree(buf);
    }
  }

  @override
  int queryFieldCard(
    int pduel,
    int playerid,
    int location,
    int queryFlag,
    Uint8List out,
    int useCache,
  ) {
    final buf = wasmMalloc(out.length);
    try {
      final ret = queryFieldCardC(pduel, playerid, location, queryFlag, buf, useCache);
      if (ret > 0) {
        final bytes = _wasmReadBytes(buf, ret);
        for (var i = 0; i < ret; i++) {
          out[i] = bytes[i];
        }
      }
      return ret;
    } finally {
      wasmFree(buf);
    }
  }

  @override
  int queryFieldInfo(int pduel, Uint8List out) {
    final buf = wasmMalloc(out.length);
    try {
      final ret = queryFieldInfoC(pduel, buf);
      if (ret > 0) {
        final bytes = _wasmReadBytes(buf, ret);
        for (var i = 0; i < ret; i++) {
          out[i] = bytes[i];
        }
      }
      return ret;
    } finally {
      wasmFree(buf);
    }
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Responses
  // ---------------------------------------------------------------------------

  @override
  void setResponsei(int pduel, int value) => setResponseiC(pduel, value);

  @override
  void setResponseb(int pduel, Uint8List data) {
    final buf = wasmMalloc(data.length);
    try {
      _wasmWriteBytes(buf, data);
      setResponsebC(pduel, buf);
    } finally {
      wasmFree(buf);
    }
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Script
  // ---------------------------------------------------------------------------

  @override
  int preloadScript(int pduel, String name) {
    final namePtr = stringToUTF8OnStack(name.toJS);
    return preloadScriptC(pduel, namePtr);
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Callbacks
  // ---------------------------------------------------------------------------

  @override
  void setScriptReader(ScriptReader? f) {
    _scriptReader = f;
    if (f == null) {
      setScriptReaderCC(0.toJS);
      return;
    }
    final callback = (JSString scriptName, JSAny lenPtr) {
      final name = scriptName.toDart;
      final bytes = _scriptCache[name];
      setValue(lenPtr, (bytes?.length ?? 0).toJS, 'i32'.toJS);
      if (bytes == null) {
        return 0;
      }
      final ptr = wasmMalloc(bytes.length);
      _wasmWriteBytes(ptr, bytes);
      return ptr;
    }.toJS;
    setScriptReaderCC(callback);
  }

  @override
  void setCardReader(CardReader? f) {
    _cardReader = f;
    if (f == null) {
      setCardReaderCC(0.toJS);
      return;
    }
    final callback = (int code, int dataPtr) {
      if (_cardCache.containsKey(code)) {
        _fillCardData(dataPtr, _cardCache[code]!);
        return OPERATION_SUCCESS;
      }
      return OPERATION_FAIL;
    }.toJS;
    setCardReaderCC(callback);
  }

  void _fillCardData(int dataPtr, CardData cardData) {
    setValue((dataPtr + 0).toJS, cardData.code.toJS, 'i32'.toJS);
    setValue((dataPtr + 4).toJS, cardData.alias.toJS, 'i32'.toJS);
    for (var i = 0; i < cardData.setcode.length && i < 16; i++) {
      setValue((dataPtr + 8 + i * 2).toJS, cardData.setcode[i].toJS, 'i16'.toJS);
    }
    setValue((dataPtr + 40).toJS, cardData.type.toJS, 'i32'.toJS);
    setValue((dataPtr + 44).toJS, cardData.level.toJS, 'i32'.toJS);
    setValue((dataPtr + 48).toJS, cardData.attribute.toJS, 'i32'.toJS);
    setValue((dataPtr + 52).toJS, cardData.race.toJS, 'i32'.toJS);
    setValue((dataPtr + 56).toJS, cardData.attack.toJS, 'i32'.toJS);
    setValue((dataPtr + 60).toJS, cardData.defense.toJS, 'i32'.toJS);
    setValue((dataPtr + 64).toJS, cardData.lscale.toJS, 'i32'.toJS);
    setValue((dataPtr + 68).toJS, cardData.rscale.toJS, 'i32'.toJS);
    setValue((dataPtr + 72).toJS, cardData.linkMarker.toJS, 'i32'.toJS);
    setValue((dataPtr + 76).toJS, cardData.ruleCode.toJS, 'i32'.toJS);
  }

  ScriptReader? _scriptReader;
  final Map<String, Uint8List> _scriptCache = {};
  CardReader? _cardReader;
  final Map<int, CardData> _cardCache = {};

  @override
  Future<void> preloadScriptAsync(String name) async {
    if (_scriptReader == null) return;
    if (_scriptCache.containsKey(name)) return;
    final data = await _scriptReader!(name);
    if (data != null) {
      _scriptCache[name] = data;
    }
  }

  @override
  Future<void> preloadCardAsync(int code) async {
    if (_cardReader == null) return;
    if (_cardCache.containsKey(code)) return;
    final cardData = await _cardReader!(code);
    if (cardData != null) {
      _cardCache[code] = cardData;
    }
  }

  @override
  void setMessageHandler(MessageHandler? f) {
    if (f == null) {
      setMessageHandlerCC(0.toJS);
      return;
    }
    final callback = (int pduel, int msgType) {
      f(pduel, msgType);
      return OPERATION_SUCCESS;
    }.toJS;
    setMessageHandlerCC(callback);
  }

  // ---------------------------------------------------------------------------
  // OcgCore: Default script reader
  // ---------------------------------------------------------------------------

  @override
  Uint8List? defaultScriptReader(String scriptName, List<int> len) {
    final namePtr = stringToUTF8OnStack(scriptName.toJS);
    final lenPtr = wasmMalloc(4);
    try {
      final result = defaultScriptReaderCC(namePtr, lenPtr);
      if (result == 0) {
        len[0] = 0;
        return null;
      }
      len[0] = getValue(lenPtr.toJS, 'i32'.toJS).toDartInt;
      final data = Uint8List(len[0]);
      final bytes = _wasmReadBytes(result, len[0]);
      for (var i = 0; i < len[0]; i++) {
        data[i] = bytes[i];
      }
      wasmFree(result);
      return data;
    } finally {
      wasmFree(lenPtr);
    }
  }
}
