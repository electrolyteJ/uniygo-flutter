

import 'dart:typed_data';

import 'package:duelink/duelink.dart';

class LanDuelServiceImpl implements DuelService {
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
  // TODO: implement onMessage
  Stream<YgoStocMsg> get onMessage => throw UnimplementedError();

  @override
  // TODO: implement onRoomStateChange
  Stream<RoomState> get onRoomStateChange => throw UnimplementedError();

  @override
  void sendChat(String message) {
    // TODO: implement sendChat
  }

  @override
  void sendHandResult(HandType hand) {
    // TODO: implement sendHandResult
  }

  @override
  void sendJoinGame(int gameId, String? passwd) {
    // TODO: implement sendJoinGame
  }

  @override
  void sendKick(int pos) {
    // TODO: implement sendKick
  }

  @override
  void sendNotReady() {
    // TODO: implement sendNotReady
  }

  @override
  void sendPlayerInfo(String name) {
    // TODO: implement sendPlayerInfo
  }

  @override
  void sendReady() {
    // TODO: implement sendReady
  }

  @override
  void sendResponse(CtosGameMsgResponse response) {
    // TODO: implement sendResponse
  }

  @override
  void sendStart() {
    // TODO: implement sendStart
  }

  @override
  void sendSurrender() {
    // TODO: implement sendSurrender
  }

  @override
  void sendTimeConfirm() {
    // TODO: implement sendTimeConfirm
  }

  @override
  void sendToDuelist() {
    // TODO: implement sendToDuelist
  }

  @override
  void sendToObserver() {
    // TODO: implement sendToObserver
  }

  @override
  void sendTpResult(bool first) {
    // TODO: implement sendTpResult
  }

  @override
  void sendUpdateDeck(Uint8List mainDeck, Uint8List extraDeck) {
    // TODO: implement sendUpdateDeck
  }

}