# wasm_bridge

C/C++ 到 Flutter web 的桥接工具。用一个 `wasm_bridge.yaml` 描述源码、编译选项、导出符号和 Dart 接口签名，`wasm_bridge` 提供三个能力：

1. **编译**：调用 Emscripten（em++）把 C/C++ 编译成 `.js` glue + `.wasm`，构建后校验产物里是否真的包含配置的导出符号。
2. **生成 Flutter web 插件**：生成一个 registerWith 插件类，通过 rootBundle 加载 wasm/js 资产、把 WASM 内联为 base64 Data URI、注入单个 `<script>` 标签，并把 wasmExports/HEAP 视图补到 `Module` 全局对象上。
3. **生成 Dart 接口**：按 `bindings.functions` 签名表生成 `dart:js_interop` 的 `@JS('Module._xxx') external ...` 声明文件，业务适配器直接 import 使用。

最初为 `packages/ocgcore` 的 `libocgcore.wasm` 重建而做，已抽成通用包，任何 Flutter web 插件都可以用同样的方式维护 wasm 产物。

## 前置条件

需要一份已激活的 emsdk。**环境里没有也不用手动装**——运行：

```bash
dart run wasm_bridge install
```

工具会自动把 emsdk 浅克隆到持久缓存目录（`~/.cache/wasm_bridge/emsdk`，遵循 XDG，不用 `/tmp`，重启不丢）并执行 `install + activate`。版本由配置项 `emsdk_version` 决定（未配置则 `latest`），钉版本可以保证团队/CI 构建可复现。下载量有数 GB，需联网。

已有 emsdk 的话无需 install，查找顺序：`EMSDK_DIR` 环境变量 -> 配置项 `emsdk` -> `~/.cache/wasm_bridge/emsdk` -> `/tmp/emsdk` -> `~/emsdk` -> PATH。用 `dart run wasm_bridge doctor` 确认工具链可用。

## 使用

1. 在包的 `pubspec.yaml` 里加 dev 依赖：

   ```yaml
   dev_dependencies:
     wasm_bridge:
       path: ../wasm_bridge
   ```

2. 在包根目录写 `wasm_bridge.yaml`（完整注释示例见 [example/wasm_bridge.yaml](example/wasm_bridge.yaml)）：

   ```yaml
   name: libfoo
   output: web/libs/libfoo.js
   sources:
     - path: ../../vendor/foo
       exclude: [main.c]
   include_dirs: [../../vendor/foo/include]
   compile_flags: [-O3]
   link:
     no_entry: true
     allow_memory_growth: true
     exported_functions: [_malloc, _free, _foo_create]
     exported_runtime_methods: [ccall, HEAPU8]
   ```

3. 构建：

   ```bash
   dart run wasm_bridge build            # 编译 + 校验导出符号
   dart run wasm_bridge verify           # 只校验已有产物
   dart run wasm_bridge gen              # 生成 web 插件注入代码 + dart 接口声明
   dart run wasm_bridge doctor           # 检查 em++ 是否可用
   dart run wasm_bridge install          # 环境没有 emsdk 时自动安装
   ```

   `build` 成功后若配置了 `plugin:`/`bindings:` 段会自动执行 `gen`。

## 代码生成

### plugin: 生成 Flutter web 插件

```yaml
# output 必填；package/class_name 可省略，自动从 pubspec.yaml 推导：
#   package    <- pubspec 的 name
#   class_name <- flutter.plugin.platforms.web.pluginClass
plugin:
  package: ocgcore                     # 包名（资产路径 packages/<package>/...）
  class_name: OcgCoreWebPlugin         # 须与 pubspec 的 pluginClass 一致
  output: lib/src/ocgcore_web_plugin.dart  # 必填
```

生成的插件解决两个 Flutter web 的通用问题：dev server 不提供包静态资产的 HTTP URL，以及动态注入脚本里 `document.currentScript` 为 null 导致 Emscripten `locateFile` 失效。运行时状态写到 `window.__<package>PluginStatus`，便于无头浏览器排查。Emscripten 升级后若 glue 结构变化导致补丁锚点失配，状态会置为 `exports_anchor_missing`（可用 `plugin.exports_anchor` 配置新锚点）。

### bindings: 生成 Dart 接口

```yaml
bindings:
  output: lib/src/ocgcore_bindings.web.g.dart  # 必填
  functions:
    _create_duel:                      # 默认 Dart 名：createDuelC（驼峰 + C 后缀）
      params: {seed: int}
      returns: int
    _malloc:
      dart_name: wasmMalloc            # 可覆盖默认命名
      params: {size: int}
      returns: int
```

- 参数/返回值类型支持 `void/int/double/bool/num/JSAny/JSString/JSNumber/JSObject/JSFunction` 等 `dart:js_interop` 类型。
- `link.exported_runtime_methods` 中已知签名的方法（`getValue`/`setValue`/`UTF8ToString`/`stringToUTF8OnStack`/`addFunction`/`removeFunction`）会自动生成类型化声明；`HEAP*` 生成 `heapU8` 这类 getter；其余跳过并在文件里注释说明。
- `link.exported_functions` 里导出了但没在 `bindings.functions` 声明签名的函数，`gen` 会告警——导出表和接口表由此保持同步。

### 合并输出

`plugin.output` 与 `bindings.output` 指向同一路径时，两部分会合并生成到**同一个文件**（统一 import 块 + 绑定声明 + 插件类），适配器 import 这一个文件即可。ocgcore 就是这么用的：两段 output 都写 `lib/src/ocgcore_web_plugin.dart`，`plugin:` 段只写 output（package/class_name 从 pubspec 推导），`bindings:` 配 output + `functions:` 签名表。

## 配置要点

- `sources[].language: c++`：强制按 C++ 编译。典型场景是 lua——lua.h 没有 `extern "C"` 保护，C++ 代码链接 C 编译出的 lua 目标文件会找不到符号。
- `link.exceptions: true`：加 `-fwasm-exceptions`。lua 按 C++ 编译后错误处理走 C++ 异常，必须开启。
- `link.allow_table_growth: true`：Dart/JS 侧要用 `Module.addFunction` 把 JS 回调注册成函数表索引时必须。
- `link.exported_functions`：带前导下划线（`_create_duel` 这种）。构建后 `verify` 会逐个在 JS glue 里检查符号存在，避免“wasm 里没打进代码但构建看似成功”的问题。
- 所有相对路径都相对配置文件所在目录解析。

## 在 ocgcore 中的落地

`packages/ocgcore/wasm_bridge.yaml` 是本工具的实际用例。
