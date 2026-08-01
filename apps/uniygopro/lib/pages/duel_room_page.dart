import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:duelink/duelink.dart';
import 'package:uniygopro/service_singleton.dart';
import '../stores/duel_room_state.dart';
import '../stores/match_store.dart';
import '../services/deck_service.dart';
import '../widgets/ready_room/player_panel.dart';
import '../widgets/ready_room/room_info_panel.dart';
import '../widgets/ready_room/chat_panel.dart';
import '../widgets/ready_room/control_bar.dart';
import '../widgets/duel_room/duel_overlay.dart';
import '../widgets/playmat/playmat.dart';
import '../widgets/duel_room/chain_indicator.dart';
import '../widgets/ready_room/hand_result_display.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key});
  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceSingleton.instance.duelService;
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  StreamSubscription<YgoStocMsg>? _msgSub;
  DisplayStyle _displayStyle = DisplayStyle.card;
  late final DuelRoomState state;

  @override
  void initState() {
    super.initState();
    _loadDecks();
    _connect();
  }

  Future<void> _loadDecks() async {
    state = context.read<DuelRoomState>();
    await state.loadDecks();
  }

  Future<void> _connect() async {
    final match = context.read<MatchStore>();
    final state = context.read<DuelRoomState>();
    _duelService.onRoomStageChange.listen((roomStage) {
      console.log('Room state changed: $roomStage players=${roomStage.players} observers=${roomStage.observerCount}');
      state.updateFromDuelink(roomStage);
      if (roomStage is RoomInDuel) {
        state.bind(_duelService);
      }
    });

    _msgSub = _duelService.onServerMessage.listen((msg) {
      if (msg.selectTp != null) {
        state.enableTurnOrderSelection();
      }
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
    final state = context.read<DuelRoomState>();
    state.setHandResult(hand.value);
  }

  void _sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    _duelService.chooseTurnOrder(first);
    final state = context.read<DuelRoomState>();
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
    final mySlotVal = _mySlot(state);
    final isReady = state.players
        .where((p) => p.pos == mySlotVal)
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

  int _mySlot(DuelRoomState state) {
    switch (state.selfType) {
      case SelfType.player1:
        return 0;
      case SelfType.player2:
        return 1;
      default:
        return -1;
    }
  }

  bool _isMyself(DuelRoomState state, int pos) => _mySlot(state) == pos;

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
      backgroundColor: state.isInDuel ? Colors.brown.shade900 : Colors.blueGrey.shade900,
      appBar: state.isInDuel ? null : _buildAppBar(state, match) as PreferredSizeWidget?,
      body: state.isInDuel ? _buildDuelView(state) : _buildReadyRoomView(state, match),
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

  Widget _buildReadyRoomView(DuelRoomState state, MatchStore match) {
    final opts = state.roomOptions;
    final mySlotVal = _mySlot(state);
    final isPlayer = mySlotVal >= 0 && mySlotVal <= 1;
    final isReady = isPlayer &&
        state.players.where((p) => p.pos == mySlotVal).any((p) => p.ready);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PlayerPanel(
                  state: state,
                  match: match,
                  mySlot: mySlotVal,
                  onSendHand: _sendHand,
                  onSendTp: _sendTp,
                  onKick: (slot) => _duelService.kickPlayer(slot),
                  displayStyle: _displayStyle,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    if (opts != null) RoomInfoPanel(opts: opts),
                    Expanded(
                      child: ChatPanel(
                        state: state,
                        chatCtrl: _chatCtrl,
                        chatScrollCtrl: _chatScrollCtrl,
                        onSend: _sendChat,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_displayStyle == DisplayStyle.statusBar &&
            (state.stage is RoomSelectingHand ||
             state.stage is RoomHandResult ||
             state.stage is RoomSelectingTurn)) ...[
          _buildStatusBarResult(state),
        ],
        ControlBar(
          state: state,
          mySlot: mySlotVal,
          isPlayer: isPlayer,
          isReady: isReady,
          onToggleReady: _toggleReady,
          onSwitchToObserver: () => _duelService.becomeObserver(),
          onSwitchToDuelist: () => _duelService.becomeDuelist(),
          onStart: () => _duelService.startDuel(),
          onToggleDisplay: () {
            setState(() {
              _displayStyle = _displayStyle == DisplayStyle.card
                  ? DisplayStyle.statusBar
                  : DisplayStyle.card;
            });
          },
          displayStyle: _displayStyle,
        ),
      ],
    );
  }

  Widget _buildStatusBarResult(DuelRoomState state) {
    final mySlotVal = _mySlot(state);
    final myPlayer = state.players.where((p) => p.pos == mySlotVal).toList();
    final myName = myPlayer.isNotEmpty ? myPlayer.first.name : '我';

    final opSlot = mySlotVal == 0 ? 1 : 0;
    final opPlayer = state.players.where((p) => p.pos == opSlot).toList();
    final opName = opPlayer.isNotEmpty ? opPlayer.first.name : '对手';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: HandResultDisplay(
        myHandResult: state.myHandResult,
        opponentHandResult: state.opponentHandResult,
        isFirstTurn: state.isFirstTurn,
        stage: state.stage,
        style: DisplayStyle.statusBar,
        myName: myName,
        opponentName: opName,
      ),
    );
  }

  Widget _buildDuelView(DuelRoomState state) {
    return _buildFieldRenderer(state);
  }

  Widget _buildFieldRenderer(DuelRoomState state) {
    return SafeArea(
      child: Stack(children: [
        Playmat(duel: state),
        if (state.isWaitingForInput) DuelOverlay(state: state),
        if (state.chains.isNotEmpty)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: ChainIndicator(chainCount: state.chains.length),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: _buildBackButton(),
        ),
      ]),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _confirmBack(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _confirmBack() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出决斗'),
        content: const Text('确定要退出当前决斗吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _duelService.disconnect();
    super.dispose();
  }
}
