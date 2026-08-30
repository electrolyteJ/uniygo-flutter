import 'package:applog/console.dart' as console;
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../ocgcore.dart';
import 'ocgcore_bindings_generated.dart';

const int _responseBufferSize = 512;
Future<OcgCore?> createOcgCore([Object? lib]) async {
  var adapter = OcgCoreNativeAdapter();
  adapter.initialize(lib);
  console.log('OcgCoreNativeAdapter initialized with lib: $lib');
  return adapter;
}
class OcgCoreNativeAdapter implements OcgCore {
  OcgCoreBindings? _bindings;
  static ScriptReader? _scriptReader;
  static CardReader? _cardReader;
  static final Map<String, Uint8List> _scriptCache = {};
  static final Map<int, CardData> _cardCache = {};

  bool get isInitialized => _bindings != null;

  ffi.DynamicLibrary loadOcgCore() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libocgcore.so');
    }
    if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libocgcore.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('ocgcore.dll');
    }
    if (Platform.isMacOS || Platform.isIOS) {
      try {
        return ffi.DynamicLibrary.open('libocgcore.dylib');
      } catch (_) {}
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  void initialize([Object? lib]) {
    if (_bindings != null) return;
    final ffiLib = (lib as ffi.DynamicLibrary?) ?? loadOcgCore();
    _bindings = OcgCoreBindings(ffiLib);
  }

  OcgCoreBindings get _b {
    final b = _bindings;
    if (b == null) {
      throw StateError(
        'OcgCoreNativeAdapter not initialized. Call initialize() first.',
      );
    }
    return b;
  }

  @override
  void setScriptReader(ScriptReader? f) {
    _scriptReader = f;
    if (f == null) {
      _b.set_script_reader(ffi.nullptr);
      return;
    }
    _b.set_script_reader(
      ffi.Pointer.fromFunction<_scriptReaderNative>(_onScriptReader),
    );
  }

  static ffi.Pointer<byte> _onScriptReader(
    ffi.Pointer<ffi.Char> scriptNamePtr,
    ffi.Pointer<ffi.Int> lenPtr,
  ) {
    final ffi.Pointer<Utf8> utf8Ptr = scriptNamePtr.cast();
    var scriptName = utf8Ptr.toDartString();
    if (scriptName.startsWith('./script/')) {
      scriptName = scriptName.substring('./script/'.length);
    }
    // print('_onScriptReader called with scriptName: $scriptName ${_scriptCache.containsKey(scriptName)}');
    if (_scriptCache.containsKey(scriptName)) {
      final result = _scriptCache[scriptName]!;
      lenPtr.value = result.length;
      // print('_onScriptReader called with scriptName: $scriptName, length: ${result.length}');
      final ptr = calloc<byte>(result.length);
      for (var i = 0; i < result.length; i++) {
        ptr[i] = result[i];
      }
      return ptr;
    }
    lenPtr.value = 0;
    return ffi.nullptr;
  }

  @override
  void setCardReader(CardReader? f) {
    _cardReader = f;
    if (f == null) {
      _b.set_card_reader(ffi.nullptr);
      return;
    }
    _b.set_card_reader(
      ffi.Pointer.fromFunction<_cardReaderNative>(_onCardReader, 0),
    );
  }

  static void _fillCardData(ffi.Pointer<card_data> data, CardData cardData) {
    data.ref.code = cardData.code;
    data.ref.alias = cardData.alias;
    for (var i = 0; i < cardData.setcode.length && i < 16; i++) {
      data.ref.setcode[i] = cardData.setcode[i];
    }
    data.ref.type = cardData.type;
    data.ref.level = cardData.level;
    data.ref.attribute = cardData.attribute;
    data.ref.race = cardData.race;
    data.ref.attack = cardData.attack;
    data.ref.defense = cardData.defense;
    data.ref.lscale = cardData.lscale;
    data.ref.rscale = cardData.rscale;
    data.ref.link_marker = cardData.linkMarker;
  }

  static int _onCardReader(int code, ffi.Pointer<card_data> data) {
    // print('_onCardReader called with code: $code ${_cardCache.containsKey(code)}');
    if (_cardCache.containsKey(code)) {
      _fillCardData(data, _cardCache[code]!);
      return OPERATION_SUCCESS;
    }
    return OPERATION_FAIL;
  }

  @override
  Future<void> preloadScriptAsync(String name) async {
    if (_scriptReader == null) {
      print(
        'preloadScriptAsync called but scriptReader is null for name: $name',
      );
      return;
    }
    if (_scriptCache.containsKey(name)) {
      return;
    }
    final start = DateTime.now();
    // print('preloadScriptAsync called with name: $name');
    final data = await _scriptReader!(name);
    // print('preloadScriptAsync called with name: $name ${data != null} in ${DateTime.now().difference(start).inMilliseconds} ms');
    if (data != null) {
      _scriptCache[name] = data;
    }
  }

  @override
  Future<void> preloadCardAsync(int code) async {
    if (_cardReader == null) {
      print('preloadCardAsync called but cardReader is null for code: $code');
      return;
    }
    if (_cardCache.containsKey(code)) {
      return;
    }
    final start = DateTime.now();
    // print('preloadCardAsync called with code: $code');
    final cardData = await _cardReader!(code);
    // print('preloadCardAsync called with code: $code ${cardData != null} in ${DateTime.now().difference(start).inMilliseconds} ms');
    if (cardData != null) {
      _cardCache[code] = cardData;
    }
  }

  static MessageHandler? _messageHandler;

  @override
  void setMessageHandler(MessageHandler? f) {
    _messageHandler = f;
    if (f == null) {
      _b.set_message_handler(ffi.nullptr);
      return;
    }
    _b.set_message_handler(
      ffi.Pointer.fromFunction<_messageHandlerNative>(_onMessageHandler, 0),
    );
  }

  static int _onMessageHandler(int pduel, int msgType) {
    final f = _messageHandler;
    if (f == null) return OPERATION_FAIL;
    f(pduel, msgType);
    return OPERATION_SUCCESS;
  }

  @override
  int createDuel(int seed) => _b.create_duel(seed);

  @override
  int createDuelV2(Uint32List seeds) {
    assert(seeds.length == 8, 'Seed sequence must have exactly 8 elements.');
    final ptr = calloc<ffi.Uint32>(8);
    try {
      for (var i = 0; i < 8; i++) {
        ptr[i] = seeds[i];
      }
      return _b.create_duel_v2(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void startDuel(int pduel, int options) => _b.start_duel(pduel, options);

  @override
  void endDuel(int pduel) => _b.end_duel(pduel);

  @override
  void setPlayerInfo(
    int pduel,
    int playerid,
    int lp,
    int startCount,
    int drawCount,
  ) {
    _b.set_player_info(pduel, playerid, lp, startCount, drawCount);
  }

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
    _b.new_card(pduel, code, owner, playerid, location, sequence, position);
  }

  @override
  void newTagCard(int pduel, int code, int owner, int location) {
    _b.new_tag_card(pduel, code, owner, location);
  }

  @override
  int process(int pduel) => _b.process(pduel);

  @override
  int getMessage(int pduel, Uint8List out) {
    final ptr = calloc<byte>(out.length);
    try {
      final ret = _b.get_message(pduel, ptr);
      if (ret > 0) {
        final copyLen = ret < out.length ? ret : out.length;
        for (var i = 0; i < copyLen; i++) {
          out[i] = ptr[i];
        }
      }
      return ret;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  String getLogMessage(int pduel) {
    final buf = calloc<byte>(1024);
    try {
      _b.get_log_message(pduel, buf.cast<ffi.Char>());
      final ffi.Pointer<Utf8> utf8Ptr = buf.cast();
      return utf8Ptr.toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  @override
  int queryFieldCount(int pduel, int playerid, int location) {
    return _b.query_field_count(pduel, playerid, location);
  }

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
    final ptr = calloc<byte>(out.length);
    try {
      final ret = _b.query_card(
        pduel,
        playerid,
        location,
        sequence,
        queryFlag,
        ptr,
        useCache,
      );
      if (ret > 0) {
        for (var i = 0; i < ret; i++) {
          out[i] = ptr[i];
        }
      }
      return ret;
    } finally {
      calloc.free(ptr);
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
    final ptr = calloc<byte>(out.length);
    try {
      final ret = _b.query_field_card(
        pduel,
        playerid,
        location,
        queryFlag,
        ptr,
        useCache,
      );
      if (ret > 0) {
        for (var i = 0; i < ret; i++) {
          out[i] = ptr[i];
        }
      }
      return ret;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  int queryFieldInfo(int pduel, Uint8List out) {
    final ptr = calloc<byte>(out.length);
    try {
      final ret = _b.query_field_info(pduel, ptr);
      if (ret > 0) {
        for (var i = 0; i < ret; i++) {
          out[i] = ptr[i];
        }
      }
      return ret;
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void setResponsei(int pduel, int value) => _b.set_responsei(pduel, value);

  @override
  void setResponseb(int pduel, Uint8List data) {
    if (data.length > _responseBufferSize) {
      throw RangeError(
        'setResponseb received ${data.length} bytes, '
        'but ocgcore expects at most $_responseBufferSize.',
      );
    }
    final ptr = calloc<byte>(_responseBufferSize);
    try {
      for (var i = 0; i < data.length; i++) {
        ptr[i] = data[i];
      }
      _b.set_responseb(pduel, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  int preloadScript(int pduel, String name) {
    final namePtr = name.toNativeUtf8(allocator: malloc);
    try {
      return _b.preload_script(pduel, namePtr.cast<ffi.Char>());
    } finally {
      malloc.free(namePtr);
    }
  }

  @override
  Uint8List? defaultScriptReader(String scriptName, List<int> len) {
    final namePtr = scriptName.toNativeUtf8(allocator: malloc);
    final lenPtr = calloc<ffi.Int>(1);
    try {
      final result = _b.default_script_reader(namePtr.cast<ffi.Char>(), lenPtr);
      if (result == ffi.nullptr) {
        len[0] = 0;
        return null;
      }
      len[0] = lenPtr.value;
      final data = Uint8List(len[0]);
      for (var i = 0; i < len[0]; i++) {
        data[i] = result[i];
      }
      malloc.free(result);
      return data;
    } finally {
      malloc.free(namePtr);
      calloc.free(lenPtr);
    }
  }
}

typedef _scriptReaderNative =
    ffi.Pointer<byte> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Int>);

typedef _cardReaderNative =
    ffi.Uint32 Function(ffi.Uint32, ffi.Pointer<card_data>);

typedef _messageHandlerNative = ffi.Uint32 Function(ffi.IntPtr, ffi.Uint32);
