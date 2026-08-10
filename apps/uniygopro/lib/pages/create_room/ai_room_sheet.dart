// ────────────────────────────────────────────────────────────
// AI Room Sheet (人机对战入口 + 房间参数)
// ────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/servers.dart';
import '../../widgets/shared/create_room.dart';
import 'match_store.dart';

/// AI 类型选择
enum _AiType {
  local('本地 AI', '与本地 AI 进行一场单局对战，无需联网。'),
  server233('233 服 AI', '连接 ygo233.com 服务器，与服务器端 AI 对战。');

  final String label;
  final String description;
  const _AiType(this.label, this.description);
}

/// AI 对决面板 — 选择房间参数后进入人机对战。
class AiRoomSheet extends StatefulWidget {
  final GameServer server;
  const AiRoomSheet({super.key, required this.server});

  @override
  State<AiRoomSheet> createState() => _AiRoomSheetState();
}

class _AiRoomSheetState extends State<AiRoomSheet> {
  _AiType _aiType = _AiType.local;
  int _startLp = 8000;
  int _startHand = 5;
  int _drawCount = 1;
  int _rule = 0;
  DuelRule _duelRule = DuelRule.mr2020;
  int _timeLimit = 180;
  bool _noCheckDeck = true;
  bool _noShuffleDeck = false;
  bool _connecting = false;

  /// 为 233 服 AI 生成 mercury233 兼容房间串。
  String _build233RoomString() {
    final codes = <String>[
      // 单局模式不输出特殊标记
      switch (_duelRule) {
        DuelRule.mr3 => 'MR3',
        DuelRule.mr4 => 'MR4',
        DuelRule.mr2020 => 'MR5',
      },
      switch (_rule) {
        0 => '', // OCG (默认)
        1 => 'TO', // 仅 TCG
        2 => 'OT', // OT 混
        4 => 'NU', // 专有卡禁止
        _ => '', // 自制卡/所有卡片 → 默认
      },
      if (_timeLimit != 0 && _timeLimit != 180) 'TM$_timeLimit',
      if (_startLp != 8000) 'LP$_startLp',
      if (_startHand != 5) 'ST$_startHand',
      if (_drawCount != 1) 'DR$_drawCount',
      if (_noCheckDeck) 'NC',
      if (_noShuffleDeck) 'NS',
    ]..removeWhere((code) => code.isEmpty);

    final prefix = codes.isEmpty ? '' : '${codes.join(',')}#';
    return '$prefix${'AI 人机对战'}';
  }

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

    if (_aiType == _AiType.local) {
      matchStore.configureCreatedRoom(
        roomOptions: options,
        roomName: 'AI 人机对战',
      );
      matchStore.selectServer(
        widget.server,
        DuelEnvironment.ai,
        RoomPassword.encodeJoin(),
      );
    } else {
      // 233 服 AI：使用 mercury233 环境，房间串作为密码。
      final roomString = _build233RoomString();
      matchStore.configureCreatedRoom(
        roomOptions: options,
        roomName: 'AI 人机对战',
      );
      matchStore.selectServer(
        widget.server,
        DuelEnvironment.mercury233,
        roomString,
      );
    }
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
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                // ── AI 类型选择器 ──
                _aiTypeSelector(),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: availableBodyHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _aiType.description,
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
                          max: 65535,
                        ),
                        numberRow(
                          '初始手牌',
                          _startHand,
                          (v) => setState(() => _startHand = v),
                          max: 15,
                        ),
                        numberRow(
                          '每回合抽卡',
                          _drawCount,
                          (v) => setState(() => _drawCount = v),
                          max: 15,
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
                              (v) =>
                                  setState(() => _noShuffleDeck = v ?? false),
                            ),
                          ],
                        ),
                        // ── 233 服 AI 房间串预览 ──
                        if (_aiType == _AiType.server233) ...[
                          const SizedBox(height: 10),
                          _roomStringPreview(),
                        ],
                        const SizedBox(height: 16),
                        connectButton(
                          key: _aiType == _AiType.local
                              ? const ValueKey('ai-room-start-local')
                              : const ValueKey('ai-room-start-server233'),
                          label: _aiType == _AiType.local
                              ? '开始人机对战'
                              : '连接 233 服 AI',
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

  /// Web 端不支持 TCP Socket，过滤掉 233 服 AI。
  List<_AiType> get _availableAiTypes =>
      kIsWeb ? [_AiType.local] : _AiType.values;

  // ── AI 类型分段选择器 ──
  Widget _aiTypeSelector() {
    final types = _availableAiTypes;
    // 仅单个选项时隐藏选择器
    if (types.length <= 1) return const SizedBox.shrink();

    return SegmentedButton<_AiType>(
      segments: types.map((type) {
        return ButtonSegment<_AiType>(
          value: type,
          label: Text(
            type.label,
            style: TextStyle(
              color: _aiType == type
                  ? Colors.blueGrey.shade900
                  : Colors.blueGrey.shade300,
              fontSize: 13,
            ),
          ),
          icon: Icon(
            type == _AiType.local ? Icons.computer : Icons.cloud,
            size: 16,
            color: _aiType == type
                ? Colors.blueGrey.shade900
                : Colors.blueGrey.shade400,
          ),
        );
      }).toList(),
      selected: {_aiType},
      onSelectionChanged: (selection) {
        setState(() => _aiType = selection.first);
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amber;
          }
          return Colors.blueGrey.shade800;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: Colors.amber);
          }
          return BorderSide(color: Colors.blueGrey.shade700);
        }),
      ),
    );
  }

  /// 233 服 AI 生成的最终房间串预览。
  Widget _roomStringPreview() {
    final roomString = _build233RoomString();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.code, size: 14, color: Colors.blueGrey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '房间串: $roomString',
              style: TextStyle(
                color: Colors.blueGrey.shade300,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
