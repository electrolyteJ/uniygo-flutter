import 'package:service_loader/service_loader.dart';

/// 卡片资源服务
abstract class IDeckService implements IService {

}
IService createDeckService(int type) {
  return ServiceFactory.create(type);
}

void registerDeckService(int type, IService Function() creator) {
  ServiceFactory.register(type, creator);
}
