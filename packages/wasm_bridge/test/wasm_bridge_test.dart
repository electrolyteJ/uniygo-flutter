import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wasm_bridge/wasm_bridge.dart';

Directory makeSources(List<String> names) {
  final dir = Directory.systemTemp.createTempSync('wasm_bridge_test');
  for (final name in names) {
    File(p.join(dir.path, name)).writeAsStringSync('// $name');
  }
  return dir;
}

void main() {
  group('WasmBridgeConfig.load', () {
    late Directory tmp;
    late Directory src;
    late String configPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('wasm_bridge_cfg');
      src = makeSources(['b.cpp', 'a.c', 'main.c']);
      configPath = p.join(tmp.path, 'wasm_bridge.yaml');
      File(configPath).writeAsStringSync('''
name: libt
output: out/libt.js
sources:
  - path: ${src.path}
    exclude: [main.c]
include_dirs: [${src.path}]
defines:
  FOO: "1"
  BAR: null
compile_flags: [-O3]
link:
  no_entry: true
  exceptions: true
  initial_memory: 67108864
  allow_table_growth: true
  environment: [web, node]
  exported_functions: [_malloc, _t_create]
  exported_runtime_methods: [ccall, HEAPU8]
''');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
      src.deleteSync(recursive: true);
    });

    test('parses fields and resolves relative paths', () {
      final config = WasmBridgeConfig.load(configPath);
      expect(config.name, 'libt');
      expect(config.outputJs, p.join(tmp.path, 'out', 'libt.js'));
      expect(config.outputWasm, p.join(tmp.path, 'out', 'libt.wasm'));
      expect(config.sources.single.exclude, ['main.c']);
      expect(config.defines, {'FOO': '1', 'BAR': null});
      expect(config.link.noEntry, isTrue);
      expect(config.link.exceptions, isTrue);
      expect(config.link.initialMemory, 67108864);
      expect(config.link.allowMemoryGrowth, isTrue);
      expect(config.link.allowTableGrowth, isTrue);
      expect(config.link.exportedFunctions, ['_malloc', '_t_create']);
    });

    test('resolveFiles excludes entries and sorts', () {
      final config = WasmBridgeConfig.load(configPath);
      final files = config.sources.single.resolveFiles();
      expect(files.map((f) => p.basename(f.path)), ['a.c', 'b.cpp']);
    });

    test('rejects missing name', () {
      File(configPath).writeAsStringSync('output: out/x.js\nsources: [x]\n');
      expect(() => WasmBridgeConfig.load(configPath),
          throwsA(isA<WasmBridgeException>()));
    });

    test('rejects bad language', () {
      File(configPath).writeAsStringSync('''
name: t
output: out/x.js
sources:
  - path: ${src.path}
    language: rust
''');
      expect(() => WasmBridgeConfig.load(configPath),
          throwsA(isA<WasmBridgeException>()));
    });

    test('parses emsdk and emsdk_version', () {
      File(configPath).writeAsStringSync('''
name: t
output: out/x.js
sources: [${src.path}]
emsdk: ../emsdk
emsdk_version: "3.1.74"
''');
      final config = WasmBridgeConfig.load(configPath);
      expect(config.emsdkDir, p.normalize(p.join(tmp.path, '..', 'emsdk')));
      expect(config.emsdkVersion, '3.1.74');
    });

    test('parses plugin section with defaults', () {
      File(configPath).writeAsStringSync('''
name: libt
output: web/libs/libt.js
sources: [${src.path}]
plugin:
  package: my_pkg
  output: lib/src/my_pkg_web_plugin.dart
''');
      final config = WasmBridgeConfig.load(configPath);
      final plugin = config.plugin!;
      expect(plugin.package, 'my_pkg');
      expect(plugin.className, 'MyPkgWebPlugin');
      expect(plugin.jsAsset, 'packages/my_pkg/web/libs/libt.js');
      expect(plugin.wasmAsset, 'packages/my_pkg/web/libs/libt.wasm');
      expect(plugin.debugPrefix, 'my_pkg');
      expect(plugin.output,
          p.join(tmp.path, 'lib', 'src', 'my_pkg_web_plugin.dart'));
    });

    test('parses bindings signatures', () {
      File(configPath).writeAsStringSync('''
name: libt
output: out/libt.js
sources: [${src.path}]
bindings:
  output: lib/src/t_bindings.web.g.dart
  functions:
    _create_duel:
      params: {seed: int}
      returns: int
    _malloc:
      dart_name: wasmMalloc
      params: {size: int}
      returns: int
''');
      final config = WasmBridgeConfig.load(configPath);
      final bindings = config.bindings!;
      expect(bindings.output,
          p.join(tmp.path, 'lib', 'src', 't_bindings.web.g.dart'));
      expect(bindings.functions[0].dartName, 'createDuelC');
      expect(bindings.functions[0].params, {'seed': 'int'});
      expect(bindings.functions[0].returns, 'int');
      expect(bindings.functions[1].dartName, 'wasmMalloc');
    });

    test('rejects unsupported binding type', () {
      File(configPath).writeAsStringSync('''
name: t
output: out/x.js
sources: [${src.path}]
bindings:
  output: lib/src/t_bindings.web.g.dart
  functions:
    _f: {params: {x: String}}
''');
      expect(() => WasmBridgeConfig.load(configPath),
          throwsA(isA<WasmBridgeException>()));
    });

    test('plugin section requires output when no bindings output to follow',
        () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: ocgcore
flutter:
  plugin:
    platforms:
      web:
        pluginClass: OcgCoreWebPlugin
        fileName: src/ocgcore_web_plugin.dart
''');
      File(configPath).writeAsStringSync('''
name: libocgcore
output: web/libs/libocgcore.js
sources: [${src.path}]
plugin:
  package: ocgcore
''');
      expect(() => WasmBridgeConfig.load(configPath),
          throwsA(isA<WasmBridgeException>()));
    });

    test('plugin output defaults to bindings output', () {
      File(configPath).writeAsStringSync('''
name: libt
output: out/libt.js
sources: [${src.path}]
plugin:
  package: my_pkg
bindings:
  output: lib/src/t_web.dart
  functions:
    _f: {returns: int}
''');
      final config = WasmBridgeConfig.load(configPath);
      expect(config.plugin!.output, config.bindings!.output);
      expect(config.plugin!.output,
          p.join(tmp.path, 'lib', 'src', 't_web.dart'));
    });

    test('derives plugin package/class_name from pubspec', () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: ocgcore
flutter:
  plugin:
    platforms:
      web:
        pluginClass: OcgCoreWebPlugin
        fileName: src/ocgcore_web_plugin.dart
''');
      File(configPath).writeAsStringSync('''
name: libocgcore
output: web/libs/libocgcore.js
sources: [${src.path}]
plugin:
  output: lib/src/ocgcore_web_plugin.dart
''');
      final config = WasmBridgeConfig.load(configPath);
      final plugin = config.plugin!;
      expect(plugin.package, 'ocgcore');
      expect(plugin.className, 'OcgCoreWebPlugin');
      expect(plugin.output,
          p.join(tmp.path, 'lib', 'src', 'ocgcore_web_plugin.dart'));
      expect(plugin.jsAsset, 'packages/ocgcore/web/libs/libocgcore.js');
    });

    test('plugin stays null when section omitted', () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: ocgcore
flutter:
  plugin:
    platforms:
      web:
        pluginClass: OcgCoreWebPlugin
        fileName: src/ocgcore_web_plugin.dart
''');
      File(configPath).writeAsStringSync('''
name: libt
output: out/libt.js
sources: [${src.path}]
''');
      expect(WasmBridgeConfig.load(configPath).plugin, isNull);
    });

    test('bindings section requires output', () {
      File(configPath).writeAsStringSync('''
name: libt
output: out/libt.js
sources: [${src.path}]
bindings:
  functions:
    _f: {returns: int}
''');
      expect(() => WasmBridgeConfig.load(configPath),
          throwsA(isA<WasmBridgeException>()));
    });
  });

  group('renderBindings', () {
    test('generates Module getter, runtime methods and C API declarations',
        () {
      final tmp = Directory.systemTemp.createTempSync('wasm_bridge_gen');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final config = WasmBridgeConfig(
        name: 'libt',
        configDir: tmp.path,
        outputJs: p.join(tmp.path, 'out.js'),
        sources: [SourceGroup(path: tmp.path)],
        link: const LinkOptions(
          exportedFunctions: ['_malloc', '_create_duel', '_missing_sig'],
          exportedRuntimeMethods: ['HEAPU8', 'getValue', 'ccall'],
        ),
        bindings: const BindingsGenConfig(
          output: 'unused',
          functions: [
            FunctionSignature(
                jsName: '_malloc',
                dartName: 'wasmMalloc',
                params: {'size': 'int'},
                returns: 'int'),
            FunctionSignature(
                jsName: '_create_duel',
                dartName: 'createDuelC',
                params: {'seed': 'int'},
                returns: 'int'),
          ],
        ),
      );
      final code = renderBindings(config);
      expect(code, contains('external JSObject? get Module;'));
      expect(code, contains("@JS('Module.HEAPU8')"));
      expect(code, contains('external JSObject get heapU8;'));
      expect(code, contains("@JS('Module.getValue')"));
      expect(code,
          contains('external JSNumber getValue(JSAny ptr, JSString type);'));
      expect(code, contains("@JS('Module._malloc')"));
      expect(code, contains('external int wasmMalloc(int size);'));
      expect(code, contains('external int createDuelC(int seed);'));
      expect(code, contains('_missing_sig')); // 告警注释
      expect(code, isNot(contains("@JS('Module.ccall')")));
    });
  });

  group('renderWebPlugin', () {
    test('substitutes class name, assets and debug prefix', () {
      const plugin = PluginGenConfig(
        package: 'ocgcore',
        className: 'OcgCoreWebPlugin',
        output: 'unused',
        jsAsset: 'packages/ocgcore/web/libs/libocgcore.js',
        wasmAsset: 'packages/ocgcore/web/libs/libocgcore.wasm',
        debugPrefix: 'ocgcore',
      );
      final code = renderWebPlugin(plugin);
      expect(code, contains('class OcgCoreWebPlugin {'));
      expect(code,
          contains("..src = 'assets/packages/ocgcore/web/libs/libocgcore.js'"));
      expect(code,
          contains('return "assets/packages/ocgcore/web/libs/libocgcore.wasm";'));
      expect(code, contains("window['__ocgcoreScriptInjected']"));
      expect(code, contains('window.__ocgcorePluginStatus="runtime_initialized";'));
      expect(code, contains('window.__lastOcgcoreError=String(what);'));
      expect(code, isNot(contains('@PREFIX@')));
      expect(code, isNot(contains('__CLASS__')));
    });
  });

  group('renderWebCombined', () {
    test('emits bindings declarations and plugin class in one file', () {
      final tmp = Directory.systemTemp.createTempSync('wasm_bridge_combined');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final config = WasmBridgeConfig(
        name: 'libt',
        configDir: tmp.path,
        outputJs: p.join(tmp.path, 'out.js'),
        sources: [SourceGroup(path: tmp.path)],
        link: const LinkOptions(
          exportedFunctions: ['_create_duel'],
          exportedRuntimeMethods: ['HEAPU8'],
        ),
        plugin: const PluginGenConfig(
          package: 'ocgcore',
          className: 'OcgCoreWebPlugin',
          output: 'same.dart',
          jsAsset: 'packages/ocgcore/web/libs/libocgcore.js',
          wasmAsset: 'packages/ocgcore/web/libs/libocgcore.wasm',
          debugPrefix: 'ocgcore',
        ),
        bindings: const BindingsGenConfig(
          output: 'same.dart',
          functions: [
            FunctionSignature(
                jsName: '_create_duel',
                dartName: 'createDuelC',
                params: {'seed': 'int'},
                returns: 'int'),
          ],
        ),
      );
      final code = renderWebCombined(config);
      // 绑定声明与插件类在同一个文件里。
      expect(code, contains("@JS('Module._create_duel')"));
      expect(code, contains('external int createDuelC(int seed);'));
      expect(code, contains('class OcgCoreWebPlugin {'));
      // import 块只有一份。
      expect("import 'dart:js_interop';".allMatches(code).length, 1);
      expect("import 'package:flutter_web_plugins/flutter_web_plugins.dart';"
          .allMatches(code)
          .length, 1);
      expect(code, isNot(contains('@PREFIX@')));
    });
  });

  group('composeEmccArgs', () {
    test('composes language groups and link flags', () {
      final src = makeSources(['x.c']);
      addTearDown(() => src.deleteSync(recursive: true));
      final config = WasmBridgeConfig(
        name: 't',
        configDir: src.path,
        outputJs: p.join(src.path, 'out.js'),
        sources: [
          SourceGroup(path: src.path, language: 'c++'),
        ],
        includeDirs: [src.path],
        compileFlags: const ['-O3'],
        link: const LinkOptions(
          noEntry: true,
          exceptions: true,
          initialMemory: 1024,
          allowTableGrowth: true,
          exportedFunctions: ['_malloc'],
          exportedRuntimeMethods: ['ccall', 'HEAPU8'],
        ),
      );
      final args = composeEmccArgs(config);
      expect(args, containsAllInOrder(['-O3', '-I${src.path}']));
      final xIndex = args.indexOf('-x');
      expect(args[xIndex + 1], 'c++');
      expect(args, contains('--no-entry'));
      expect(args, contains('-fwasm-exceptions'));
      expect(args, contains('-sALLOW_MEMORY_GROWTH'));
      expect(args, contains('-sINITIAL_MEMORY=1024'));
      expect(args, contains('-sALLOW_TABLE_GROWTH'));
      expect(args, contains('-sEXPORTED_FUNCTIONS=_malloc'));
      expect(args, contains('-sEXPORTED_RUNTIME_METHODS=ccall,HEAPU8'));
      expect(args, contains('-sENVIRONMENT=web,node'));
      expect(args.last, p.join(src.path, 'out.js'));
    });
  });

  group('verifyArtifacts', () {
    test('reports missing symbols and wasm magic', () {
      final tmp = Directory.systemTemp.createTempSync('wasm_bridge_verify');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final jsPath = p.join(tmp.path, 'lib.js');
      final wasmPath = p.join(tmp.path, 'lib.wasm');
      File(jsPath).writeAsStringSync(
          'var Module={};Module["_malloc"]=_malloc=()=>{};Module["ccall"]=ccall;');
      File(wasmPath).writeAsBytesSync([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
      final config = WasmBridgeConfig(
        name: 't',
        configDir: tmp.path,
        outputJs: jsPath,
        sources: [SourceGroup(path: tmp.path, extensions: const ['.none'])],
        link: const LinkOptions(
          exportedFunctions: ['_malloc', '_free'],
          exportedRuntimeMethods: ['ccall', 'getValue'],
        ),
      );
      // extensions '.none' has no files -> resolveFiles would throw, but
      // verify does not touch sources.
      final report = verifyArtifacts(config);
      expect(report.ok, isFalse);
      expect(report.missingSymbols, ['_free', 'getValue']);
      expect(report.wasmMagicOk, isTrue);
    });
  });
}
