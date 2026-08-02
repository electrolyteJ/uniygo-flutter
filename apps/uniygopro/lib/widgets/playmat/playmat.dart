import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:provider/provider.dart';
import 'package:ygo_card/card_info.dart';
import '../../models/IdleAction.dart';
import '../../models/SelectState.dart';
import '../../stores/duel_board_store.dart';
import '../../stores/duel_room_state.dart';
import '../../stores/duel_selection_store.dart';
import '../../stores/duel_ui_store.dart';
import 'card_detail_drawer.dart';
import 'chain_stack_overlay.dart';
import 'duel_log_drawer.dart';
import 'flame/duel_flame_game.dart';
import 'hand_action_menu.dart';
import 'hand_cards_bar.dart';
import 'phase_bar.dart';
import 'player_status_card.dart';
import 'zone_browser_modal.dart';

class Playmat extends StatefulWidget {
  const Playmat({super.key});

  @override
  State<Playmat> createState() => _PlaymatState();
}

class _PlaymatState extends State<Playmat> {
  late final DuelBoardStore boardState;
  late final DuelSelectionStore selectionState;
  late final DuelUiStore uiState;
  static const int _locationHand = 0x02;
  int? _inspectedCardCode;
  CardInfo? _inspectedCardInfo;
  int? _selectedHandCardCode;
  String? _openZoneBrowserKey;
  bool _showInspector = true;
  late DuelFlameGame _flameGame;

  @override
  void initState() {
    super.initState();
    boardState = context.read<DuelBoardStore>();
    selectionState = context.read<DuelSelectionStore>();
    uiState = context.read<DuelUiStore>();
    _flameGame = DuelFlameGame(
      boardState: boardState,
      onCardSelect: (fieldCard, code) {
        if (code != null) {
          _inspectCard(code);
        } else if (fieldCard != null) {
          _inspectCard(fieldCard.code);
        }
      },
      onZoneInspect: _handleZoneInspect,
    );
  }

