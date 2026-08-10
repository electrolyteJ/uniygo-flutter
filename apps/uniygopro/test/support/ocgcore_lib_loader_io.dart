import 'dart:ffi' as ffi;
import 'dart:io';

/// VM 平台：显式加载 ocgcore 动态库。
///
/// flutter_tester 环境默认的库查找（DynamicLibrary.open('libocgcore.dylib')）
/// 不可用，这里按仓库相对路径打开（cwd = apps/uniygopro）。找不到时返回
/// null，让 ocgcore 走默认查找（integration_test 真机环境可用）。
Object? loadOcgCoreLib() {
  if (Platform.isMacOS) {
    for (final path in const [
      '../../packages/ocgcore/macos/Frameworks/libocgcore.dylib',
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
    ]) {
      try {
        return ffi.DynamicLibrary.open(path);
      } catch (_) {}
    }
  }
  return null;
}
