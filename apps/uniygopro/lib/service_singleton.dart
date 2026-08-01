import 'package:duelink_online/duelink_online.dart';
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/service_loader.registrations.g.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';

class ServiceSingleton {

  late OnlineDuelService duelService;
  late CardService cardService;

  ServiceSingleton._();

  static final ServiceSingleton instance = ServiceSingleton._();

  void registerService() {
    registerAllServices();
    duelService = ServiceFactory.create<OnlineDuelService>();
    cardService = ServiceFactory.create<CardService>();
  }
}
