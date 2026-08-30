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

import 'package:applog/console.dart' as console;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../ocgcore.dart';
import 'ocgcore_bindings_generated.web.dart';

Future<OcgCore?> createOcgCore([Object? lib]) async {
  console.log('OcgCoreWasmAdapter Initializing ocgcore WASM adapter...');
  final startTime = DateTime.now().millisecondsSinceEpoch;
  try {
    final ret = await OcgCoreWasmAdapter.initialize();
    final endTime = DateTime.now().millisecondsSinceEpoch;
    console.log('OcgCoreWasmAdapter initialized in ${endTime - startTime} ms.');
    return ret;
  } catch (e) {
    final endTime = DateTime.now().millisecondsSinceEpoch;
    console.log(
      'OcgCoreWasmAdapter failed to initialize ocgcore WASM adapter in ${endTime - startTime} ms: $e',
    );
    return null;
  }
}

const int _responseBufferSize = 512;

// ---------------------------------------------------------------------------
// JS global type declarations
// ---------------------------------------------------------------------------

@JS('window.__ocgcorePluginStatus')
external JSAny? get _ocgcorePluginStatus;

@JS('window.__ocgcoreWasmExportKeys')
external JSAny? get _ocgcoreWasmExportKeys;

@JS('window.__lastOcgcoreError')
external JSAny? get _ocgcoreLastError;

// ---------------------------------------------------------------------------
// WASM adapter
// ---------------------------------------------------------------------------

class OcgCoreWasmAdapter implements OcgCore {
  OcgCoreWasmAdapter._();

  static const List<String> _requiredModuleSymbols = <String>[
    '_create_duel',
    '_malloc',
    'HEAPU8',
    'ccall',
  ];

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

    await _waitFor(
      () => Module != null,
      timeoutMs: 5000,
      timeoutMessage:
          'ocgcore WASM bootstrap did not create a global Module object. '
          '${_moduleDiagnostics()}',
    );

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      final missing = _missingRequiredModuleSymbols();
      if (missing.isEmpty) {
        w._ready = true;
        return w;
      }

