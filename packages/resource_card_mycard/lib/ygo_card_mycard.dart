import 'package:applog/console.dart' as console;

import 'package:service_loader/service_loader.dart';
import 'package:resource_card_mycard/src/card_service.dart';
import 'package:resource_card_mycard/src/db/card_database.dart';
import 'src/env_config.dart';

export 'src/env_config.dart';

@Service(MyCardCardService)
class MyCardCardService extends CardService {
  MyCardCardService() : super(config: EnvConfig.production);
}

@OnServiceRegister()
onServiceRegister() {
  console.log('ygo_card_mycard.dart onServiceRegister');
  preDownloadDatabase();
}
