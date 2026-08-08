// ────────────────────────────────────────────────────────────
// AI Room Sheet (人机对战入口 + 房间参数)
// ────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/servers.dart';
import '../../widgets/shared/create_room.dart';
import 'match_store.dart';

/// AI 对决面板 — 选择房间参数后进入本地人机对战，无需联网。
class AiRoomSheet extends StatefulWidget {
  final GameServer server;
  const AiRoomSheet({super.key, required this.server});

  @override
  State<AiRoomSheet> createState() => _AiRoomSheetState();
}

class _AiRoomSheetState extends State<AiRoomSheet> {
  int _startLp = 8000;
  int _startHand = 5;
  int _drawCount = 1;
  int _rule = 0;
  DuelRule _duelRule = DuelRule.mr2020;
  int _timeLimit = 180;
  bool _noCheckDeck = true;
  bool _noShuffleDeck = true;
  bool _connecting = false;

  Future<void> _start() async {
    final matchStore = context.read<MatchStore>();
    final options = RoomOptions(
      mode: RoomMode.single,
      rule: _rule,
      duelRule: _duelRule,
      noCheckDeck: _noCheckDeck,
      noShuffleDeck: _noShuffleDeck,
      startLp: _startLp,
      startHand: _startHand,
      drawCount: _drawCount,
      timeLimit: _timeLimit,
    );
    setState(() => _connecting = true);
    matchStore.configureCreatedRoom(
      roomOptions: options,
      roomName: 'AI 人机对战',
    );
    matchStore.selectServer(widget.server, DuelEnvironment.ai, RoomPassword.encodeJoin());
    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: sheetContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.maxHeight.isFinite;
            final availableBodyHeight = hasBoundedHeight
                ? math.max(240.0, constraints.maxHeight - 116.0)
                : 520.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.server.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.server.description,
                  style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: availableBodyHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '与本地 AI 进行一场单局对战，无需联网。',
                          style: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        numberRow(
                          '初始 LP',
                          _startLp,
                          (v) => setState(() => _startLp = v),
                        ),
                        numberRow(
                          '初始手牌',
                          _startHand,
                          (v) => setState(() => _startHand = v),
                        ),
                        numberRow(
                          '每回合抽卡',
                          _drawCount,
                          (v) => setState(() => _drawCount = v),
                        ),
                        const SizedBox(height: 6),
                        dropdownRow<int>(
                          label: '卡片允许',
                          value: _rule,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('OCG')),
                            DropdownMenuItem(value: 1, child: Text('TCG')),
                            DropdownMenuItem(value: 2, child: Text('OT 混')),
                            DropdownMenuItem(value: 3, child: Text('自制卡')),
                            DropdownMenuItem(value: 4, child: Text('专有卡禁止')),
                            DropdownMenuItem(value: 5, child: Text('所有卡片')),
                          ],
                          onChanged: (v) => setState(() => _rule = v!),
                        ),
                        dropdownRow<DuelRule>(
                          label: '决斗规则',
                          value: _duelRule,
                          items: const [
                            DropdownMenuItem(
                              value: DuelRule.mr3,
                              child: Text('大师规则 3 (2014)'),
                            ),
                            DropdownMenuItem(
                              value: DuelRule.mr4,
                              child: Text('新大师规则 (2017)'),
                            ),
                            DropdownMenuItem(
                              value: DuelRule.mr2020,
                              child: Text('大师规则 2020'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _duelRule = v!),
                        ),
                        dropdownRow<int>(
                          label: '时间限制',
                          value: _timeLimit,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('无限制')),
                            DropdownMenuItem(value: 180, child: Text('3 分钟')),
                            DropdownMenuItem(value: 240, child: Text('4 分钟')),
                            DropdownMenuItem(value: 300, child: Text('5 分钟')),
                            DropdownMenuItem(value: 600, child: Text('10 分钟')),
                          ],
                          onChanged: (v) => setState(() => _timeLimit = v!),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            checkRow(
                              '不检查卡组',
                              _noCheckDeck,
                              (v) => setState(() => _noCheckDeck = v ?? false),
                            ),
                            const SizedBox(width: 16),
                            checkRow(
                              '不切洗卡组',
                              _noShuffleDeck,
                              (v) => setState(() => _noShuffleDeck = v ?? false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        connectButton(
                          label: '开始人机对战',
                          connecting: _connecting,
                          onPressed: () => _start(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
