import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

/// 一条服务注册信息。
class ServiceRegistration {
  /// 服务类型源码（如 `OnlineDuelService`），用作注册表的 key。
  final String service;

  /// 服务类型所在库的 uri（用于生成 import）。
  final Uri? serviceLibraryUri;

  /// 生成代码中的工厂表达式（如 `() => OnlineDuelService()`）。
  final String creator;

  /// 元素所在库的 uri（用于生成 import）。
  final Uri libraryUri;

  ServiceRegistration({
    required this.service,
    this.serviceLibraryUri,
    required this.creator,
    required this.libraryUri,
  });

  /// 用于生成 import 的导入路径。
  ///
  /// `package:` URI 原样使用（既适用于本包，也适用于依赖包），其余
  /// scheme（如 `file:`，仅测试中出现）原样输出。
  String get relativeImport => libraryUri.toString();

  /// 服务类型所在库的导入路径。
  ///
  /// 若服务类型与实现同库，则复用实现库的 import，避免重复导入。
  String get serviceImport {
    if (serviceLibraryUri == null || serviceLibraryUri == libraryUri) {
      return '';
    }
    return serviceLibraryUri.toString();
  }
}

class OnServiceRegisterHook {
  /// 函数名。
  final String functionName;

  /// 函数所在库的 uri。
  final Uri libraryUri;

  OnServiceRegisterHook({
    required this.functionName,
    required this.libraryUri,
  });
}
class ServiceRegistrationCollector {
  static final TypeChecker _serviceAnnotation = TypeChecker.fromUrl(
    Uri.parse('package:service_loader/service_loader.dart#Service'),
  );
  static final TypeChecker _onServiceRegister = TypeChecker.fromUrl(
    Uri.parse('package:service_loader/service_loader.dart#OnServiceRegister'),
  );
  static final TypeChecker _iservice = TypeChecker.fromUrl(
    Uri.parse('package:service_loader/service_loader.dart#IService'),
  );

  /// 收集 [library] 中所有标注了 [Service] 的元素。
  List<ServiceRegistration> collect(LibraryElement library) {
    final result = <ServiceRegistration>[];
    for (final element in [...library.classes, ...library.topLevelFunctions]) {
      for (final metadata in element.metadata.annotations) {
        final value = metadata.computeConstantValue();
        if (value == null ||
            !_serviceAnnotation.isExactlyType(value.type!)) continue;
        result.add(_createRegistration(element, value));
      }
    }
    return result;
  }

  /// 收集 [library] 中所有标注了 [OnServiceRegister] 的顶层函数。
  ///
  /// 返回 [OnServiceRegisterHook]，包含函数名和所在库的 uri。
  /// 允许多个函数同时标注。
  List<OnServiceRegisterHook> collectOnServiceRegisterHooks(
      LibraryElement library) {
    final result = <OnServiceRegisterHook>[];
    for (final element in library.topLevelFunctions) {
      for (final metadata in element.metadata.annotations) {
        final value = metadata.computeConstantValue();
        if (value == null ||
            !_onServiceRegister.isExactlyType(value.type!)) continue;
        result.add(OnServiceRegisterHook(
          functionName: element.name!,
          libraryUri: element.library.uri,
        ));
      }
    }
    return result;
  }

  ServiceRegistration _createRegistration(
    Element element,
    DartObject value,
  ) {
    final reader = ConstantReader(value);
    final serviceType = reader.read('service').typeValue;

    switch (element) {
      case ClassElement():
        if (!_iservice.isAssignableFromType(element.thisType)) {
          throw InvalidGenerationSourceError(
            '@Service 标注的类必须实现 IService：${element.name}',
            element: element,
          );
        }
        return ServiceRegistration(
          service: serviceType.getDisplayString(),
          serviceLibraryUri: serviceType.element?.library?.uri,
          creator: '() => ${element.name}()',
          libraryUri: element.library.uri,
        );
      case TopLevelFunctionElement():
        if (!_iservice.isAssignableFromType(element.returnType)) {
          throw InvalidGenerationSourceError(
            '@Service 标注的顶层函数必须返回 IService：${element.name}',
            element: element,
          );
        }
        return ServiceRegistration(
          service: serviceType.getDisplayString(),
          serviceLibraryUri: serviceType.element?.library?.uri,
          creator: element.name!,
          libraryUri: element.library.uri,
        );
      default:
        throw InvalidGenerationSourceError(
          '@Service 只能标注在类或顶层函数上。',
          element: element,
        );
    }
  }
}

/// 渲染 `service_loader.registrations.g.dart` 的完整内容。
///
/// [registrations] 为 [Service] 标注的服务注册列表；
/// [onServiceRegisterHooks] 为 [OnServiceRegister] 标注的函数列表，
/// 会在 `registerAllServices()` 体开头按顺序调用。当多个函数同名时，
/// 通过 `import ... as _iN` 前缀消歧义。
String renderRegisterAllServices(
  List<ServiceRegistration> registrations, {
  List<OnServiceRegisterHook> onServiceRegisterHooks = const [],
}) {
  // 统计同名函数，决定哪些需要 import prefix 消歧义。
  final nameCount = <String, int>{};
  for (final hook in onServiceRegisterHooks) {
    nameCount[hook.functionName] =
        (nameCount[hook.functionName] ?? 0) + 1;
  }
  final collisionNames = nameCount.entries
      .where((e) => e.value > 1)
      .map((e) => e.key)
      .toSet();

  // 为需要消歧义的 hook 分配 import prefix。
  int prefixIdx = 1;
  final prefixByHook = <OnServiceRegisterHook, String?>{};
  final prefixImports = <String, String>{}; // uri -> prefix
  for (final hook in onServiceRegisterHooks) {
    if (collisionNames.contains(hook.functionName)) {
      final uri = hook.libraryUri.toString();
      final prefix = prefixImports.putIfAbsent(uri, () => '_i${prefixIdx++}');
      prefixByHook[hook] = prefix;
    } else {
      prefixByHook[hook] = null;
    }
  }
  final prefixedUris = prefixImports.keys.toSet();

  final imports = <String>{
    'package:service_loader/service_loader.dart',
    for (final r in registrations) r.relativeImport,
    for (final r in registrations) r.serviceImport,
    for (final hook in onServiceRegisterHooks)
      if (!prefixedUris.contains(hook.libraryUri.toString()))
        hook.libraryUri.toString(),
  }..remove('');

  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln();
  for (final uri in imports.toList()..sort()) {
    output.writeln("import '$uri';");
  }
  for (final entry in prefixImports.entries) {
    output.writeln("import '${entry.key}' as ${entry.value};");
  }
  output.writeln();
  output.writeln('/// 注册本包内所有标注了 [Service] 的服务。');
  if (registrations.isEmpty && onServiceRegisterHooks.isEmpty) {
    output.writeln('void registerAllServices() {}');
  } else {
    output.writeln('void registerAllServices() {');
    for (final hook in onServiceRegisterHooks) {
      final prefix = prefixByHook[hook];
      if (prefix != null) {
        output.writeln('  $prefix.${hook.functionName}();');
      } else {
        output.writeln('  ${hook.functionName}();');
      }
    }
    for (final registration in registrations) {
      output.writeln(
        '  ServiceFactory.register<${registration.service}>('
        '${registration.creator});',
      );
    }
    output.writeln('}');
  }
  return output.toString();
}
