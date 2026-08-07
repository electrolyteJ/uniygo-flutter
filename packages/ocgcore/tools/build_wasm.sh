#!/usr/bin/env bash
# ocgcore Web (WASM) 源码构建脚本。
#
# 与原生平台同一套源码:vendor/ocgcore + vendor/lua(经 src/lua_amalgam.cpp
# 以 C++ 编译,匹配 ocgcore 对 Lua API 的 C++ 符号引用)。
#
# 前置条件:安装并激活 emsdk
#   git clone https://github.com/emscripten-core/emsdk.git
#   ./emsdk install latest && ./emsdk activate latest
#   source ./emsdk/emsdk_env.sh
#
# 产物:web/libs/libocgcore.js + libocgcore.wasm
# 导出符号与 lib/ocgcore_wasm_adapter.dart 中的 @JS('Module._xxx') 一一对应,
# 改动 API 时请同步更新 EXPORTED_FUNCTIONS。

set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$PKG_DIR/web/libs"

if ! command -v emcc >/dev/null 2>&1; then
  echo "error: emcc 未找到,请先安装并激活 emsdk(source emsdk_env.sh)" >&2
  exit 1
fi

EXPORTED_FUNCTIONS='[
  "_set_script_reader", "_set_card_reader", "_set_message_handler",
  "_default_script_reader",
  "_create_duel", "_create_duel_v2", "_start_duel", "_end_duel",
  "_set_player_info", "_get_log_message", "_get_message", "_process",
  "_new_card", "_new_tag_card",
  "_query_card", "_query_field_count", "_query_field_card", "_query_field_info",
  "_set_responsei", "_set_responseb", "_preload_script",
  "_malloc", "_free"
]'

EXPORTED_RUNTIME_METHODS='[
  "ccall", "cwrap", "getValue", "setValue",
  "writeArrayToMemory", "stringToUTF8OnStack", "stackAlloc", "UTF8ToString",
  "addOnPreRun", "addOnPostRun",
  "HEAP8", "HEAPU8", "HEAP16", "HEAPU16",
  "HEAP32", "HEAPU32", "HEAPF32", "HEAPF64"
]'

emcc "$PKG_DIR"/vendor/ocgcore/*.cpp "$PKG_DIR/src/lua_amalgam.cpp" \
  -I"$PKG_DIR/vendor/ocgcore" -I"$PKG_DIR/vendor/lua" \
  -std=c++17 -O2 -fexceptions \
  -s WASM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORT_NAME=Module \
  -s EXPORTED_FUNCTIONS="$EXPORTED_FUNCTIONS" \
  -s EXPORTED_RUNTIME_METHODS="$EXPORTED_RUNTIME_METHODS" \
  -o "$OUT_DIR/libocgcore.js"

echo "done: $OUT_DIR/libocgcore.js / libocgcore.wasm"
