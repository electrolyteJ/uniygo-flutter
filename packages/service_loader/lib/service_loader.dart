interface class IService {}

/// 服务工厂注册表
class ServiceFactory {
  static final Map<int, IService Function()> _registry = {};

  /// 注册服务实现
  static void register(int type, IService Function() creator) {
    _registry[type] = creator;
  }

  /// 创建服务实例
  static IService create(int type) {
    final creator = _registry[type];
    if (creator == null) {
      throw UnimplementedError('Service type $type not registered');
    }
    return creator();
  }

  /// 检查类型是否已注册
  static bool isRegistered(int type) => _registry.containsKey(type);
}

/// 服务类型枚举
interface class ServiceType {
  static const int duelink_online = 0; // 默认网络服务
  static const int duelink_lan = 1; // 局域网服务
  static const int duelink_ai = 2; // AI本地服务
  static const int card_mycard = 3;
  static const int deck_mdpro3 = 4;
}
