import 'package:service_loader/service_loader.dart';
import 'package:ygo_deck/ygo_deck.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';

void registerMdPro3CardService() {
  registerDeckService(ServiceType.deck_mdpro3, () => DeckService());
}
