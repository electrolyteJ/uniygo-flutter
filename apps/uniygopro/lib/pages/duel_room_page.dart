import 'dart:async';
import 'dart:developer' as console;
import 'dart:math';

import 'package:duelink/duelink.dart' as duel;
import 'package:duelink/duelink.dart';
import 'package:duelink_online/duelink_online.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/pages/duel_field_page.dart';
import 'package:uniygopro/pages/waiting_room_page.dart';
import '../stores/duel_board_store.dart';
import '../stores/duel_chat_store.dart';
import '../stores/waiting_room_store.dart';
import '../stores/duel_room_state.dart';
import '../stores/duel_selection_store.dart';
import '../stores/duel_ui_store.dart';
import '../stores/match_store.dart';
import '../models/duel_event.dart';
import '../models/DuelPhase.dart';
import '../eventbus/duel_event_mapper.dart';


class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key});

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceFactory.create<OnlineDuelService>();
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  StreamSubscription<RoomStage>? _roomStageSub;
  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<YgoStocMsg>? _chatMsgSub;

  late final DuelRoomState duelRoomState;
  late final DuelChatStore duelChatStore;
  late final WaitingRoomStore waitingRoomStore;
  late final DuelBoardStore duelBoardStore;
  late final DuelSelectionStore selectionStore;
  late final DuelUiStore uiStore;
  late final MatchStore matchRoomStore;

  @override
  void initState() {
    super.initState();
    duelRoomState = context.read<DuelRoomState>();
    duelRoomState.bind(_duelService);
    waitingRoomStore = context.read<WaitingRoomStore>();
    waitingRoomStore.bind(_duelService);
    duelChatStore = context.read<DuelChatStore>();
    duelBoardStore = context.read<DuelBoardStore>();
    duelBoardStore.bind(_duelService);
    selectionStore = context.read<DuelSelectionStore>();
    selectionStore.bind(_duelService);
    uiStore = context.read<DuelUiStore>();
    matchRoomStore = context.read<MatchStore>();
    _connect();
  }

  final Random random = Random();

  Future<void> _connect() async {

    _roomStageSub = _duelService.onRoomStageChange.listen((roomStage) {
      waitingRoomStore.players = roomStage.players;
      waitingRoomStore.observerCount = roomStage.observerCount;
      waitingRoomStore.stage = roomStage;
      switch (roomStage) {
        case RoomNotJoined():
          //游戏结束或者离开房间后，重置房间状态
          break;
        case RoomInLobby():
          waitingRoomStore.selfType = roomStage.selfType;
          waitingRoomStore.isHost = roomStage.isHost;
          waitingRoomStore.roomOptions = roomStage.options;
          break;
        case RoomSelectingHand():
          if (waitingRoomStore.autoHandEnabled) {
            Timer(const Duration(milliseconds: 700), () {
              waitingRoomStore.opponentHandResult = 0;
              final hands = HandType.values
                  .where((hand) => hand != HandType.unknown)
                  .toList();
              _sendHand(hands[random.nextInt(hands.length)]);
            });
          }
          break;
        case RoomHandResult():
          waitingRoomStore.myHandResult = roomStage.myHand;
          waitingRoomStore.opponentHandResult = roomStage.opponentHand;
          break;
        case RoomSelectingTurn():
          if (waitingRoomStore.autoTurnOrderEnabled) {
            _sendTp(random.nextBool());
          }
          break;
        case RoomInDuel():
          // duelRoomState.bind(_duelService);
          waitingRoomStore.myHandResult = 0;
          waitingRoomStore.opponentHandResult = 0;
          waitingRoomStore.isFirstTurn = roomStage.isFirstTurn;
          break;
        case RoomDuelEnded():
          backhome();
          break;
        default:
          break;
      }
      waitingRoomStore.markChanged();
    });

    _chatMsgSub = _duelService.onChatServerMessage.listen((msg) {
      if (msg.chat != null) {
        final chat = msg.chat!;
        final player = waitingRoomStore.players
            .where((p) => p.pos == chat.player)
            .toList();
        final name = chat.player < 0
            ? 'System'
            : (player.isNotEmpty ? player.first.name : '[${chat.player}]');
        duelChatStore.addChat(chat.player, name, chat.message);

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
      duelChatStore.markChanged();

    });
    _msgSub = _duelService.onServerMessage.listen((msg) {
      console.log('Received server message: $msg');
      _onMessage(msg);
      if (msg.selectTp != null) {
        console.log('Received selectTp message: ${msg.selectTp}');
        waitingRoomStore.enableTurnOrderSelection();
      }
      if (msg.errorMsg != null) {
        final err = msg.errorMsg!;
        waitingRoomStore.setError(_errorMessage(err.errorType, err.errorCode));
      }
    });

    final host = matchRoomStore.serverAddress;
    final port = matchRoomStore.serverPort;
    final password = matchRoomStore.serverPassword;
    if (host == null || port == null) {
      console.log('Server address or port is null');
      return;
    }
    await _duelService.connect(host, port);
    _duelService.setPlayerName(matchRoomStore.username);
    _duelService.enterRoom(password ?? '');
  }
  // ══════════════════════════════════════════
  // 消息处理 (from DuelStore)
  // ══════════════════════════════════════════
  final DuelEventMapper _eventMapper = const DuelEventMapper();
  void _onMessage(YgoStocMsg msg) {
    switch (msg.protoId) {
      case MSG_SHUFFLE_DECK:
        console.log('Received shuffle deck message: $msg');
        return;
      default:
        break;
    }
    final event = _eventMapper.map(msg);
    if (event == null) return;
    _onEvent(event);
    duelRoomState.markChanged();
    waitingRoomStore.markChanged();
    duelBoardStore.markChanged();
    selectionStore.markChanged();
    uiStore.markChanged();
  }

  void _onEvent(DuelEvent event) {
    switch (event) {
      case DuelIgnoredEvent():
        return;
      case DuelFlowMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_START:
            _handleStart(innerMsg);
            break;
          case MSG_NEW_TURN:
            _handleNewTurn(innerMsg);
            break;
          case MSG_NEW_PHASE:
            _handleNewPhase(innerMsg);
            break;
          case MSG_WAITING:
            _handleWaiting(innerMsg as MsgWait);
            break;
          case MSG_ATTACK:
            _handleAttack(innerMsg);
            break;
          case MSG_DAMAGE:
            _handleDamage(innerMsg);
            break;
          case MSG_PAY_LP_COST:
            _handlePayLife(innerMsg);
            break;
          case MSG_CHAINING:
            final name = duelBoardStore.handleChaining(innerMsg);
            addLog('连锁发动 ${name}。');
            break;
          case MSG_CHAIN_END:
            _handleChainEnd(innerMsg);
            break;
          case MSG_SUMMONING:
            final name = duelBoardStore.handleSummoning(innerMsg);
            addLog('正在召唤 $name。');
            break;
          case MSG_BATTLE:
            _handleBattle(innerMsg as MsgBattle);
            break;
          case MSG_HINT:
            final msg = innerMsg as MsgHint;
            console.log(
              'MSG_HINT received, but no handler implemented yet. $msg',
            );
            break;
          case MSG_WIN:
            final msg = innerMsg as MsgWin;
            console.log(
              'MSG_WIN received, but no handler implemented yet. $msg',
            );
            break;
          default:
            console.log('Unhandled flow event: $func');
        }
        return;
      case DuelBoardMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_DRAW:
            _handleDraw(innerMsg);
            break;
          case MSG_UPDATE_DATA:
            _handleUpdateData(innerMsg as MsgUpdateData);
            break;
          case MSG_UPDATE_CARD:
            _handleUpdateCard(innerMsg as MsgUpdateCard);
            break;
          case MSG_RELOAD_FIELD:
            _handleReloadField(innerMsg as MsgReloadField);
            break;
          case MSG_MOVE:
            _handleMove(innerMsg);
            break;
          case MSG_FIELD_DISABLED:
            _handleFieldDisabled(innerMsg as MsgFieldDisabled);
            break;
          case MSG_POS_CHANGE:
            final card = duelBoardStore.handlePosChange(innerMsg);
            addLog('${card?.name} 表示形式变更。');
            break;
          case MSG_SHUFFLE_HAND:
            _handleShuffleHand(innerMsg);
            break;
          case MSG_SET:
            final msg = innerMsg as MsgSet;
            console.log(
              'MSG_SET received, but no handler implemented yet. $msg',
            );
            break;
          default:
            console.log('Unhandled board event: $func');
        }
        return;
      case DuelSelectionMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_SELECT_IDLE_CMD:
            _handleSelectIdleCmd(innerMsg);
            break;
          case MSG_SELECT_BATTLE_CMD:
            _handleSelectBattleCmd(innerMsg);
            break;
          case MSG_SELECT_CARD:
          case MSG_SELECT_CHAIN:
          case MSG_SELECT_EFFECTYN:
          case MSG_SELECT_YES_NO:
          case MSG_SELECT_PLACE:
            _handleSelectGeneric(func, innerMsg);
            break;
          case MSG_SELECT_POSITION:
            _handleSelectPosition(innerMsg as MsgSelectPosition);
            break;
          case MSG_SELECT_TRIBUTE:
            _handleSelectTribute(innerMsg as MsgSelectTribute);
            break;
          case MSG_SELECT_COUNTER:
            _handleSelectCounter(innerMsg as MsgSelectCounter);
            break;
          case MSG_SELECT_SUM:
            _handleSelectSum(innerMsg as MsgSelectSum);
            break;
          case MSG_SORT_CARD:
            _handleSortCard(innerMsg as MsgSortCard);
            break;
          case MSG_SELECT_OPTION:
            _handleSelectOption(innerMsg);
            break;
          case MSG_SELECT_UNSELECT_CARD:
            _handleSelectUnselectCard(innerMsg);
            break;
          case MSG_SELECT_DISFIELD:
            _handleSelectDisfield(innerMsg);
            break;
          default:
            console.log('Unhandled selection event: $func');
        }
    }
  }
  void addLog(String log) {
    duelRoomState.duelLogs.add(log);
    duelRoomState.markChanged();
  }


  void _handleStart(dynamic data) {
    final msg = data as MsgStart;
    final isFirst = msg.isFirst;
    duelBoardStore.myController = isFirst ? 0 : 1;

    duelBoardStore.selfLp = isFirst ? msg.life1 : msg.life2;
    duelBoardStore.opponentLp = isFirst ? msg.life2 : msg.life1;

    duelBoardStore.selfDeck = isFirst ? msg.deckSize1 : msg.deckSize2;
    duelBoardStore.selfExtra = isFirst ? msg.extraSize1 : msg.extraSize2;
    duelBoardStore.oppDeck = isFirst ? msg.deckSize2 : msg.deckSize1;
    duelBoardStore.oppExtra = isFirst ? msg.extraSize2 : msg.extraSize1;

    duelBoardStore.selfHand.clear();
    duelBoardStore.opponentHand.clear();
    duelBoardStore.fieldCards.clear();

    duelBoardStore.turnCount = 1;
    duelBoardStore.phases = [];
    addLog('决斗开始。');
  }

  void _handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    duelBoardStore.currentPlayer = msg.player;
    duelBoardStore.turnCount++;
    duelBoardStore.phases = [];
    final name = waitingRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
      orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
    )
        .name;
    addLog('$name 的回合。');
  }

  void _handleNewPhase(dynamic data) {
    final msg = data as MsgNewPhase;
    duelBoardStore.phase = msg.phase;

    String phaseName = '';
    DuelPhase duelPhase;
    switch (msg.phase) {
      case PHASE_DRAW:
        duelPhase = DuelPhase.dp;
        phaseName = '抽卡阶段';
        break;
      case PHASE_STANDBY:
        duelPhase = DuelPhase.sp;
        phaseName = '准备阶段';
        break;
      case PHASE_MAIN1:
        duelPhase = DuelPhase.m1;
        phaseName = '主要阶段 1';
        selectionStore.enableBp = true;
        selectionStore.enableM2 = false;
        selectionStore.enableEp = true;
        break;
      case PHASE_BATTLE_START:
      case PHASE_BATTLE_STEP:
      case PHASE_DAMAGE:
      case PHASE_DAMAGE_CAL:
      case PHASE_BATTLE:
        duelPhase = DuelPhase.bp;
        phaseName = '战斗阶段';
        break;
      case PHASE_MAIN2:
        duelPhase = DuelPhase.m2;
        phaseName = '主要阶段 2';
        selectionStore.enableBp = false;
        selectionStore.enableM2 = false;
        selectionStore.enableEp = true;
        break;
      case PHASE_END:
        duelPhase = DuelPhase.ep;
        phaseName = '结束阶段';
        break;
      default:
        duelPhase = DuelPhase.idle;
    }
    duelBoardStore.phases.add(duelPhase);
    if (phaseName.isNotEmpty) addLog('$phaseName 开始。');
  }

  void _handleDraw(dynamic data) {
    final msg = data as MsgDraw;
    duelBoardStore.applyDraw(msg);
    final name = waitingRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
      orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
    )
        .name;
    addLog('$name 抽了 ${msg.count} 张卡。');
  }

  void _handleUpdateData(MsgUpdateData msg) {
    duelBoardStore.applyUpdateData(msg);
  }

  void _handleUpdateCard(MsgUpdateCard msg) {
    duelBoardStore.applyUpdateCard(msg);
  }



  void _handleReloadField(MsgReloadField msg) {
    duelBoardStore.applyReloadField(msg);
  }

  void _handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void _handleMove(dynamic data) {
    duelBoardStore.applyMove(data as MsgMove);
  }





  void _handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    duelBoardStore.lastAttackFrom =
    '${msg.attacker.controller}_${msg.attacker.location}_${msg.attacker.sequence}';

    if (msg.target != null) {
      duelBoardStore.lastAttackTo =
      '${msg.target!.controller}_${msg.target!.location}_${msg.target!.sequence}';
    } else {
      duelBoardStore.lastAttackTo = null;
    }
    final attackerName = duelBoardStore.fieldCards[duelBoardStore.lastAttackFrom]?.name ?? '怪兽';
    if (duelBoardStore.lastAttackTo != null) {
      final targetName = duelBoardStore.fieldCards[duelBoardStore.lastAttackTo]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。');
    } else {
      addLog('$attackerName 发动直接攻击。');
    }
  }

  void _handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    if (msg.player == duelBoardStore.myController) {
      duelBoardStore.selfLp -= msg.value;
    } else {
      duelBoardStore.opponentLp -= msg.value;
    }
    final name = waitingRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
      orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
    )
        .name;
    addLog('$name 受到 ${msg.value} 点伤害。');
  }

  void _handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    if (msg.player == duelBoardStore.myController) {
      duelBoardStore.selfLp -= msg.value;
    } else {
      duelBoardStore.opponentLp -= msg.value;
    }
    final name = waitingRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
      orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
    )
        .name;
    addLog('$name 支付了 ${msg.value} 点生命值。');
  }

  void _handleSelectIdleCmd(dynamic data) {
    selectionStore.applyIdleCmd(data as MsgSelectIdleCmd);
  }

  void _handleSelectBattleCmd(dynamic data) {
    selectionStore.applyBattleCmd(data as MsgSelectBattleCmd);
  }

  void _handleSelectGeneric(int func, dynamic data) {
    switch (func) {
      case MSG_SELECT_CARD:
        _handleSelectCard(data as MsgSelectCard);
        break;
      case MSG_SELECT_CHAIN:
        _handleSelectChain(data as MsgSelectChain);
        break;
      case MSG_SELECT_EFFECTYN:
        _handleSelectEffectYn(data as MsgSelectEffectYn);
        break;
      case MSG_SELECT_YES_NO:
        _handleSelectYesNo(data as MsgSelectYesNo);
        break;
      case MSG_SELECT_PLACE:
        _handleSelectPlace(data as MsgSelectPlace);
        break;
      default:
        console.log('Unhandled select message: $func');
    }
  }

  void _handleSelectPlace(MsgSelectPlace msg) {
    selectionStore.applySelectPlace(msg);
  }

  void _handleSelectCard(MsgSelectCard msg) {
    selectionStore.applySelectCard(msg);
  }

  void _handleSelectChain(MsgSelectChain msg) {
    selectionStore.applySelectChain(msg);
  }

  void _handleSelectEffectYn(MsgSelectEffectYn msg) {
    selectionStore.applySelectEffectYn(msg);
  }

  void _handleSelectYesNo(MsgSelectYesNo msg) {
    selectionStore.applySelectYesNo(msg);
  }

  void _handleSelectPosition(MsgSelectPosition msg) {
    selectionStore.applySelectPosition(msg);
  }

  void _handleFieldDisabled(MsgFieldDisabled msg) {
    duelBoardStore.applyFieldDisabled(msg);
    addLog('区域禁用状态已更新。');
  }

  void _handleSelectTribute(MsgSelectTribute msg) {
    selectionStore.applySelectTribute(msg);
  }

  void _handleSelectCounter(MsgSelectCounter msg) {
    selectionStore.applySelectCounter(msg);
  }

  void _handleSelectSum(MsgSelectSum msg) {
    selectionStore.applySelectSum(msg);
  }

  void _handleSortCard(MsgSortCard msg) {
    selectionStore.applySortCard(msg);
  }


  void _handleBattle(MsgBattle msg) {
    duelBoardStore.applyBattle(msg);
    addLog('战斗结算。');
  }

  void _handleChainEnd(dynamic data) {
    duelBoardStore.chains.clear();
  }

  void _handleShuffleHand(dynamic data) {
    duelBoardStore.applyShuffleHand(data as MsgShuffleHand);
  }

  void _handleSelectOption(dynamic data) {
    selectionStore.applySelectOption(data as MsgSelectOption);
  }

  void _handleSelectUnselectCard(dynamic data) {
    selectionStore.applySelectUnselectCard(data as MsgSelectUnselectCard);
  }

  void _handleSelectDisfield(dynamic data) {
    selectionStore.applySelectDisfield(data as MsgSelectPlace);
  }


  void _sendHand(HandType hand) {
    console.log('Sending hand result: $hand');
    _duelService.chooseHand(hand);
    waitingRoomStore.setHandResult(hand.value);
  }

  void _sendTp(bool first) {
    console.log('Sending TP result: ${first ? 'first' : 'second'}');
    _duelService.chooseTurnOrder(first);
    waitingRoomStore.setTpResult(first);
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _duelService.sendChat(text);
    _chatCtrl.clear();
  }


  String _roomTitle(WaitingRoomStore waitingRoomStore, MatchStore match) {
    final modeName = switch (waitingRoomStore.roomOptions?.mode) {
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
    final match = context.watch<MatchStore>();
    if (waitingRoomStore.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(waitingRoomStore.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
          waitingRoomStore.clearError();
        }
      });
    }

    return Scaffold(
      backgroundColor: waitingRoomStore.stage is RoomInDuel
          ? Colors.brown.shade900
          : Colors.blueGrey.shade900,
      appBar: waitingRoomStore.stage is RoomInDuel
          ? null
          : _buildAppBar() as PreferredSizeWidget?,
      body: waitingRoomStore.stage is RoomInDuel
          ? DuelFieldPage()
          : WaitingRoomPage(
              match: match,
              onSendHand: _sendHand,
              onSendTp: _sendTp,
              onKick: (int slot) {
                _duelService.kickPlayer(slot);
              },
              chatCtrl: _chatCtrl,
              chatScrollCtrl: _chatScrollCtrl,
              onSend: _sendChat,
              onSwitchToObserver: () {
                _duelService.becomeObserver();
              },
              onSwitchToDuelist: () {
                _duelService.becomeDuelist();
              },
              onStart: () {
                _duelService.startDuel();
              },
              onToggleAutoHand: (value) =>
                  waitingRoomStore.setAutoHandEnabled(value),
              onToggleAutoTurnOrder: (value) =>
                  waitingRoomStore.setAutoTurnOrderEnabled(value),
            ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          backhome();
        },
      ),
      title: Text(_roomTitle(waitingRoomStore, matchRoomStore)),
      backgroundColor: Colors.blueGrey.shade800,
      foregroundColor: Colors.white,
    );
  }
  void backhome(){
    duelRoomState.reset();
    waitingRoomStore.reset();
    duelBoardStore.reset();
    selectionStore.reset();
    duelChatStore.reset();
    uiStore.reset();
    matchRoomStore.reset();
    context.go('/');
  }

  @override
  void dispose() {
    if (_duelService.connectionState == duel.ConnectionState.connected) {
      _duelService.surrender();
    }
    _duelService.surrender();
    _duelService.disconnect();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _roomStageSub?.cancel();
    _msgSub?.cancel();
    _chatMsgSub?.cancel();
    super.dispose();
    console.log('DuelRoomPage disposed and disconnected from server.');
  }
}
