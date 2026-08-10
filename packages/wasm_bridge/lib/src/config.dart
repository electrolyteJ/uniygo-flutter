import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Error thrown for invalid config or a failed build step.
class WasmBridgeException implements Exception {
  WasmBridgeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A group of C/C++ source files sharing compile settings.
class SourceGroup {
  SourceGroup({
    required this.path,
    this.language,
    this.recursive = false,
    this.exclude = const [],
    this.extensions = const ['.c', '.cc', '.cpp', '.cxx'],
  });

  /// Directory containing the sources (absolute, resolved).
  final String path;

  /// Force compilation as `c` or `c++` regardless of file extension.
  /// Needed e.g. for lua, whose headers lack `extern "C"` guards when the
  /// library is consumed from C++.
  final String? language;

  final bool recursive;

  /// File basenames to skip (e.g. standalone interpreter entry points).
  final List<String> exclude;

  final List<String> extensions;

  /// Lists the source files of this group, sorted for reproducible builds.
  List<File> resolveFiles() {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      throw WasmBridgeException('sources 目录不存在: $path');
    }
    final files = dir
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((f) =>
            extensions.contains(p.extension(f.path)) &&
            !exclude.contains(p.basename(f.path)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw WasmBridgeException('sources 目录内没有匹配的源文件: $path');
    }
    return files;
  }
}

/// Emscripten link settings.
class LinkOptions {
  const LinkOptions({
    this.noEntry = false,
    this.exceptions = false,
    this.initialMemory,
    this.allowMemoryGrowth = true,
    this.allowTableGrowth = false,
    this.environment = const ['web', 'node'],
    this.exportedFunctions = const [],
    this.exportedRuntimeMethods = const [],
    this.extraFlags = const [],
  });

  final bool noEntry;
  final bool exceptions;
  final int? initialMemory;
  final bool allowMemoryGrowth;
  final bool allowTableGrowth;
  final List<String> environment;
  final List<String> exportedFunctions;
  final List<String> exportedRuntimeMethods;

  /// Raw extra flags appended to the em++ invocation (escape hatch).
  final List<String> extraFlags;
}

/// 生成 Flutter web 插件（动态注入 wasm/js）的配置，对应 `plugin:` 段。
class PluginGenConfig {
  const PluginGenConfig({
    required this.package,
    required this.className,
    required this.output,
    required this.jsAsset,
    required this.wasmAsset,
    required this.debugPrefix,
  });

  /// Flutter 包名，用于拼资产路径 `packages/<package>/...`。
  final String package;

  /// 生成的插件类名（须与 pubspec 的 pluginClass 一致）。
  final String className;

  /// 生成的 Dart 文件路径（绝对路径，已解析）。
  final String output;

  /// 资产 key，如 `packages/ocgcore/web/libs/libocgcore.js`；
  /// 对应 HTTP URL 为 `assets/<key>`。
  final String jsAsset;
  final String wasmAsset;

  /// window 调试全局变量前缀：`__<debugPrefix>PluginStatus` 等。
  final String debugPrefix;
}

/// 单个导出函数的 Dart 接口签名。
class FunctionSignature {
  const FunctionSignature({
    required this.jsName,
    required this.dartName,
    this.params = const {},
    this.returns = 'void',
  });

  /// JS 侧名称（不含 `Module.` 前缀），如 `_create_duel`。
  final String jsName;

  /// 生成的 Dart 顶层函数名，如 `createDuelC`。
  final String dartName;

  /// 有序参数表：参数名 -> Dart 类型（int/double/JSAny/JSString/...）。
  final Map<String, String> params;

  /// 返回值 Dart 类型。
  final String returns;
}

/// 生成 dart:js_interop 接口声明的配置，对应 `bindings:` 段。
class BindingsGenConfig {
  const BindingsGenConfig({
    required this.output,
    this.functions = const [],
  });

  /// 生成的 Dart 文件路径（绝对路径，已解析）。
  final String output;

