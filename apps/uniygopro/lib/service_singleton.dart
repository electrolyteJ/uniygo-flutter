import 'package:service_loader/service_loader.dart';
import 'package:ygo_data/ygo_data.dart';

class ServiceSingleton {
  late YgoDataService dataService;

  ServiceSingleton._();

  static final ServiceSingleton instance = ServiceSingleton._();

  void registerService() {
    dataService = ServiceFactory.create<YgoDataService>();
  }
}
