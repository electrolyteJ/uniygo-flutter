import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/src/card_service.dart';
import 'package:ygo_data/ygo_data.dart';
import 'src/env_config.dart';

export 'src/env_config.dart';

@Service(CardService)
ICardService createMyCardCardService() =>
    CardService(config: EnvConfig.production);

@OnServiceRegister()
onServiceRegister() {
  preDownloadDatabase();
}
