/// Generic C/C++ -> WebAssembly/JS toolchain driven by a wasm_bridge.yaml
/// config file. Wraps Emscripten (em++), verifies the exported symbols of
/// the produced artifacts, and generates the Flutter web glue:
/// the script-injection plugin and dart:js_interop binding declarations.
library;

export 'src/config.dart';
export 'src/emscripten.dart';
export 'src/gen_bindings.dart';
export 'src/gen_plugin.dart';
export 'src/verify.dart';
