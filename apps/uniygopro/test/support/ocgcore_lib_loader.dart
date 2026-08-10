/// 按平台条件导出 ocgcore 动态库加载器。
///
/// - Web（chrome）：返回 null，走 `libocgcore.js/wasm` 适配器。
/// - VM（flutter_tester / macOS）：显式 `DynamicLibrary.open`，因为
///   flutter_tester 环境下 ocgcore 的默认查找路径找不到 dylib。
export 'ocgcore_lib_loader_stub.dart'
    if (dart.library.io) 'ocgcore_lib_loader_io.dart';
