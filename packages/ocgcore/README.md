• 结论如下。

createOcgCore() 在 web 端初始化失败，根因不是 Lua 脚本资产，也不是 Flutter 注入时机，而是 packages/ocgcore/web/libs/libocgcore.wasm 本身导出符号不对。

我实际排到的结果：

- JS glue 能成功注入，Module 存在。
- runtime 能跑起来，插件状态到过 runtime_initialized。
- 之前 HEAPU8 没挂到 Module 上，这个我已确认属于 JS 暴露层问题，不是主因。
- 真正致命的是 wasm 导出表里没有 createOcgCore() 需要的核心符号。

当前 wasm 实际导出只有这些：

- memory
- __wasm_call_ctors
- __indirect_function_table
- _emscripten_stack_restore
- _emscripten_stack_alloc
- emscripten_stack_get_current

但 packages/ocgcore/lib/src/ocgcore_adapter.js.dart 依赖至少这些：

- Module._create_duel
- Module._malloc
- Module.HEAPU8
- Module.ccall

其中：

- ccall 来自 JS glue，本身有。
- HEAPU8 可以在 JS 层补。
- 但 _create_duel、_malloc 根本不在 wasm 导出表里，这会导致 createOcgCore() 无法完成初始化。

所以最终判断是：

- 当前 packages/ocgcore/web/libs/libocgcore.wasm
  不是一份可供现有 Dart 适配器使用的正确 web 构建产物。

- 需要重新用 Emscripten 编译 vendor/ocgcore，并显式导出 ocgcore API 与 malloc/free，替换现有 libocgcore.js 和 libocgcore.wasm。

顺带记录两个次要现象：

- flutter test -d chrome integration_test/... 在当前 Flutter 工具链下不支持 web integration test。
- app 里还有一个无关的 deck 资源 404：ygo_deck_mycard 的某个 .ydk 取不到，但这不是 ocgcore 初始化失败主因。

---

## 已处理（2026-08-10）

按上面结论完成修复，createOcgCore() 现在可以在 web 端正常初始化。

### 1. 重建 libocgcore.wasm

构建链为通用包 `packages/wasm_bridge`（Emscripten 6.0.6），配置见 `packages/ocgcore/wasm_bridge.yaml`，从仓库根的 `vendor/ocgcore` + `vendor/lua` 重建 `web/libs/libocgcore.{js,wasm}`。在 `packages/ocgcore` 下执行 `dart run wasm_bridge build` 即可。关键点：

- 导出全部 22 个 C API 符号（`_create_duel`/`_create_duel_v2`/`_malloc`/`_free`/`_start_duel`/`_process`/`_get_message`/`_end_duel`/`_set_script_reader`/`_set_card_reader`/`_set_message_handler`/`_preload_script` 等）以及 JS runtime 方法（`ccall`、`HEAPU8`、`addFunction`/`removeFunction`、`getValue`/`setValue`、`UTF8ToString`、`stringToUTF8OnStack`）。
- lua 源用 `-x c++` 编译：lua.h 没有 extern "C" 保护，否则 ocgcore（C++）引用的 mangled lua_* 符号链接不上。
- `-fwasm-exceptions`：lua 按 C++ 编译后错误处理走 C++ 异常（LUAI_THROW/LUAI_TRY），必须开异常支持。
- `--no-entry`、`INITIAL_MEMORY=64MB` + `ALLOW_MEMORY_GROWTH`、`ALLOW_TABLE_GROWTH`（addFunction 需要函数表可增长）、`ENVIRONMENT=web,node`。

重建后 wasm 从约 27KB 变为约 895KB（旧产物基本没有打进任何 ocgcore 代码）。

### 2. 修复适配器回调传参 bug

`lib/src/ocgcore_adapter.js.dart` 原来把 JS 回调函数对象直接传给 `Module._set_script_reader` 等 raw wasm export。wasm 导出函数只接受数字（间接函数表索引），直接传 JS 函数会存进一个非法的函数指针。现改为通过 `Module.addFunction(cb, sig)` 先注册拿到 table index 再传给 setter，替换时用 `removeFunction` 释放。签名：script_reader 为 `'ppp'`，card_reader/message_handler 为 `'iii'`。

### 2.5 生成代码接管手写胶水（2026-08-10 更新）

构建链 `packages/wasm_bridge` 扩展为三能力：编译 wasm/js、生成 Flutter web 插件、生成 Dart 接口。ocgcore 的手写胶水已切换为由 `wasm_bridge.yaml` 的 `plugin:`/`bindings:` 段生成（`dart run wasm_bridge gen`，或 `build` 自动触发）：

- `lib/src/ocgcore_web_plugin.dart`：plugin 与 bindings 合并生成的单文件——wasm/js 注入插件类 + `@JS('Module._xxx')` 接口声明。适配器 `ocgcore_adapter.js.dart` import 这一个文件；改 C API 时只需改 `wasm_bridge.yaml` 的 `bindings.functions` 签名表。

### 3. 验证结果

- Node 冒烟：符号齐全，HEAPU8 正常，`create_duel_v2 → start_duel → process → get_message → end_duel` 全流程跑通。
- 模拟 Flutter web 插件注入流程（node vm，按 `ocgcore_web_plugin.dart` 的方式注入并初始化）：`runtime_initialized`、preload_script 触发 script_reader 回调成功。
- 真实无头 Chrome（HTTP 加载 libocgcore.js/wasm）：全部导出检查通过，addFunction 回调被 wasm 侧正确回调，完整 duel 流程 PASS。
- `flutter analyze`（packages/ocgcore）：无 error（仅存量 info 级提示）。

注意：环境没有 emsdk 时在 `packages/ocgcore` 下执行 `dart run wasm_bridge install` 即可自动安装（版本由配置里的 `emsdk_version: 6.0.6` 钉住，装到 `~/.cache/wasm_bridge/emsdk`，重启不丢）。
