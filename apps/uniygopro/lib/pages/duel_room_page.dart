import 'dart:async';
import 'dart:developer' as console;
import 'dart:math';
import 'dart:typed_data';

import 'package:duelink_online/duelink_online.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/pages/duel_field_page.dart';
import 'package:uniygopro/pages/waiting_room_page.dart';
import '../stores/duel_room_state.dart';
import '../stores/match_store.dart';
import '../services/deck_service.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key});
  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceFactory.create<OnlineDuelService>();
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<YgoStocMsg>? _chatMsgSub;

  late final DuelRoomState state;

  @override
  void initState() {
    super.initState();
    state = context.read<DuelRoomState>();
    state.loadDecks();
    _connect();
  }
  final Random random = Random();
  Future<void> _connect() async {
    final match = context.read<MatchStore>();
    final state = context.read<DuelRoomState>();
    _duelService.onRoomStageChange.listen((roomStage) {
      state.players = roomStage.players;
      state.observerCount = roomStage.observerCount;
      state.stage = roomStage;
      switch (roomStage) {
        case RoomNotJoined():
          //游戏结束或者离开房间后，重置房间状态
          break;
        case RoomInLobby():
          state.selfType = roomStage.selfType;
          state.isHost = roomStage.isHost;
          state.roomOptions = roomStage.options;
          break;
        case RoomSelectingHand():
          if (state.autoHandEnabled) {
            final timer = Timer(const Duration(milliseconds: 700), () {
              state.opponentHandResult = 0;
              final hands = HandType.values
                  .where((hand) => hand != HandType.unknown)
                  .toList();
              _sendHand(hands[random.nextInt(hands.length)]);
            });
          }
          break;
        case RoomHandResult():
          state.myHandResult = roomStage.myHand;
          state.opponentHandResult = roomStage.opponentHand;
          break;
        case RoomSelectingTurn():
          if (state.autoTurnOrderEnabled) {
            _sendTp(random.nextBool());
          }
          break;
        case RoomInDuel():
          state.bind(_duelService);
          state.myHandResult = 0;
          state.opponentHandResult = 0;
          state.isFirstTurn = roomStage.isFirstTurn;
          break;
        case RoomDuelEnded():
          // state.unbind();
          context.go('/');
          break;
        default:
          break;
      }
      state.notifyListeners();
    });

    _chatMsgSub = _duelService.onChatServerMessage.listen((msg) {
      if (msg.chat != null) {
        final chat = msg.chat!;
        final player = state.players.where((p) => p.pos == chat.player).toList();
        final name = chat.player < 0
            ? 'System'
            : (player.isNotEmpty ? player.first.name : '[${chat.player}]');
        state.addChat(chat.player, name, chat.message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollCtrl.hasClients) {
            _chatScrollCtrl.animateTo(
              _chatScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    _msgSub = _duelService.onServerMessage.listen((msg) {
      console.log('Received server message: $msg');
      if (msg.selectTp != null) {
        console.log('Received selectTp message: ${msg.selectTp}');
        state.enableTurnOrderSelection();
      }
      if (msg.errorMsg != null) {
        final err = msg.errorMsg!;
        state.setError(_errorMessage(err.errorType, err.errorCode));
      }
    });

    final host = match.serverAddress;
    final port = match.serverPort;
    final password = match.serverPassword;
    if (host == null || port == null) {
      console.log('Server address or port is null');
      return;
    }
    await _duelService.connect(host, port);
    _duelService.setPlayerName(match.username);
    _duelService.enterRoom(password ?? '');
  }

  void _sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    _duelService.chooseHand(hand);
    state.setHandResult(hand.value);
  }

  void _sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    _duelService.chooseTurnOrder(first);
    state.setTpResult(first);
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _duelService.sendChat(text);
    _chatCtrl.clear();
  }

  Future<void> _toggleReady() async {
    final state = context.read<DuelRoomState>();
    final isReady = state.players
        .where((p) => p.pos == state.selfType.slot)
        .any((p) => p.ready);
    if (isReady) {
      _duelService.unready();
    } else {
      final deckName = state.selectedDeckName;
      if (deckName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先选择卡组'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final deckService = DeckService();
      final deck = await deckService.loadDeck(deckName);
      console.log('loadDeck: $deckName -> $deck');
      if (deck == null || deck.main.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('卡组为空或加载失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final mainBytes = _deckToBytes(deck.main.map((c) => c.code).toList());
      final extraBytes = _deckToBytes(deck.extra.map((c) => c.code).toList());
      _duelService.submitDeck(mainBytes, extraBytes);
      _duelService.ready();
    }
  }

  Uint8List _deckToBytes(List<int> codes) {
    final bytes = Uint8List(codes.length * 4);
    final bd = ByteData.view(bytes.buffer);
    for (int i = 0; i < codes.length; i++) {
      bd.setInt32(i * 4, codes[i], Endian.little);
    }
    return bytes;
  }

  String _roomTitle(DuelRoomState state, MatchStore match) {
    final modeName = switch (state.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛',
      RoomMode.tag => '双打',
      _ => '',
    };
    if (match.roomName.isNotEmpty) return match.roomName;
    return '$modeName房间';
  }

  String _errorMessage(int type, int code) {
    switch (type) {
      case 1:
        return '连接已断开';
      case 2:
        return '你已经被踢出房间';
      case 3:
        return '错误: $code';
      case 4:
        return '卡组无效 (错误码: $code)';
      case 5:
        return '卡组数量不正确 (错误码: $code)';
      case 6:
        return '主卡组需要至少40张';
      case 7:
        return '额外卡组不能超过15张';
      case 8:
        return '副卡组不能超过15张';
      case 9:
        return '禁限卡表不匹配';
      default:
        return '服务器错误: type=$type code=$code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DuelRoomState>();
    final match = context.watch<MatchStore>();
    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
          state.clearError();
        }
      });
    }

    return Scaffold(
      backgroundColor: state.stage is RoomInDuel
          ? Colors.brown.shade900
          : Colors.blueGrey.shade900,
      appBar: state.stage is RoomInDuel ? null : _buildAppBar(state, match) as PreferredSizeWidget?,
      body: state.stage is RoomInDuel
          ? DuelFieldPage(state: state)
          : WaitingRoomPage(state: state, match: match, onSendHand: _sendHand, onSendTp: _sendTp, onKick: (int slot) {
        _duelService.kickPlayer(slot);
      }, chatCtrl: _chatCtrl, chatScrollCtrl: _chatScrollCtrl, onSend: _sendChat, onToggleReady: _toggleReady, onSwitchToObserver: () {
        _duelService.becomeObserver();
      }, onSwitchToDuelist: () {
        _duelService.becomeDuelist();
      }, onStart: () {
        _duelService.startDuel();
      },),
    );
  }

  Widget _buildAppBar(DuelRoomState state, MatchStore match) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          _duelService.disconnect();
          context.go('/');
        },
      ),
      title: Text(_roomTitle(state, match)),
      backgroundColor: Colors.blueGrey.shade800,
      foregroundColor: Colors.white,
    );
  }


  @override
  void dispose() {
    _msgSub?.cancel();
    _chatMsgSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _duelService.surrender();
    _duelService.disconnect();
    super.dispose();
  }
}