  void _inspectCard(
    int? code, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code == null || code <= 0) return;
    setState(() {
      uiState.clearInspectedZone();
      _inspectedCardCode = code;
      _inspectedCardInfo = boardState.getCardInfo(code);
      if (!preserveHandSelection) {
        _selectedHandCardCode = null;
      }
      if (!preserveZoneBrowser) {
        _openZoneBrowserKey = null;
      }
      _showInspector = true;
    });
  }

  void _inspectZone(String zoneKey) {
    setState(() {
      uiState.inspectZone(zoneKey);
      _inspectedCardCode = null;
      _inspectedCardInfo = null;
      _showInspector = true;
    });
  }

  void _handleHandCardTap(int code) {
    setState(() {
      _selectedHandCardCode = code;
      _openZoneBrowserKey = null;
    });
    _inspectCard(code, preserveHandSelection: true);
  }

  void _handleHandCardDoubleTap(int code) {
    final action = _defaultHandActionFor(code);
    if (action == null) {
      _handleHandCardTap(code);
      return;
    }
    setState(() {
      _selectedHandCardCode = null;
      _openZoneBrowserKey = null;
    });
    selectionState.respondIdleCmd(action.sequence);
  }

  void _clearHandSelection() {
    if (_selectedHandCardCode == null) return;
    setState(() {
      _selectedHandCardCode = null;
    });
  }

  void _openZoneBrowser(String zoneKey) {
    setState(() {
      uiState.clearInspectedZone();
      _selectedHandCardCode = null;
      _openZoneBrowserKey = zoneKey;
      _showInspector = true;
    });
  }

  void _closeZoneBrowser() {
    setState(() {
      _openZoneBrowserKey = null;
    });
  }

  void _inspectZoneBrowserCard(int code) {
    _inspectCard(code, preserveZoneBrowser: true);
  }

  void _handleZoneInspect(String zoneKey) {
    if (zoneKey == 'self_extra' || zoneKey == 'opp_extra') {
      _openZoneBrowser(zoneKey);
      return;
    }
    _inspectZone(zoneKey);
  }

  List<IdleAction> _handActionsForCurrentSelection() {
    final selectedCode = _selectedHandCardCode;
    final select = selectionState.currentSelect;
    if (selectedCode == null ||
        select == null ||
        select.type != SelectType.idleCmd ||
        select.player != boardState.myController) {
      return const [];
    }

    return selectionState.selectedIdleActions
        .where(
          (action) =>
              action.code == selectedCode &&
              action.controller == boardState.myController &&
              action.location == _locationHand,
        )
        .toList();
  }

  IdleAction? _defaultHandActionFor(int code) {
    final actions = _handActionsForCode(code);
    if (actions.isEmpty) return null;

    final cardInfo = boardState.getCardInfo(code);
    final priorities = cardInfo?.isMonster == true
        ? const [0, 1, 3]
        : const [5, 4];

    for (final type in priorities) {
      for (final action in actions) {
        if (action.type == type) {
          return action;
        }
      }
    }
    return actions.first;
  }

  List<IdleAction> _handActionsForCode(int code) {
    final select = selectionState.currentSelect;
    if (select == null ||
        select.type != SelectType.idleCmd ||
        select.player != boardState.myController) {
      return const [];
    }
    return selectionState.selectedIdleActions
        .where(
          (action) =>
              action.code == code &&
              action.controller == boardState.myController &&
              action.location == _locationHand,
        )
        .toList();
  }

  Set<int> _tappablePhaseCodes() {
    final board = boardState;
    final selection = selectionState;
    final select = selection.currentSelect;
    if (select == null || select.player != board.myController) {
      return const <int>{};
    }

    switch (select.type) {
      case SelectType.idleCmd:
        return {
          if (selection.enableBp) PHASE_BATTLE_START,
          if (selection.enableEp) PHASE_END,
        };
      case SelectType.battleCmd:
        return {
          if (selection.enableM2) PHASE_MAIN2,
          if (selection.enableEp) PHASE_END,
        };
      default:
        return const <int>{};
    }
  }

  void _handlePhaseTap(int phaseCode) {
    final board = boardState;
    final selection = selectionState;
    final select = selection.currentSelect;
    if (select == null || select.player != board.myController) {
      return;
    }

    if (select.type == SelectType.idleCmd) {
      if (phaseCode == PHASE_BATTLE_START && selection.enableBp) {
        selectionState.respondIdleCmd(6);
      } else if (phaseCode == PHASE_END && selection.enableEp) {
        selectionState.respondIdleCmd(7);
      }
      _clearHandSelection();
      return;
    }

    if (select.type == SelectType.battleCmd) {
      if (phaseCode == PHASE_MAIN2 && selection.enableM2) {
        selectionState.respondBattleCmd(2);
      } else if (phaseCode == PHASE_END && selection.enableEp) {
        selectionState.respondBattleCmd(3);
      }
      _clearHandSelection();
    }
  }

  List<HandActionMenuEntry> _buildHandActionMenuEntries() {
    final cardInfo = _selectedHandCardCode == null
        ? null
        : boardState.getCardInfo(_selectedHandCardCode!);
    return _handActionsForCurrentSelection()
        .map(
          (action) => HandActionMenuEntry(
            label: _idleActionLabel(action, cardInfo),
            onTap: () {
              setState(() {
                _selectedHandCardCode = null;
              });
              selectionState.respondIdleCmd(action.sequence);
            },
          ),
        )
        .toList();
  }

  String _idleActionLabel(IdleAction action, CardInfo? cardInfo) {
    final isSpellTrap = cardInfo?.isSpell == true || cardInfo?.isTrap == true;
    switch (action.type) {
      case 0:
        return '召唤';
      case 1:
        return '特殊召唤';
      case 2:
        return '改变表示形式';
      case 3:
        return '盖放';
      case 4:
        return '盖放';
      case 5:
        return isSpellTrap ? '发动' : '发动效果';
      default:
        return '行动 #${action.sequence}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final duelState = context.watch<DuelRoomState>();
    final boardState = context.watch<DuelBoardStore>();
    final selectionState = context.watch<DuelSelectionStore>();
    final uiState = context.watch<DuelUiStore>();
    final isMyTurn = boardState.currentPlayer == boardState.myController;
    final zoneBrowserKey = _openZoneBrowserKey;
    final zoneBrowserCodes = zoneBrowserKey == null
        ? const <int>[]
        : boardState.getZoneCodes(zoneBrowserKey).where((code) => code > 0).toList();
    final handActionEntries = _buildHandActionMenuEntries();

    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      body: Stack(
        children: [
          // 1. 底层线性渐变 (linear-gradient(to bottom, #020408, #070c16, #020407))
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF020408),
                    Color(0xFF070C16),
                    Color(0xFF020407),
                  ],
                ),
              ),
            ),
          ),
          // 2. 顶部青色径向光晕 (radial-gradient(circle at 50% 35%, rgba(0, 240, 255, 0.16) 0%, transparent 60%))
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.3),
                  radius: 1.2,
                  colors: [Color(0x2900F0FF), Colors.transparent],
                ),
              ),
            ),
          ),
          // 3. 底部紫色径向光晕 (radial-gradient(circle at 50% 85%, rgba(176, 38, 255, 0.12) 0%, transparent 50%))
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.7),
                  radius: 1.0,
                  colors: [Color(0x1FAD26FF), Colors.transparent],
                ),
              ),
            ),
          ),

          // 4. 内容层
          Column(
            children: [
              // 4.1 顶部阶段栏 (matches .header-bar)
              PhaseBar(
                tappablePhaseCodes: _tappablePhaseCodes(),
                onPhaseTap: _handlePhaseTap,
              ),

              Expanded(
                child: Row(
                  children: [
                    // 4.2 左侧卡片检查器 (matches .inspector-panel, width: 250px)
                    if (_showInspector)
                      CardDetailDrawer(
                        cardInfo: _inspectedCardInfo,
                        cardCode: _inspectedCardCode,
                        titleOverride: uiState.inspectedZoneKey == null
                            ? null
                            : _zoneTitle(uiState.inspectedZoneKey!),
                        extraLines: uiState.inspectedZoneKey == null
                            ? null
                            : boardState.getZoneCodes(uiState.inspectedZoneKey!)
                                  .where((code) => code > 0)
                                  .map(
                                    (code) =>
                                        boardState.getCardInfo(code)?.name ??
                                        'Card #$code',
                                  )
                                  .toList(),
                        onClose: () => setState(() => _showInspector = false),
                      ),

                    // 4.3 主战场区域
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 3D 战场地毯渲染
                          Positioned.fill(child: GameWidget(game: _flameGame)),

                          // 悬浮 HUD: 对方 (matches .compact-player-hud.top-opponent)
                          Positioned(
                            top: 14,
                            left: 16,
                            child: PlayerStatusCard(
                              name: '海马濑人',
                              lp: boardState.opponentLp,
                              isSelf: false,
                              isActiveTurn: !isMyTurn,
                              deckCount: boardState.oppDeck,
                              extraCount: boardState.oppExtra,
                              graveCount: boardState.oppGrave,
                              removedCount: boardState.oppRemoved,
                              onExtraTap: () => _openZoneBrowser('opp_extra'),
                              onGraveTap: () => _openZoneBrowser('opp_grave'),
                              onRemovedTap: () => _inspectZone('opp_removed'),
                            ),
                          ),

                          // 悬浮 HUD: 决斗日志 (matches .battle-log-drawer)
                          Positioned(
                            top: 14,
                            right: 16,
                            child: DuelLogDrawer(logs: duelState.duelLogs),
                          ),

                          // 屏幕中央连锁显示 (matches .chain-stack-indicator)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ChainStackOverlay(chains: boardState.chains),
                            ),
                          ),

                          // 悬浮 HUD: 己方 (matches .compact-player-hud.bottom-self)
                          Positioned(
                            bottom: 84, // 位于手牌轨道上方
                            left: 16,
                            child: PlayerStatusCard(
                              name: '武藤游戏',
                              lp: boardState.selfLp,
                              isSelf: true,
                              isActiveTurn: isMyTurn,
                              deckCount: boardState.selfDeck,
                              extraCount: boardState.selfExtra,
                              graveCount: boardState.selfGrave,
                              removedCount: boardState.selfRemoved,
                              onExtraTap: () => _openZoneBrowser('self_extra'),
                              onGraveTap: () => _openZoneBrowser('self_grave'),
                              onRemovedTap: () => _inspectZone('self_removed'),
                            ),
                          ),

                          // 弧形手牌栏 (matches .hand-arc-rail, height: 84px)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: HandCardsBar(
                              handCodes: boardState.selfHand,
                              selectedCardCode: _selectedHandCardCode,
                              onCardTap: _handleHandCardTap,
                              onCardDoubleTap: _handleHandCardDoubleTap,
                            ),
                          ),

                          if (handActionEntries.isNotEmpty)
                            Positioned(
                              top: 96,
                              right: 16,
                              child: HandActionMenu(actions: handActionEntries),
                            ),

                          Positioned(
                            bottom: 18,
                            right: 16,
                            child: IgnorePointer(
                              ignoring: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  selectionState.currentSelect?.player ==
                                          boardState.myController
                                      ? '等待你的操作'
                                      : '等待对手操作',
                                  style: const TextStyle(
                                    color: Color(0xFF8B9BB4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (zoneBrowserKey != null)
            ZoneBrowserModal(
              title: _zoneTitle(zoneBrowserKey),
              cardCodes: zoneBrowserCodes,
              selectedCardCode: _inspectedCardCode,
              onCardTap: _inspectZoneBrowserCard,
              onClose: _closeZoneBrowser,
              cardNameBuilder: (code) =>
                  boardState.getCardInfo(code)?.name ?? 'Card #$code',
            ),
        ],
      ),
    );
  }

  String _zoneTitle(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
        return '己方墓地';
      case 'opp_grave':
        return '对手墓地';
      case 'self_removed':
        return '己方除外';
      case 'opp_removed':
        return '对手除外';
      case 'self_extra':
        return '己方额外';
      case 'opp_extra':
        return '对手额外';
      default:
        return '区域详情';
    }
  }
}
