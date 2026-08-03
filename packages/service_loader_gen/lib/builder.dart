import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:package_config/package_config.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'src/registration.dart';

/// build.yaml 的 builder_factories 入口。
Builder serviceBuilder(BuilderOptions options) =>
    ServiceBuilder();

/// 扫描当前包及其直接依赖包 `lib/**` 下标注了 [Service] 的
/// 类/顶层函数，生成 `lib/service_loader.registrations.g.dart`，其中包含
/// `registerAllServices()` 函数。
///
/// - 标注在类上 → 生成 `() => ClassName()`，要求类可无参构造。
/// - 标注在顶层函数上 → 直接以该函数作为服务工厂。
///
/// 同时扫描 [OnServiceRegister] 标注的顶层函数，在
/// `registerAllServices()` 体开头调用它们。
///
/// 直接在生成注册代码的主包（应用）内完成全部扫描与生成：除了本包
/// `lib/`，还会扫描所有声明了 `service_loader` 依赖的直接依赖包，
/// 因此在服务包内无需再生成各自的注册文件。
///
/// 使用独立 [AnalysisContextCollection] 扫描源码，而不是
/// `buildStep.resolver`：后者无法解析引用了本包生成物的库，会导致这类
/// 库被当作未解析而漏掉注册。
class ServiceBuilder implements Builder {
  static const _outputName = 'service_loader.registrations.g.dart';
  static final _formatter = DartFormatter(
    languageVersion: Version.parse(Platform.version.split(' ').first),
  );

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': [_outputName],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final rootPackage = buildStep.inputId.package;
    final packageByName = await _loadPackageConfig();

    final libDirs = <Directory>{
      Directory(packageByName[rootPackage]!.root.resolve('lib').toFilePath()),
      for (final name
          in await _serviceDependencies(buildStep, packageByName))
        Directory(packageByName[name]!.root.resolve('lib').toFilePath()),
    };

    final collection = AnalysisContextCollection(
      includedPaths: [for (final dir in libDirs) dir.absolute.path],
    );
    final registrations = <String, ServiceRegistration>{};
    final onServiceRegisterHooks = <OnServiceRegisterHook>[];

    for (final libDir in libDirs) {
      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || _isGenerated(file.path)) continue;
        final library = await _resolveLibrary(collection, file);
        if (library == null) continue;
        final collector = ServiceRegistrationCollector();
        for (final registration in collector.collect(library)) {
          registrations[
            '${registration.libraryUri}|${registration.service}'
          ] = registration;
        }
        onServiceRegisterHooks
            .addAll(collector.collectOnServiceRegisterHooks(library));
      }
    }

    final output = renderRegisterAllServices(
      registrations.values.toList(),
      onServiceRegisterHooks: onServiceRegisterHooks,
    );
    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      _format(output),
    );
  }

  /// 加载当前包所在工程的真实 `package_config.json`（`buildStep.packageConfig`
  /// 返回的包根是 `asset:` URI，无法得到磁盘路径）。
  Future<Map<String, Package>> _loadPackageConfig() async {
    var dir = Directory.current;
    while (true) {
      final configFile = File('${dir.path}/.dart_tool/package_config.json');
      if (configFile.existsSync()) {
        final config = await loadPackageConfig(configFile);
        return {for (final package in config.packages) package.name: package};
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    throw StateError(
      'Cannot find .dart_tool/package_config.json above '
      '${Directory.current.path}',
    );
  }

  /// 直接依赖中声明了 `service_loader` 或 `service_loader_gen` 的包名。
  ///
  /// 只有这类包才可能标注 [Service]，过滤后可避免扫描
  /// provider/flame 等无关依赖的大体积 lib。
  Future<List<String>> _serviceDependencies(
    BuildStep buildStep,
    Map<String, Package> packageByName,
  ) async {
    final rootPackage = buildStep.inputId.package;
    final pubspec = await buildStep.readAsString(
      AssetId(rootPackage, 'pubspec.yaml'),
    );
    final yaml = loadYaml(pubspec) as YamlMap?;
    if (yaml == null) return const [];

    final direct = <String>{
      for (final key in const ['dependencies', 'dev_dependencies'])
        if (yaml[key] case final YamlMap deps)
          ...deps.keys.whereType<String>(),
    };

    final result = <String>[];
    for (final name in direct) {
      final package = packageByName[name];
      if (package == null) continue;
      if (_dependsOnServiceLoader(package.root)) result.add(name);
    }
    return result;
  }

  /// 包根目录下的 pubspec 是否声明了 `service_loader`（或 `service_loader_gen`）。
  bool _dependsOnServiceLoader(Uri packageRoot) {
    final pubspecFile = File(packageRoot.resolve('pubspec.yaml').toFilePath());
    if (!pubspecFile.existsSync()) return false;
    final yaml = loadYaml(pubspecFile.readAsStringSync()) as YamlMap?;
    if (yaml == null) return false;
    for (final key in const ['dependencies', 'dev_dependencies']) {
      if (yaml[key] case final YamlMap deps) {
        if (deps.keys
            .whereType<String>()
            .any((name) => name == 'service_loader' || name == 'service_loader_gen')) {
          return true;
        }
      }
    }
    return false;
  }

  Future<LibraryElement?> _resolveLibrary(
    AnalysisContextCollection collection,
    File file,
  ) async {
    try {
      final session = collection.contextFor(file.absolute.path).currentSession;
      final result = await session.getResolvedUnit(file.absolute.path);
      return (result as ResolvedUnitResult).libraryElement;
    } on Exception {
      return null;
    }
  }

  String _format(String source) {
    try {
      return _formatter.format(source);
    } on FormatterException {
      return source;
    }
  }

  bool _isGenerated(String path) =>
      path.endsWith('.g.dart') || path.endsWith('.g.part');
}
