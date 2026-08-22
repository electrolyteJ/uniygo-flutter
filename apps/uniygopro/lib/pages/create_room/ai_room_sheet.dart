// ────────────────────────────────────────────────────────────
// AI Room Sheet (人机对战入口 + 房间参数)
// ────────────────────────────────────────────────────────────

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/servers.dart';
import 'package:biz/service_singleton.dart';
import '../../models/mercury233_room_spec.dart';
import '../../widgets/create_room/duel_room_params_fields.dart';
import '../../widgets/create_room/room_params_form.dart';
import '../../widgets/create_room/room_dialog.dart';
import 'match_store.dart';

/// AI 类型选择
enum _AiType {
  local('本地 AI', '与本地 AI 进行一场单局对战，无需联网。'),
  server233('233 服 AI', '连接 ygo233.com 服务器，与服务器端 AI 对战（禁限卡可选，无禁限为 NF 标记）。');

  final String label;
  final String description;
  const _AiType(this.label, this.description);
}

/// AI 对决面板 — 选择房间参数后进入人机对战。
///
/// 房间参数（大师规则/卡片允许/禁限卡表/LP/手牌/抽卡/时间/
/// 卡组检查开关）与 233 建房表单共用 [RoomParamsForm]，
/// 状态统一为 [Mercury233RoomSpec]；233 服 AI 主机密码由同一份 spec
/// 经 [RoomTokens.encodeAiPassword] 生成。
class AiRoomSheet extends StatefulWidget {
  final GameServer server;
  const AiRoomSheet({super.key, required this.server});

  @override
  State<AiRoomSheet> createState() => _AiRoomSheetState();
}

class _AiRoomSheetState extends State<AiRoomSheet> {
  _AiType _aiType = _AiType.local;

  /// 本地 AI 的对手模式：-1=规则 AI，0=端侧 ygo-agent 模型（默认），
  /// 1=远端 predict 服务。仅 [_AiType.local] 时生效。
  int _agentMode = 0;

  /// 远端 predict 服务地址（仅 agent==1 生效）；留空 = 默认公共服务。
  String _agentServer = '';

  /// 房间参数（单局、无房间名）。AI 对战默认不检查卡组。
  Mercury233RoomSpec _spec = const Mercury233RoomSpec(
    options: RoomOptions(mode: RoomMode.single, noCheckDeck: true),
  );
  bool _connecting = false;

  /// 禁限卡表选项与自由房同源：dataService 的全部 lflist 表 +
  /// 末尾追加无禁限（NF）。
  Future<List<Mercury233BanlistOption>> _loadBanlistOptions() async {
    final tables =
        await ServiceSingleton.instance.dataService.getAllLfTable();
    return buildMercury233BanlistOptions(tables.values);
  }

  /// 为 233 服 AI 生成主机密码：AI 必须首位 + 协议 token。
  /// 参考 https://ygo233.com/lab：主机密码输入 AI 即可自动生成 AI 对手，
  /// 不需要也不能使用 # 和房间名。编码复用 [RoomTokens.encodeAiPassword]
  /// （与自由房房间串共用同一套 token 定义）。
  String _build233AiPassword() => RoomTokens.encodeAiPassword(
    _spec.toRoomOptions(),
    banlistToken: _spec.banlistToken,
  );