  /// C API 签名表；`link.exported_functions` 中未在此声明的函数会告警。
  final List<FunctionSignature> functions;
}

/// Parsed `wasm_bridge.yaml`.
class WasmBridgeConfig {
  WasmBridgeConfig({
    required this.name,
    required this.configDir,
    required this.outputJs,
    required this.sources,
    this.emsdkDir,
    this.emsdkVersion,
    this.includeDirs = const [],
    this.defines = const {},
    this.compileFlags = const ['-O2'],
    this.link = const LinkOptions(),
    this.plugin,
    this.bindings,
  });

  final String name;

  /// Directory containing the config file; relative paths resolve from here.
  final String configDir;

  /// Output .js path (absolute). The .wasm is emitted next to it.
  final String outputJs;
  final List<SourceGroup> sources;
  final String? emsdkDir;

  /// emsdk 工具链版本（如 `6.0.6`），供 `wasm_bridge install` 使用。
  /// 不设置则安装 `latest`。
  final String? emsdkVersion;
  final List<String> includeDirs;
  final Map<String, String?> defines;
  final List<String> compileFlags;
  final LinkOptions link;

  /// `plugin:` 段，存在时 `gen` 会生成 Flutter web 插件注入代码。
  final PluginGenConfig? plugin;

  /// `bindings:` 段，存在时 `gen` 会生成 dart:js_interop 接口声明。
  final BindingsGenConfig? bindings;

  String get outputWasm => p.setExtension(outputJs, '.wasm');

  static WasmBridgeConfig load(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw WasmBridgeException('配置文件不存在: $configPath');
    }
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) {
      throw WasmBridgeException('配置文件格式错误: 顶层必须是 map');
    }
    final configDir = p.absolute(p.dirname(configPath));
    String resolve(String path) =>
        p.normalize(p.isAbsolute(path) ? path : p.join(configDir, path));

    final name = doc['name'];
    final output = doc['output'];
    if (name is! String || name.isEmpty) {
      throw WasmBridgeException('缺少配置项: name');
    }
    if (output is! String || !output.endsWith('.js')) {
      throw WasmBridgeException('缺少配置项: output（需为 .js 路径）');
    }

    final sourcesNode = doc['sources'];
    if (sourcesNode is! YamlList || sourcesNode.isEmpty) {
      throw WasmBridgeException('缺少配置项: sources（非空列表）');
    }
    final sources = <SourceGroup>[];
    for (final node in sourcesNode) {
      if (node is String) {
        sources.add(SourceGroup(path: resolve(node)));
        continue;
      }
      if (node is! YamlMap || node['path'] is! String) {
        throw WasmBridgeException('sources 列表项必须是路径字符串或含 path 的 map');
      }
      final language = node['language'];
      if (language != null && language != 'c' && language != 'c++') {
        throw WasmBridgeException('sources.language 只支持 c 或 c++: $language');
      }
      sources.add(SourceGroup(
        path: resolve(node['path'] as String),
        language: language as String?,
        recursive: node['recursive'] == true,
        exclude: _stringList(node['exclude'], 'sources.exclude'),
        extensions: node['extensions'] == null
            ? const ['.c', '.cc', '.cpp', '.cxx']
            : _stringList(node['extensions'], 'sources.extensions'),
      ));
    }

    final defines = <String, String?>{};
    final definesNode = doc['defines'];
    if (definesNode is YamlMap) {
      for (final entry in definesNode.entries) {
        defines['${entry.key}'] = entry.value?.toString();
      }
    } else if (definesNode != null) {
      throw WasmBridgeException('defines 必须是 map');
    }

