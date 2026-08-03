interface class IService {}

/// 编译时服务注册注解。
///
/// 标注在服务实现类上（要求可无参构造），或标注在返回 [IService] 的
/// 顶层工厂函数上。配合 `service_loader_gen` 生成器，在编译期自动生成
/// `registerAllServices()` 注册函数，无需手写注册逻辑。
///
/// [service] 为服务类型，作为注册表的唯一 key。同一类型重复注册会抛
/// [StateError]。
class Service {
  final Type service;
  const Service(this.service);
}

/// 服务注册完成回调注解。
///
/// 标注在无参顶层函数上。`service_loader_gen` 生成器会在编译期收集所有
/// 标注了 [OnServiceRegister] 的函数，并在 `registerAllServices()` 的
/// 开头按发现顺序依次调用它们。
///
/// 常用于在服务注册前执行初始化逻辑（如预加载配置、设置环境等）。
class OnServiceRegister{
  const OnServiceRegister();
}
/// 服务工厂注册表 — 按服务类型（[Service.service]）索引。
///
/// 通过泛型方法保证 key 与工厂函数返回类型一致：
/// - [register] 注册 `T` 的工厂函数
/// - [create] 创建 `T` 的实例
class ServiceFactory {
  static final Map<Type, IService Function()> _registry = {};

  /// 注册服务实现。
  ///
  /// 同一类型重复注册会抛 [StateError]，而不是静默覆盖。
  static void register<T extends IService>(T Function() creator) {
    if (_registry.containsKey(T)) {
      throw StateError(
        'Service type $T is already registered. '
        'Check for duplicate @Service annotations across the packages '
        'whose registerAllServices() is being called.',
      );
    }
    _registry[T] = creator;
  }

  /// 创建服务实例。
  static T create<T extends IService>() {
    final creator = _registry[T];
    if (creator == null) {
      throw UnimplementedError(
        'Service type $T is not registered. '
        'Did you forget to call the registerAllServices() of the package '
        'that provides it?',
      );
    }
    return creator() as T;
  }

  /// 检查类型是否已注册。
  static bool isRegistered<T extends IService>() =>
      _registry.containsKey(T);

  /// 清空注册表（主要用于测试隔离）。
  static void clear() => _registry.clear();
}
