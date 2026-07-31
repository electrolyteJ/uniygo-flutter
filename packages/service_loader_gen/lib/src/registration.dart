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

/// 收集一个库中标注了 [ServiceRegister] 的类/顶层函数。
class ServiceRegistrationCollector {
  static final TypeChecker _annotation = TypeChecker.fromUrl(
    Uri.parse('package:service_loader/service_loader.dart#ServiceRegister'),
  );
  static final TypeChecker _iservice = TypeChecker.fromUrl(
    Uri.parse('package:service_loader/service_loader.dart#IService'),
  );

  /// 收集 [library] 中所有标注了 [ServiceRegister] 的元素。
  List<ServiceRegistration> collect(LibraryElement library) {
    final result = <ServiceRegistration>[];
    for (final element in [...library.classes, ...library.topLevelFunctions]) {
      for (final metadata in element.metadata.annotations) {
        final value = metadata.computeConstantValue();
        if (value == null || !_annotation.isExactlyType(value.type!)) continue;
        result.add(_createRegistration(element, value));
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
            '@ServiceRegister 标注的类必须实现 IService：${element.name}',
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
            '@ServiceRegister 标注的顶层函数必须返回 IService：${element.name}',
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
          '@ServiceRegister 只能标注在类或顶层函数上。',
          element: element,
        );
    }
  }
}

/// 渲染 `service_loader.registrations.g.dart` 的完整内容。
String renderRegisterAllServices(List<ServiceRegistration> registrations) {
  final imports = <String>{
    'package:service_loader/service_loader.dart',
    for (final r in registrations) r.relativeImport,
    for (final r in registrations) r.serviceImport,
  }..remove('');

  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln();
  for (final uri in imports.toList()..sort()) {
    output.writeln("import '$uri';");
  }
  output.writeln();
  output.writeln('/// 注册本包内所有标注了 [ServiceRegister] 的服务。');
  if (registrations.isEmpty) {
    output.writeln('void registerAllServices() {}');
  } else {
    output.writeln('void registerAllServices() {');
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