    final linkNode = doc['link'];
    final LinkOptions link;
    if (linkNode == null) {
      link = const LinkOptions();
    } else if (linkNode is YamlMap) {
      link = LinkOptions(
        noEntry: linkNode['no_entry'] == true,
        exceptions: linkNode['exceptions'] == true,
        initialMemory: _intOrNull(linkNode['initial_memory']),
        allowMemoryGrowth: linkNode['allow_memory_growth'] != false,
        allowTableGrowth: linkNode['allow_table_growth'] == true,
        environment: linkNode['environment'] == null
            ? const ['web', 'node']
            : _stringList(linkNode['environment'], 'link.environment'),
        exportedFunctions: _stringList(
            linkNode['exported_functions'], 'link.exported_functions'),
        exportedRuntimeMethods: _stringList(
            linkNode['exported_runtime_methods'],
            'link.exported_runtime_methods'),
        extraFlags: _stringList(linkNode['extra_flags'], 'link.extra_flags'),
      );
    } else {
      throw WasmBridgeException('link 必须是 map');
    }

    // bindings: 段——生成 dart:js_interop 接口声明。
    // output 必填；与 plugin.output 相同时两部分合并生成单文件。
    BindingsGenConfig? bindings;
    final bindingsNode = doc['bindings'];
    if (bindingsNode != null) {
      if (bindingsNode is! YamlMap) {
        throw WasmBridgeException('bindings 必须是 map');
      }
      final functions = <FunctionSignature>[];
      final functionsNode = bindingsNode['functions'];
      if (functionsNode is YamlMap) {
        for (final entry in functionsNode.entries) {
          functions.add(_parseFunctionSignature(entry));
        }
      } else if (functionsNode != null) {
        throw WasmBridgeException('bindings.functions 必须是 map');
      }
      final bindingsOutput = bindingsNode['output'];
      if (bindingsOutput is! String || bindingsOutput.isEmpty) {
        throw WasmBridgeException(
            '缺少配置项: bindings.output（生成的 Dart 文件路径）');
      }
      bindings = BindingsGenConfig(
        output: resolve(bindingsOutput),
        functions: functions,
      );
    }

    // plugin: 段——生成 Flutter web 插件（动态注入 wasm/js）。
    // output 缺省时跟随 bindings.output（合并生成单文件），二者都没有则报错；
    // package/class_name 缺省时从同目录 pubspec.yaml 推导：package 取
    // pubspec name，class_name 取 flutter.plugin.platforms.web.pluginClass。
    final pubspec = _PubspecInfo.load(configDir);
    PluginGenConfig? plugin;
    final pluginNode = doc['plugin'];
    if (pluginNode != null && pluginNode is! YamlMap) {
      throw WasmBridgeException('plugin 必须是 map');
    }
    final pluginMap = pluginNode as YamlMap?;
    if (pluginMap != null) {
      final package = (pluginMap['package'] as String?) ?? pubspec.name;
      if (package == null || package.isEmpty) {
        throw WasmBridgeException(
            '缺少配置项: plugin.package（Flutter 包名），且 pubspec.yaml 中没有 name 可供推导');
      }
      // bindings.output 已是绝对路径，resolve 会原样返回。
      final pluginOutput =
          (pluginMap['output'] as String?) ?? bindings?.output;
      if (pluginOutput == null || pluginOutput.isEmpty) {
        throw WasmBridgeException(
            '缺少配置项: plugin.output（生成的 Dart 文件路径），且没有 bindings.output 可供跟随');
      }
      final jsRelative =
          p.isAbsolute(output) ? p.relative(output, from: configDir) : output;
      final wasmRelative = p.setExtension(jsRelative, '.wasm');
      final className = (pluginMap['class_name'] as String?) ??
          pubspec.webPluginClass ??
          '${_pascalCase(package)}WebPlugin';
      plugin = PluginGenConfig(
        package: package,
        className: className,
        output: resolve(pluginOutput),
        jsAsset: 'packages/$package/${jsRelative.replaceAll(r'\', '/')}',
        wasmAsset: 'packages/$package/${wasmRelative.replaceAll(r'\', '/')}',
        debugPrefix: (pluginMap['debug_prefix'] as String?) ?? package,
      );
    }