      final pluginStatus = _ocgcorePluginStatus?.dartify()?.toString();
      final runtimeFinished =
          pluginStatus == 'runtime_initialized' ||
          (pluginStatus?.startsWith('runtime_abort:') ?? false) ||
          (pluginStatus?.startsWith('inject_failed:') ?? false) ||
          (pluginStatus?.startsWith('unhandled_rejection:') ?? false);
      if (runtimeFinished) {
        throw StateError(
          'ocgcore WASM runtime initialized without required exports: '
          '${missing.join(', ')}. ${_moduleDiagnostics()}',
        );
      }

      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'Timed out waiting for ocgcore WASM exports: '
          '${missing.join(', ')}. ${_moduleDiagnostics()}',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<void> _waitFor(
    bool Function() predicate, {
    int timeoutMs = 30000,
    String? timeoutMessage,
  }) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          timeoutMessage ?? 'Timed out waiting for ocgcore WASM runtime.',
        );
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static List<String> _missingRequiredModuleSymbols() {
    final module = Module;
    if (module == null) return List<String>.from(_requiredModuleSymbols);
    return _requiredModuleSymbols
        .where((symbol) {
          try {
            return module[symbol] == null;
          } catch (_) {
            return true;
          }
        })
        .toList(growable: false);
  }

  static String _moduleDiagnostics() {
    final module = Module;
    final pluginStatus =
        _ocgcorePluginStatus?.dartify()?.toString() ?? '<unset>';
    final lastError = _ocgcoreLastError?.dartify()?.toString() ?? '<none>';
    final exportKeys = _dartifiedExportKeys();
    final presentSymbols = <String>[];
    if (module != null) {
      for (final symbol in _requiredModuleSymbols) {
        try {
          if (module[symbol] != null) {
            presentSymbols.add(symbol);
          }
        } catch (_) {
          // Best-effort diagnostics only.
        }
      }
    }
    return 'pluginStatus=$pluginStatus; '
        'modulePresent=${module != null}; '
        'presentSymbols=${presentSymbols.isEmpty ? '<none>' : presentSymbols.join(',')}; '
        'exportKeys=${exportKeys.isEmpty ? '<unset>' : exportKeys.join(',')}; '
        'lastError=$lastError';
  }

  static List<String> _dartifiedExportKeys() {
    final value = _ocgcoreWasmExportKeys?.dartify();
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
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
      final ret = queryCardC(
        pduel,
        playerid,
        location,
        sequence,
        queryFlag,
        buf,
        useCache,
      );
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
      final ret = queryFieldCardC(
        pduel,
        playerid,
        location,
        queryFlag,
        buf,
        useCache,
      );
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
    if (data.length > _responseBufferSize) {
      throw RangeError(
        'setResponseb received ${data.length} bytes, '
        'but ocgcore expects at most $_responseBufferSize.',
      );
    }
    final buf = wasmMalloc(_responseBufferSize);
    try {
      _wasmWriteBytes(
        buf,
        Uint8List(_responseBufferSize)..setRange(0, data.length, data),
      );
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
      _clearCallback(_CallbackSlot.scriptReader);
      setScriptReaderCC(0.toJS);
      return;
    }
    // wasm 侧按 'ppp' 签名回调，传入的是裸 i32 指针，
    // 不能用 JSString/JSAny 接收（DDC 会做参数类型检查直接抛 TypeError）。
    final callback = (int scriptNamePtr, int lenPtr) {
      final name = utf8ToString(scriptNamePtr).toDart;
      final bytes = _scriptCache[name];
      setValue(lenPtr.toJS, (bytes?.length ?? 0).toJS, 'i32'.toJS);
      if (bytes == null) {
        return 0;
      }
      final ptr = wasmMalloc(bytes.length);
      _wasmWriteBytes(ptr, bytes);
      return ptr;
    }.toJS;
    _setCallback(_CallbackSlot.scriptReader, callback, 'ppp');
  }

  @override
  void setCardReader(CardReader? f) {
    _cardReader = f;
    if (f == null) {
      _clearCallback(_CallbackSlot.cardReader);
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
    _setCallback(_CallbackSlot.cardReader, callback, 'iii');
  }

  void _fillCardData(int dataPtr, CardData cardData) {
    setValue((dataPtr + 0).toJS, cardData.code.toJS, 'i32'.toJS);
    setValue((dataPtr + 4).toJS, cardData.alias.toJS, 'i32'.toJS);
    for (var i = 0; i < cardData.setcode.length && i < 16; i++) {
      setValue(
        (dataPtr + 8 + i * 2).toJS,
        cardData.setcode[i].toJS,
        'i16'.toJS,
      );
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

  /// Wasm function-table indexes of the currently registered callbacks,
  /// keyed by callback slot so stale entries can be freed with
  /// `Module.removeFunction`.
  final Map<_CallbackSlot, int> _callbackPtrs = {};

  /// Registers [callback] in the wasm indirect function table and passes the
  /// resulting table index to the corresponding ocgcore setter.
  ///
  /// `Module._set_*` are raw wasm exports, so passing a JS function object
  /// directly would store garbage in the native function pointer. Emscripten
  /// `addFunction` wraps the JS function with the correct signature.
  void _setCallback(_CallbackSlot slot, JSAny callback, String sig) {
    final ptr = addFunctionCC(callback, sig.toJS);
    _clearCallback(slot);
    _callbackPtrs[slot] = ptr;
    switch (slot) {
      case _CallbackSlot.scriptReader:
        setScriptReaderCC(ptr.toJS);
      case _CallbackSlot.cardReader:
        setCardReaderCC(ptr.toJS);
      case _CallbackSlot.messageHandler:
        setMessageHandlerCC(ptr.toJS);
    }
  }

  void _clearCallback(_CallbackSlot slot) {
    final ptr = _callbackPtrs.remove(slot);
    if (ptr != null) {
      removeFunctionCC(ptr);
    }
  }

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
      _clearCallback(_CallbackSlot.messageHandler);
      setMessageHandlerCC(0.toJS);
      return;
    }
    final callback = (int pduel, int msgType) {
      f(pduel, msgType);
      return OPERATION_SUCCESS;
    }.toJS;
    _setCallback(_CallbackSlot.messageHandler, callback, 'iii');
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

/// Identifies the ocgcore callback slots so their wasm function-table
/// entries can be tracked and freed.
enum _CallbackSlot { scriptReader, cardReader, messageHandler }
