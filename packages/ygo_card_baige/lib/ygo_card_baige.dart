import 'package:service_loader/service_loader.dart';

export 'src/baige_api_client.dart' show BaigeApiClient, CardImageCdn;
export 'src/baige_card_service.dart' show BaigeCardService;

@OnServiceRegister()
void onServiceRegister() {}
