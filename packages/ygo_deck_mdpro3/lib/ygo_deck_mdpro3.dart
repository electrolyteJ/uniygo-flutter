// Barrel file — services are registered via @Service annotations in the services/ directory.

import 'dart:developer' as console;

import 'package:service_loader/service_loader.dart';
import 'package:ygo_deck_mdpro3/services/deck_service.dart';

@Service(MdPro3DeckService)
class MdPro3DeckService extends DeckService {}

@OnServiceRegister()
void onServiceRegister() {
  console.log('ygo_deck_mdpro3.dart onServiceRegister');
}
