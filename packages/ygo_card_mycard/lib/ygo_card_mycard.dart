import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/src/card_service.dart';
import 'src/env_config.dart';

export 'src/env_config.dart';

@Service(CardService)
CardService createMyCardCardService() =>
    CardService(config: EnvConfig.production);

@OnServiceRegister()
onServiceRegister() {
  preDownloadDatabase();
}

class CardService extends BaseCardService {
  CardService({required EnvConfig config}) : super(config: config);
}
