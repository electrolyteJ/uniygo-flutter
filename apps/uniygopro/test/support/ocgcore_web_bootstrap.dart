/// 测试环境下确保 ocgcore 的 WASM 脚本被注入。
///
/// 真实 App 由 Web 插件注册器（dart_plugin_registrant）调用
/// `OcgCoreWebPlugin.registerWith` 注入 `libocgcore.js`；而
/// `flutter test --platform chrome` 不会注册 Web 插件，需要测试侧
/// 手动触发。VM 平台为空操作。
export 'ocgcore_web_bootstrap_stub.dart'
    if (dart.library.js_interop) 'ocgcore_web_bootstrap_web.dart';
