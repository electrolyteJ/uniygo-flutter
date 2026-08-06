import 'dart:async';
import 'dart:developer' as console;
import 'package:duelink/duelink.dart' as duel;
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/pages/duel_room/waiting/waiting_room_page.dart';
import '../../constants.dart';
import '../../service_singleton.dart';
import 'duel/duel_field_store.dart';
import 'duel/duel_field_page.dart';
import 'waiting/duel_chat_store.dart';
import 'duel_room_store.dart';
import '../create_room/match_store.dart';
import '../../models/duel_event.dart';
import '../../eventbus/duel_event_mapper.dart';
import '../../widgets/shared/duel_room.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key});

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceSingleton.instance.duelService;

  StreamSubscription<YgoStocMsg>? _msgSub;

  late final DuelRoomStore duelRoomStore;
  late final DuelChatStore duelChatStore;
  late final DuelFieldStore duelStore;
  late final MatchStore matchRoomStore;

  @override
  void initState() {
    super.initState();
    duelRoomStore = context.read<DuelRoomStore>();
    duelRoomStore.bind(_duelService);
    duelChatStore = context.read<DuelChatStore>();
    duelChatStore.bind(_duelService);
    duelStore = context.read<DuelFieldStore>();
    duelStore.bind(_duelService);
    matchRoomStore = context.read<MatchStore>();
    _connect();
  }

  Future<void> _connect() async {
    final host = matchRoomStore.serverAddress;
    final port = matchRoomStore.serverPort;
    final env = matchRoomStore.environment;
    final password = matchRoomStore.serverPassword;
    if (host == null || port == null) {
      console.log('Server address or port is null');
      return;
    }
    final uri = Uri.tryParse('${env.schema}://$host:$port');
    if (uri == null) return;

    // connect() 必须在流订阅之前调用，否则 DuelService 门面会把订阅
    // 路由到默认的 WebSocket 服务（而不是 AI/TCP 等目标协议）。
    await _duelService.connect(uri);

    duelRoomStore.bindRoomStageChange(context);
    _duelService.onDuelPhaseMessage.listen((phase) {
      _handleNewPhase(phase);
      duelStore.markChanged();
    });
    _msgSub = _duelService.onServerMessage.listen((msg) {
      console.log('Received server message: $msg');
      _onMessage(msg);
      if (msg.errorMsg != null) {
        final err = msg.errorMsg!;
        duelStore.setError(err.errorType, err.errorCode);
      }
    });

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
    duelRoomStore.markChanged();
    duelStore.markChanged();
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
            final name = duelStore.handleChaining(innerMsg);
            addLog('连锁发动 $name。');
            break;
          case MSG_CHAIN_END:
            _handleChainEnd(innerMsg);
            break;
          case MSG_SUMMONING:
            final name = duelStore.handleSummoning(innerMsg);
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
            final card = duelStore.handlePosChange(innerMsg);
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
    duelRoomStore.duelLogs.add(log);
    duelRoomStore.markChanged();
  }

  void _handleStart(dynamic data) {
    final msg = data as MsgStart;
    final isFirst = msg.isFirst;
    duelStore.myController = isFirst ? 0 : 1;

    duelStore.selfLp = isFirst ? msg.life1 : msg.life2;
    duelStore.opponentLp = isFirst ? msg.life2 : msg.life1;

    duelStore.selfDeck = isFirst ? msg.deckSize1 : msg.deckSize2;
    duelStore.selfExtra = isFirst ? msg.extraSize1 : msg.extraSize2;
    duelStore.oppDeck = isFirst ? msg.deckSize2 : msg.deckSize1;
    duelStore.oppExtra = isFirst ? msg.extraSize2 : msg.extraSize1;

    duelStore.selfHand.clear();
    duelStore.opponentHand.clear();
    duelStore.fieldCards.clear();

    duelStore.turnCount = 1;
    addLog('决斗开始。');
  }

  void _handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    duelStore.currentPlayer = msg.player;
    duelStore.turnCount++;
    final name = duelRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => PlayerInfo(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 的回合。');
  }

  void _handleNewPhase(DuelPhase duelPhase) {
    duelStore.phase = duelPhase;
    // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
    // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
    final phaseName = getDuelPhaseText(context, duelPhase);
    if (phaseName?.isNotEmpty == true) addLog('$phaseName 开始。');
  }

  void _handleDraw(dynamic data) {
    final msg = data as MsgDraw;
    duelStore.applyDraw(msg);
    final name = duelRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => PlayerInfo(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 抽了 ${msg.count} 张卡。');
  }

  void _handleUpdateData(MsgUpdateData msg) {
    duelStore.applyUpdateData(msg);
  }

  void _handleUpdateCard(MsgUpdateCard msg) {
    duelStore.applyUpdateCard(msg);
  }

  void _handleReloadField(MsgReloadField msg) {
    duelStore.applyReloadField(msg);
  }

  void _handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void _handleMove(dynamic data) {
    duelStore.applyMove(data as MsgMove);
  }

  void _handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    duelStore.lastAttackFrom =
        '${msg.attacker.controller}_${msg.attacker.location}_${msg.attacker.sequence}';

    if (msg.target != null) {
      duelStore.lastAttackTo =
          '${msg.target!.controller}_${msg.target!.location}_${msg.target!.sequence}';
    } else {
      duelStore.lastAttackTo = null;
    }
    final attackerName =
        duelStore.fieldCards[duelStore.lastAttackFrom]?.name ?? '怪兽';
    if (duelStore.lastAttackTo != null) {
      final targetName =
          duelStore.fieldCards[duelStore.lastAttackTo]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。');
    } else {
      addLog('$attackerName 发动直接攻击。');
    }
  }

  void _handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    if (msg.player == duelStore.myController) {
      duelStore.selfLp -= msg.value;
    } else {
      duelStore.opponentLp -= msg.value;
    }
    final name = duelRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => PlayerInfo(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 受到 ${msg.value} 点伤害。');
  }

  void _handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    if (msg.player == duelStore.myController) {
      duelStore.selfLp -= msg.value;
    } else {
      duelStore.opponentLp -= msg.value;
    }
    final name = duelRoomStore.players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => PlayerInfo(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 支付了 ${msg.value} 点生命值。');
  }

  void _handleSelectIdleCmd(dynamic data) {
    duelStore.applyIdleCmd(data as MsgSelectIdleCmd);
  }

  void _handleSelectBattleCmd(dynamic data) {
    duelStore.applyBattleCmd(data as MsgSelectBattleCmd);
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
    duelStore.applySelectPlace(msg);
  }

  void _handleSelectCard(MsgSelectCard msg) {
    duelStore.applySelectCard(msg);
  }

  void _handleSelectChain(MsgSelectChain msg) {
    duelStore.applySelectChain(msg);
  }

  void _handleSelectEffectYn(MsgSelectEffectYn msg) {
    duelStore.applySelectEffectYn(msg);
  }

  void _handleSelectYesNo(MsgSelectYesNo msg) {
    duelStore.applySelectYesNo(msg);
  }

  void _handleSelectPosition(MsgSelectPosition msg) {
    duelStore.applySelectPosition(msg);
  }

  void _handleFieldDisabled(MsgFieldDisabled msg) {
    duelStore.applyFieldDisabled(msg);
    addLog('区域禁用状态已更新。');
  }

  void _handleSelectTribute(MsgSelectTribute msg) {
    duelStore.applySelectTribute(msg);
  }

  void _handleSelectCounter(MsgSelectCounter msg) {
    duelStore.applySelectCounter(msg);
  }

  void _handleSelectSum(MsgSelectSum msg) {
    duelStore.applySelectSum(msg);
  }

  void _handleSortCard(MsgSortCard msg) {
    duelStore.applySortCard(msg);
  }

  void _handleBattle(MsgBattle msg) {
    duelStore.applyBattle(msg);
    addLog('战斗结算。');
  }

  void _handleChainEnd(dynamic data) {
    duelStore.chains.clear();
  }

  void _handleShuffleHand(dynamic data) {
    duelStore.applyShuffleHand(data as MsgShuffleHand);
  }

  void _handleSelectOption(dynamic data) {
    duelStore.applySelectOption(data as MsgSelectOption);
  }

  void _handleSelectUnselectCard(dynamic data) {
    duelStore.applySelectUnselectCard(data as MsgSelectUnselectCard);
  }

  void _handleSelectDisfield(dynamic data) {
    duelStore.applySelectDisfield(data as MsgSelectPlace);
  }

  String _roomTitle(DuelRoomStore duelRoomStore, MatchStore match) {
    final modeName = switch (duelRoomStore.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛',
      RoomMode.tag => '双打',
      _ => '',
    };
    if (match.roomName.isNotEmpty) return match.roomName;
    return '$modeName房间';
  }

  @override
  Widget build(BuildContext context) {
    final duel = context.watch<DuelRoomStore>();
    final matchRoomStore = context.watch<MatchStore>();
    if (duelStore.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(duelStore.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
          duelStore.clearError();
        }
      });
    }
    return Scaffold(
      backgroundColor: duel.stage is RoomInDuel
          ? Colors.brown.shade900
          : Colors.blueGrey.shade900,
      appBar: duel.stage is RoomInDuel
          ? null
          : _buildAppBar(duelRoomStore, matchRoomStore) as PreferredSizeWidget?,
      body: duel.stage is RoomInDuel ? DuelFieldPage() : WaitingRoomPage(),
    );
  }

  Widget _buildAppBar(DuelRoomStore duelRoomStore, MatchStore matchRoomStore) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          backHomeDialog(
            context: context,
            title: '退出房间',
            content: '是否确认退出当前房间？',
          );
        },
      ),
      title: Text(_roomTitle(duelRoomStore, matchRoomStore)),
      backgroundColor: Colors.blueGrey.shade800,
      foregroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    if (_duelService.connectionState == duel.ConnectionState.connected) {
      _duelService.surrender();
    }
    _duelService.disconnect();
    _msgSub?.cancel();
    super.dispose();
    console.log('DuelRoomPage disposed and disconnected from server.');
  }
}
