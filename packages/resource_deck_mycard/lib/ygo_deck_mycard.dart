import 'package:applog/console.dart' as console;

import 'package:service_loader/service_loader.dart';
import 'src/deck_service.dart';

@Service(MycardDeckService)
class MycardDeckService extends DeckService {}

@OnServiceRegister()
void onServiceRegister() {
  console.log('ygo_deck_mycard.dart onServiceRegister');
}