  Future<void> _start() async {
    final matchStore = context.read<MatchStore>();
    final options = RoomOptions(
      // 本地 AI 引擎是 1v1，固定单局；233 服 AI 由服务端按密码 token 决定模式。
      mode: _aiType == _AiType.local ? RoomMode.single : _spec.mode,
      rule: _spec.rule,
      duelRule: _spec.duelRule,
      noCheckDeck: _spec.noCheckDeck,
      noShuffleDeck: _spec.noShuffleDeck,
      startLp: _spec.startLp,
      startHand: _spec.startHand,
      drawCount: _spec.drawCount,
      timeLimit: _spec.timeLimit,
      // 仅本地 AI 使用端侧/远端模型；233 服 AI 由服务端托管。
      agent: _aiType == _AiType.local ? _agentMode : -1,
      agentServer: _agentMode == 1 ? _agentServer.trim() : '',
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
        RoomTokens.encodeAiPassword(options),
      );
    } else {
      // 233 服 AI：主机密码输入 AI（+ 协议 token）即可自动生成 AI 对手，
      // 无需再手动发送 /ai。禁限（含无禁限 NF）走密码 token，统一连 233 端口。
      final aiPassword = _build233AiPassword();
      matchStore.configureCreatedRoom(
        roomOptions: options,
        roomName: 'AI 人机对战',
      );
      matchStore.selectServer(
        widget.server,
        DuelEnvironment.mercury233,
        aiPassword,
      );
    }
    final params = matchStore.toDuelRoomParams();
    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room', extra: params);
    matchStore.reset();
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
            // 表单主体用 Flexible 占据头部之后的剩余高度（不用固定
            // 像素预算，避免头部高度变化导致 RenderFlex 溢出）；主体
            // 自带 SingleChildScrollView，超出时自行滚动。
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
                Flexible(
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
                        // ── 本地 AI 对手模式选择 ──
                        if (_aiType == _AiType.local) ...[
                          _agentModeSelector(),
                          const SizedBox(height: 8),
                        ],
                        // ── 与 233 建房表单共用的参数控件 ──
                        RoomParamsForm(
                          options: _spec.toRoomOptions(),
                          cardRuleItems: cardRuleItems233,
                          // 本地 AI 固定单局，隐藏对战模式；233 服 AI 可切模式。
                          showMode: _aiType != _AiType.local,
                          // 本地 AI 没有禁限概念，隐藏该选项。
                          showBanlist: _aiType != _AiType.local,
                          banlistOptionsLoader: _loadBanlistOptions,
                          banlist: _spec.banlist,
                          onBanlistChanged: (v) =>
                              setState(() => _spec = _spec.copyWith(banlist: v)),
                          onChanged: (o) =>
                              setState(() => _spec = _spec.applyRoomOptions(o)),
                        ),
                        // ── 233 服 AI 房间串预览 ──
                        if (_aiType != _AiType.local) ...[
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
                          onTapFeedback: ServiceSingleton
                              .instance
                              .ygoSoundService
                              .playButtonTap,
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

  /// 本地 AI 对手模式选择器：端侧模型 / 规则 AI / 远端模型。
  Widget _agentModeSelector() {
    const modes = [
      (0, '端侧模型', '本地 ygo-agent 神经网络（首次加载约 17MB 模型）'),
      (-1, '规则 AI', '简单规则策略（快速、无模型加载）'),
      (1, '远端模型', '远端 ygo-agent predict 服务（需联网）'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: modes.map((m) {
            final (value, label, _) = m;
            return ButtonSegment<int>(
              value: value,
              label: Text(
                label,
                style: TextStyle(
                  color: _agentMode == value
                      ? Colors.blueGrey.shade900
                      : Colors.blueGrey.shade300,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          selected: {_agentMode},
          onSelectionChanged: (selection) {
            setState(() => _agentMode = selection.first);
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
        ),
        const SizedBox(height: 4),
        Text(
          modes.firstWhere((m) => m.$1 == _agentMode).$3,
          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
        ),
        // 远端模型：自托管服务地址（留空 = 默认公共服务）
        if (_agentMode == 1) ...[
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ai-agent-server-field'),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'https://sapi.moecube.com:444/neos-ai-agent',
              hintStyle: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 12,
              ),
              labelText: 'predict 服务地址（留空 = 默认公共服务）',
              labelStyle: TextStyle(
                color: Colors.blueGrey.shade400,
                fontSize: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueGrey.shade700),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
            onChanged: (v) => _agentServer = v,
          ),
        ],
      ],
    );
  }

  /// 233 服 AI 生成的主机密码预览。
  Widget _roomStringPreview() {
    final aiPassword = _build233AiPassword();
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
              'AI 密码: $aiPassword',
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
