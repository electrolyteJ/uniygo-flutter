import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ygo_card/card_info.dart';
import '../../stores/duel_room_state.dart';
import 'card_detail_drawer.dart';
import 'player_status_card.dart';
import 'phase_bar.dart';
import 'hand_cards_bar.dart';
import 'duel_log_drawer.dart';
import 'cyber_button.dart';
import 'chain_stack_overlay.dart';
import 'flame/duel_flame_game.dart';

class Playmat extends StatefulWidget {
  final DuelRoomState duel;

  const Playmat({super.key, required this.duel});

  @override
  State<Playmat> createState() => _PlaymatState();
}

class _PlaymatState extends State<Playmat> {
  int? _inspectedCardCode;
  CardInfo? _inspectedCardInfo;
  bool _showInspector = true;
  bool _showActionModal = false;
  late DuelFlameGame _flameGame;

  @override
  void initState() {
    super.initState();
    _flameGame = DuelFlameGame(
      duel: widget.duel,
      onCardSelect: (fieldCard, code) {
        if (code != null) {
          _inspectCard(code);
        } else if (fieldCard != null) {
          _inspectCard(fieldCard.code);
        }
      },
    );
  }

  void _inspectCard(int? code) {
    if (code == null || code <= 0) return;
    setState(() {
      _inspectedCardCode = code;
      _inspectedCardInfo = widget.duel.getCardInfo(code);
      _showInspector = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final duel = widget.duel;
    final isMyTurn = duel.currentPlayer == duel.myController;

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
                  colors: [Color(0xFF020408), Color(0xFF070C16), Color(0xFF020407)],
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
              PhaseBar(duel: duel),
              
              Expanded(
                child: Row(
                  children: [
                    // 4.2 左侧卡片检查器 (matches .inspector-panel, width: 250px)
                    if (_showInspector)
                      CardDetailDrawer(
                        cardInfo: _inspectedCardInfo,
                        cardCode: _inspectedCardCode,
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
                              lp: duel.opponentLp,
                              isSelf: false,
                              isActiveTurn: !isMyTurn,
                              deckCount: duel.oppDeck,
                              extraCount: duel.oppExtra,
                              graveCount: duel.oppGrave,
                              removedCount: duel.oppRemoved,
                            ),
                          ),

                          // 悬浮 HUD: 决斗日志 (matches .battle-log-drawer)
                          Positioned(
                            top: 14,
                            right: 16,
                            child: DuelLogDrawer(logs: duel.duelLogs),
                          ),

                          // 屏幕中央连锁显示 (matches .chain-stack-indicator)
                          Positioned.fill(
                            child: IgnorePointer(child: ChainStackOverlay(chains: duel.chains)),
                          ),

                          // 悬浮 HUD: 己方 (matches .compact-player-hud.bottom-self)
                          Positioned(
                            bottom: 84, // 位于手牌轨道上方
                            left: 16,
                            child: PlayerStatusCard(
                              name: '武藤游戏',
                              lp: duel.selfLp,
                              isSelf: true,
                              isActiveTurn: isMyTurn,
                              deckCount: duel.selfDeck,
                              extraCount: duel.selfExtra,
                              graveCount: duel.selfGrave,
                              removedCount: duel.selfRemoved,
                            ),
                          ),

                          // 弧形手牌栏 (matches .hand-arc-rail, height: 84px)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: HandCardsBar(
                              handCodes: duel.selfHand,
                              selectedCardCode: _inspectedCardCode,
                              onCardTap: (code) => _inspectCard(code),
                            ),
                          ),

                          // 行动控制面板 (matches .action-command-panel)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Row(
                              children: [
                                CyberButton(
                                  label: '❖ 行动指令', 
                                  isPrimary: true, 
                                  onTap: () => setState(() => _showActionModal = true),
                                ),
                                const SizedBox(width: 8),
                                CyberButton(label: 'BP', isPrimary: false, onTap: () {}),
                                const SizedBox(width: 8),
                                CyberButton(label: 'EP', isPrimary: false, onTap: () {}),
                              ],
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

          // 5. 模态行动弹窗 (matches .action-modal-overlay)
          if (_showActionModal)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showActionModal = false),
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {}, 
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xF2080C14), 
                            border: Border.all(color: const Color(0xFF00F0FF), width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withOpacity(0.5),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '❖ 请选择行动',
                                style: TextStyle(
                                  color: Color(0xFF00F0FF),
                                  fontFamily: 'Orbitron',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildModalOption('通常召唤'),
                              const SizedBox(height: 10),
                              _buildModalOption('特殊召唤'),
                              const SizedBox(height: 10),
                              _buildModalOption('发动卡片效果'),
                              const SizedBox(height: 10),
                              _buildModalOption('盖放卡片'),
                              const SizedBox(height: 10),
                              CyberButton(
                                label: '取消', 
                                isPrimary: false, 
                                width: double.infinity,
                                onTap: () => setState(() => _showActionModal = false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModalOption(String label) {
    return CyberButton(
      label: label,
      isPrimary: true,
      width: double.infinity,
      onTap: () => setState(() => _showActionModal = false),
    );
  }
}
