

import 'dart:typed_data';

import 'package:duelink/duelink.dart';

class LanDuelServiceImpl implements IDuelService {
  @override
  void becomeDuelist() {
    // TODO: implement becomeDuelist
  }

  @override
  void becomeObserver() {
    // TODO: implement becomeObserver
  }

  @override
  void chooseHand(HandType hand) {
    // TODO: implement chooseHand
  }

  @override
  void chooseTurnOrder(bool goFirst) {
    // TODO: implement chooseTurnOrder
  }

  @override
  void confirmTime() {
    // TODO: implement confirmTime
  }

  @override
  Future<void> connect(String address, int port) {
    // TODO: implement connect
    throw UnimplementedError();
  }

  @override
  // TODO: implement connectionState
  ConnectionState get connectionState => throw UnimplementedError();

  @override
  Future<void> disconnect() {
    // TODO: implement disconnect
    throw UnimplementedError();
  }

  @override
  void enterRoom(String password) {
    // TODO: implement enterRoom
  }

  @override
  void kickPlayer(int pos) {
    // TODO: implement kickPlayer
  }

  @override
  // TODO: implement onRoomStateChange
  Stream<RoomState> get onRoomStateChange => throw UnimplementedError();

  @override
  // TODO: implement onServerMessage
  Stream<YgoStocMsg> get onServerMessage => throw UnimplementedError();

  @override
  void playGameResponse(CtosGameMsgResponse response) {
    // TODO: implement playGameResponse
  }

  @override
  void ready() {
    // TODO: implement ready
  }

  @override
  void sendChat(String message) {
    // TODO: implement sendChat
  }

  @override
  void setPlayerName(String name) {
    // TODO: implement setPlayerName
  }

  @override
  void startDuel() {
    // TODO: implement startDuel
  }

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck) {
    // TODO: implement submitDeck
  }

  @override
  void surrender() {
    // TODO: implement surrender
  }

  @override
  void unready() {
    // TODO: implement unready
  }


}