    return WasmBridgeConfig(
      name: name,
      configDir: configDir,
      outputJs: resolve(output),
      sources: sources,
      emsdkDir: doc['emsdk'] is String ? resolve(doc['emsdk'] as String) : null,
      emsdkVersion:
          doc['emsdk_version'] is String ? doc['emsdk_version'] as String : null,
      includeDirs:
          _stringList(doc['include_dirs'], 'include_dirs').map(resolve).toList(),
      defines: defines,
      compileFlags: doc['compile_flags'] == null
          ? const ['-O2']
          : _stringList(doc['compile_flags'], 'compile_flags'),
      link: link,
      plugin: plugin,
      bindings: bindings,
    );
  }

  static FunctionSignature _parseFunctionSignature(MapEntry entry) {
    final jsName = '${entry.key}';
    if (entry.value is! YamlMap) {
      throw WasmBridgeException('bindings.functions.$jsName 必须是 map');
    }
    final node = entry.value as YamlMap;
    final params = <String, String>{};
    final paramsNode = node['params'];
    if (paramsNode is YamlMap) {
      for (final param in paramsNode.entries) {
        final type = '${param.value}';
        _checkBindingType(type, 'bindings.functions.$jsName.params');
        params['${param.key}'] = type;
      }
    } else if (paramsNode != null) {
      throw WasmBridgeException('bindings.functions.$jsName.params 必须是 map');
    }
    final returns = '${node['returns'] ?? 'void'}';
    _checkBindingType(returns, 'bindings.functions.$jsName.returns');
    return FunctionSignature(
      jsName: jsName,
      dartName: (node['dart_name'] as String?) ?? _defaultDartName(jsName),
      params: params,
      returns: returns,
    );
  }

  /// `_create_duel` -> `createDuelC`。
  static String _defaultDartName(String jsName) {
    final stripped = jsName.replaceFirst(RegExp('^_+'), '');
    final camel = stripped.replaceAllMapped(
        RegExp('_([a-zA-Z0-9])'), (m) => m.group(1)!.toUpperCase());
    return '${camel}C';
  }

  static void _checkBindingType(String type, String field) {
    const allowed = {
      'void',
      'bool',
      'int',
      'double',
      'num',
      'JSAny',
      'JSAny?',
      'JSString',
      'JSNumber',
      'JSObject',
      'JSObject?',
      'JSFunction',
    };
    if (!allowed.contains(type)) {
      throw WasmBridgeException('$field 不支持的类型: $type（支持: ${allowed.join(', ')}）');
    }
  }

  static String _pascalCase(String name) => name
      .split('_')
      .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
      .join();

  static List<String> _stringList(Object? node, String field) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw WasmBridgeException('$field 必须是字符串列表');
    }
    return node.map((e) => '$e').toList();
  }

  static int? _intOrNull(Object? node) {
    if (node == null) return null;
    if (node is int) return node;
    final value = int.tryParse('$node');
    if (value == null) {
      throw WasmBridgeException('link.initial_memory 必须是整数: $node');
    }
    return value;
  }
}

/// 从包根目录的 pubspec.yaml 读取的信息，用于推导 plugin 段默认值。
class _PubspecInfo {
  _PubspecInfo({this.name, this.webPluginClass});

  /// pubspec 的 `name`。
  final String? name;

  /// `flutter.plugin.platforms.web.pluginClass`。
  final String? webPluginClass;

  static _PubspecInfo load(String packageDir) {
    final file = File(p.join(packageDir, 'pubspec.yaml'));
    if (!file.existsSync()) return _PubspecInfo();
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return _PubspecInfo();
    final flutter = doc['flutter'];
    final plugin = flutter is YamlMap ? flutter['plugin'] : null;
    final platforms = plugin is YamlMap ? plugin['platforms'] : null;
    final web = platforms is YamlMap ? platforms['web'] : null;
    return _PubspecInfo(
      name: doc['name'] as String?,
      webPluginClass: web is YamlMap ? web['pluginClass'] as String? : null,
    );
  }
}
