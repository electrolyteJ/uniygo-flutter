import 'dart:async';
import 'dart:math' as math;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resource_data/lf_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../duel_room_exit.dart';
import '../hud/hud_theme.dart';
import '../invite/duel_invite.dart';
import 'widgets/duel_style.dart';
import 'widgets/room_actions.dart';
import 'widgets/player_card.dart';
import 'widgets/room_info_card.dart';
import 'widgets/spectator_list_card.dart';
import 'widgets/spectator_stack_icon.dart';
import 'widgets/side_decking_panel.dart';

Future<void> _onEditDeck(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(duelRoomProvider.notifier);
  final roomState = ref.read(duelRoomProvider);
  final opts = roomState.roomOptions;
  final result = await context.push<Map<String, Object?>>(
    '/deck-editor',
    extra: <String, Object?>{
      'initialDeckName': roomState.selectedDeckName,
      if (opts != null) 'noCheckDeck': opts.noCheckDeck,
      if (opts != null) 'lfTableHash': opts.lfTableHash,
      'lockDeckSelection': true,
      'lockDeckName': true,
    },
  );
  // 跨页 await 之后 context 可能已卸载。
  if (!context.mounted) return;
  if (result?['saved'] == true) {
    await controller.refreshSelectedDeckValidation();
  }
}

/// 换备确认：提交换备后的卡组并 ready，失败原因走 SnackBar。
Future<void> _onConfirmSiding(BuildContext context, WidgetRef ref) async {
  // 兜住一切异常：确认是 match 局间唯一推进通道，未处理异常会让
  // 换备永远卡住（第二局不开局）且无任何提示。
  String? error;
  try {
    error = await ref.read(duelRoomProvider.notifier).confirmSiding();
  } catch (e) {
    error = '换备提交失败: $e';
  }
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// 05 对战-等候：顶部状态栏 + 左右选手卡 + 中央阶段区 + 规则条 + 操作栏。
class WaitingRoomPage3D extends ConsumerStatefulWidget {
  const WaitingRoomPage3D({
    super.key,
    this.roomId,
    this.roomName,
    this.serverHost,
    this.serverPort,
  });

  /// 建房/进房链路携带的房间邀码与房间名（路由参数注入，避免房间状态被阶段刷新重置）。
  final String? roomId;
  final String? roomName;

  /// 房间所在服务器（写进邀请二维码，扫码方据此推断环境）。
  final String? serverHost;
  final int? serverPort;

  @override
  ConsumerState<WaitingRoomPage3D> createState() => _WaitingRoomPage3DState();
}

class _WaitingRoomPage3DState extends ConsumerState<WaitingRoomPage3D> {
  /// 路由参数优先；状态里也带一份（测试/预览场景无路由参数）。
  String? get _roomId => widget.roomId ?? ref.read(duelRoomProvider).roomId;
  String? get _roomName =>
      widget.roomName ?? ref.read(duelRoomProvider).roomName;
  LfTable? _lfTable;
  int _lfTableHash = 0;

  /// 房间信息卡常驻展示，需要提前加载禁限卡表（显示卡表名 + 可点开详情）。
  Future<void> _ensureLfTable(int hash) async {
    if (hash == 0 || hash == _lfTableHash) return;
    _lfTableHash = hash;
    LfTable? table;
    try {
      table = await ref.read(duelRoomProvider.notifier).getLfTable(hash);
    } catch (_) {
      table = null;
    }
    if (!mounted) return;
    setState(() => _lfTable = table);
  }

  /// 观战列表弹窗（点右侧叠放头像入口打开）。
  Future<void> _openSpectators(DuelRoomState room) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SpectatorListCard(
          observerCount: room.observerCount,
          selfIsObserver: !room.selfType.isDuelist,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _openBanlist() {
    final table = _lfTable;
    if (table == null) return;
    BanlistDetailDialog.show(
      context,
      lfTable: table,
      cardLoader: (_) async => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(duelRoomProvider);
    final stage = room.stage;
    // 房间信息卡直接展示：卡表 hash 就绪后异步补加载。
    final lfHash = room.roomOptions?.lfTableHash ?? 0;
    if (lfHash != 0 && lfHash != _lfTableHash) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureLfTable(lfHash),
      );
    }
    final size = MediaQuery.sizeOf(context);
    final k = (math.min(size.width / 844, size.height / 390)).clamp(0.85, 2.4);
    final inPhase =
        stage is RoomSelectingHand ||
        stage is RoomHandResult ||
        stage is RoomSelectingTurn;
    final seatW = (inPhase ? 252.0 : 190.0) * k;
    final seatH = (inPhase ? 210.0 : 196.0) * k;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1220), Color(0xFF05070F)],
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(k)),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WaitingTopBar(
                      room: room,
                      stage: stage,
                      roomId: _roomId,
                      roomName: _roomName,
                      serverHost: widget.serverHost,
                      serverPort: widget.serverPort,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: seatW,
                            height: seatH,
                            child: PlayerCard(
                              room: room,
                              roomId: _roomId,
                              isSelf: true,
                              onChangeDeck: () =>
                                  _showDeckPicker(context, ref, room),
                              onEditDeck: () => _onEditDeck(context, ref),
                              onShowDeckCheck: () =>
                                  _showDeckCheckDialog(context, room),
                              onInvite: () {},
                            ),
                          ),
                          SizedBox(width: 12 * k),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (inPhase)
                                  _WaitingStage(
                                    room: room,
                                    stage: stage,
                                    roomId: _roomId,
                                  )
                                else
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: RoomInfoCard(
                                      room: room,
                                      roomId: _roomId,
                                      lfTable: _lfTable,
                                      onOpenBanlist: _lfTable == null
                                          ? null
                                          : _openBanlist,
                                      onShowDeckCheck: () =>
                                          _showDeckCheckDialog(context, room),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12 * k),
                          SizedBox(
                            width: seatW,
                            height: seatH,
                            child: PlayerCard(
                              room: room,
                              roomId: _roomId,
                              isSelf: false,
                              onChangeDeck: () {},
                              onEditDeck: () {},
                              onShowDeckCheck: () {},
                              onInvite: () {
                                final id = _roomId;
                                if (id != null) _showInviteDialog(context, id);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (inPhase) _PhaseStatusBar(room: room, stage: stage),
                    // 观战入口：页面右侧、准备按钮上方，头像堆叠 + 人数。
                    if (!inPhase)
                      Padding(
                        // 设计稿位置：右侧距页面边 52（页面内边距 16 + 36）。
                        padding: EdgeInsets.only(bottom: 6 * k, right: 36 * k),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SpectatorStackIcon(
                            count: room.observerCount,
                            onTap: () => _openSpectators(room),
                          ),
                        ),
                      ),
                    RoomActions(room: room, stage: stage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 05a3 房间信息浮层：400×262 设计稿面板（按屏宽等比缩放）。

/// 顶部房间信息条：模式 + 观战数 + 可展开的完整房间信息面板。
///
/// 默认收起保持紧凑；点击信息图标展开 [RoomInfoPanel]（含禁限卡表弹层）。
class _StageBody extends ConsumerWidget {
  const _StageBody({required this.room, required this.stage, this.roomId});

  final DuelRoomState room;
  final RoomStage stage;
  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = stage;
    if (current is RoomSelectingHand) {
      return _RpsStage(room: room);
    }
    if (current is RoomHandResult) {
      return _RpsResultStage(room: room, result: current);
    }
    if (current is RoomSelectingTurn) {
      return _TurnSelectStage(room: room);
    }
    if (stage is RoomSideDecking) {
      final notifier = ref.read(duelRoomProvider.notifier);
      // 换备内容随卡组规模增长，外层套滚动 + 宽度上限，避免长卡组溢出。
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: SideDeckingPanel(
              // tag 模式座位 2/3（player3/player4）同样是决斗者。
              isDuelist: room.selfType.isDuelist,
              sidingMain: room.sidingMain,
              sidingExtra: room.sidingExtra,
              sidingSide: room.sidingSide,
              sidingInitFailed: room.sidingInitFailed,
              onRetryInit: notifier.retrySidingInit,
              baselineMainCount: room.sidingBaseline?.main.length ?? 0,
              baselineExtraCount: room.sidingBaseline?.extra.length ?? 0,
              baselineSideCount: room.sidingBaseline?.side.length ?? 0,
              onMoveCard: notifier.moveSidingCard,
              onReset: notifier.resetSiding,
              onConfirm: () => _onConfirmSiding(context, ref),
            ),
          ),
        ),
      );
    }
    return _WaitingLobbyView(room: room, roomId: roomId);
  }
}

/// 大厅面板：卡组选择（含主/额/副数量）+ 校验状态 + 编辑卡组入口。

/// 选先后攻面板。

/// 底部操作栏：准备/开始 + 观战切换 + 聊天 + 自动化开关。

/// 顶部状态栏：取消 / 当前阶段 / 段位 / 房间信息 / 设置。
class _WaitingTopBar extends ConsumerWidget {
  const _WaitingTopBar({
    required this.room,
    required this.stage,
    required this.roomId,
    required this.roomName,
    this.serverHost,
    this.serverPort,
  });

  final DuelRoomState room;
  final RoomStage stage;
  final String? roomId;
  final String? roomName;

  /// 房间所在服务器（写进邀请二维码，扫码方据此推断环境）。
  final String? serverHost;
  final int? serverPort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('waiting-exit'),
          tooltip: '退出房间',
          icon: const Icon(Icons.arrow_back, color: duelSub, size: 20),
          onPressed: () => backHomeDialog(
            context: context,
            ref: ref,
            title: '退出房间',
            content: '是否确认退出当前房间？',
          ),
        ),
        Text(
          roomName ?? '对战房间',
          style: HudTheme.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (roomId != null)
          IconButton(
            key: const ValueKey('waiting-invite'),
            tooltip: '邀请好友',
            icon: const Icon(Icons.person_add_alt, color: duelCyan, size: 20),
            onPressed: () => _showInviteDialog(
              context,
              roomId!,
              host: serverHost,
              port: serverPort,
            ),
          ),
        IconButton(
          key: const ValueKey('waiting-settings'),
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined, color: duelSub, size: 20),
          onPressed: () {
            final open = ref.read(showYgoSettingsDialogProvider);
            if (open == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('设置功能不可用')));
              return;
            }
            final notifier = ref.read(duelRoomProvider.notifier);
            // 传当前房间值 + 即时回调：改完立刻作用到本局等候厅。
            open(
              context,
              autoDuel: room.autoDuelEnabled,
              autoHand: room.autoHandEnabled,
              autoTurnOrder: room.autoTurnOrderEnabled,
              onAutoDuelChanged: (v) =>
                  unawaited(notifier.setAutoDuelEnabled(v)),
              onAutoHandChanged: (v) =>
                  unawaited(notifier.setAutoHandEnabled(v)),
              onAutoTurnOrderChanged: (v) =>
                  unawaited(notifier.setAutoTurnOrderEnabled(v)),
            );
          },
        ),
      ],
    );
  }
}

/// 选手卡：头像 / 昵称 / 段位 / 出战卡组（可切换）/ 卡组校验 / LP / 准备态。

/// 05a4 房间邀请：房间号 + 二维码 + 复制房间号/分享链接。
void _showInviteDialog(
  BuildContext context,
  String roomId, {
  String? host,
  int? port,
}) {
  // 深链格式；对方扫码后可直接拿到邀码（h/p 帮助扫码方选出同一环境）。
  final link = DuelInvite.buildLink(roomId, host: host, port: port);
  void copy(String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HudTheme.panelBg,
      title: const Text('邀请好友', style: HudTheme.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roomId,
              textAlign: TextAlign.center,
              style: HudTheme.title.copyWith(
                fontSize: roomId.length > 12 ? 12 : 26,
                letterSpacing: roomId.length > 12 ? 0 : 6,
                color: HudTheme.cyan,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: QrImageView(
                data: link,
                size: 150,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF05070F),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF05070F),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('把房间号或分享链接发给好友', style: HudTheme.caption),
            const SizedBox(height: 4),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: HudTheme.caption.copyWith(
                fontSize: 10,
                color: HudTheme.cyan,
              ),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => copy(roomId, '房间号已复制'),
          child: const Text('复制房间号'),
        ),
        TextButton(
          onPressed: () => copy(link, '分享链接已复制'),
          child: const Text('复制分享链接'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 05a7 卡组校验明细：列出未通过项，提示切换卡组。
Future<void> _showDeckPicker(
  BuildContext context,
  WidgetRef ref,
  DuelRoomState room,
) async {
  final notifier = ref.read(duelRoomProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: duelPanel,
      title: const Text(
        '出战卡组',
        style: TextStyle(fontSize: 14, color: duelTextColor),
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final d in room.availableDecks)
                InkWell(
                  onTap: () {
                    notifier.selectDeck(d.deckName);
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      d.deckName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: d.deckName == room.selectedDeckName
                            ? duelCyan
                            : duelTextColor,
                      ),
                    ),
                  ),
                ),
              if (room.availableDecks.isEmpty)
                Text(
                  '暂无可用卡组',
                  style: TextStyle(fontSize: 10, color: duelFaint),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _onEditDeck(context, ref);
          },
          child: const Text('编辑卡组'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

void _showDeckCheckDialog(BuildContext context, DuelRoomState room) {
  final issues = room.invalidationDeckResult ?? const <String>[];
  final ok = issues.isEmpty;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: duelPanel,
      title: const Text('卡组校验明细', style: HudTheme.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.verified : Icons.error_outline,
                  size: 16,
                  color: ok ? duelHeal : duelDanger,
                ),
                const SizedBox(width: 6),
                Text(
                  ok ? '校验通过' : '${issues.length} 项未通过',
                  style: HudTheme.body.copyWith(
                    color: ok ? duelHeal : duelDanger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: duelLine),
            const SizedBox(height: 8),
            if (ok)
              Text('当前卡组符合禁限卡表与卡组数量规则', style: HudTheme.caption)
            else
              for (final issue in issues.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 4, color: duelDanger),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issue,
                          style: HudTheme.caption.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            if (issues.length > 12) ...[
              const SizedBox(height: 4),
              Text(
                '…还有 ${issues.length - 12} 项',
                style: HudTheme.caption.copyWith(fontSize: 10),
              ),
            ],
            if (!ok) ...[
              const SizedBox(height: 8),
              Text(
                '可点「变更」切换或编辑卡组后重新校验',
                style: HudTheme.caption.copyWith(fontSize: 10, color: duelCyan),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 中央等待舞台：大厅阶段显示等待计时，其余阶段沿用原有阶段面板。
class _WaitingStage extends StatelessWidget {
  const _WaitingStage({required this.room, required this.stage, this.roomId});

  final DuelRoomState room;
  final RoomStage stage;
  final String? roomId;

  @override
  Widget build(BuildContext context) {
    if (stage is! RoomInLobby && stage is! RoomJoined) {
      return _StageBody(room: room, stage: stage, roomId: roomId);
    }
    return _WaitingLobbyView(room: room);
  }
}

class _HandButton extends StatelessWidget {
  const _HandButton({
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? duelCyan : duelSub;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF09121C),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: duelLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: height * 0.4),
              SizedBox(height: height * 0.1),
              Text(
                label,
                style: HudTheme.caption.copyWith(
                  fontSize: 9,
                  color: enabled ? duelTextColor : duelSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 05b2 出拳结果：双方手势 + 胜负 + 下一步提示。

/// 05c 选择先后攻 / 05c2 等待对手选择。

class _TurnButton extends StatelessWidget {
  const _TurnButton({
    required this.width,
    required this.height,
    required this.label,
    required this.caption,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final String label;
  final String caption;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF0A1F2F) : const Color(0xFF09121C),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: enabled ? duelCyan : duelLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: HudTheme.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled ? duelCyan : duelSub,
                ),
              ),
              const SizedBox(height: 2),
              Text(caption, style: HudTheme.caption.copyWith(fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 阶段状态栏（05b-05e 底栏）：连接态 + 进度 + 下一步提示。
class _PhaseStatusBar extends StatelessWidget {
  const _PhaseStatusBar({required this.room, required this.stage});

  final DuelRoomState room;
  final RoomStage stage;

  @override
  Widget build(BuildContext context) {
    final (status, hint, progress) = switch (stage) {
      RoomSelectingHand() => ('双方已连接 · 出拳决定先后攻', '下一步：选择先后攻 →', 0.75),
      RoomHandResult() => ('出拳结果 · 胜者选择先后攻', '选择后进入决斗 →', 0.85),
      RoomSelectingTurn() when room.isFirstTurn != null => (
        '已选择 · 等待对手确认',
        '对手确认后进入决斗 →',
        0.95,
      ),
      RoomSelectingTurn() => ('猜拳结果 · 请选择先攻或后攻', '等待选择 →', 0.85),
      _ => ('等待中', '', 0.5),
    };
    return Container(
      decoration: BoxDecoration(
        color: duelPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: duelLine),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: duelHeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: HudTheme.caption.copyWith(fontSize: 10, color: duelHeal),
          ),
          const Spacer(),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: duelLine,
                valueColor: const AlwaysStoppedAnimation(duelCyan),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            hint,
            style: HudTheme.caption.copyWith(fontSize: 10, color: duelCyan),
          ),
        ],
      ),
    );
  }
}

// ── 各阶段内联（原 stages/ 目录） ──────────────────────

// 05a 等待对手阶段。
class _WaitingLobbyView extends StatefulWidget {
  const _WaitingLobbyView({required this.room, this.roomId});

  final DuelRoomState room;
  final String? roomId;

  @override
  State<_WaitingLobbyView> createState() => _WaitingLobbyViewState();
}

class _WaitingLobbyViewState extends State<_WaitingLobbyView> {
  Timer? _ticker;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 短画布（844×390 设计稿）下圆环按可用高度收缩，避免溢出。
          final outer = math
              .min(constraints.maxHeight - 8, 230.0)
              .clamp(120.0, 230.0);
          final inner = outer * 0.78;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final size in [outer, inner])
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: duelCyan.withValues(alpha: 0.18)),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('等待对手', style: HudTheme.title),
                  const SizedBox(height: 8),
                  Text('已等待 $mm:$ss', style: HudTheme.caption),
                  if (widget.roomId != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '房间 #${widget.roomId}',
                      style: HudTheme.caption.copyWith(
                        fontSize: 8,
                        color: duelCyan,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    widget.room.isHost ? '您是房主，可邀请好友加入' : '等待房主开始决斗',
                    style: HudTheme.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// 05b 猜拳 / 05b2 出拳结果阶段。
String _handName(int hand) => switch (hand) {
  1 => '剪刀',
  2 => '石头',
  3 => '布',
  _ => '—',
};

IconData _handIcon(int hand) => switch (hand) {
  1 => Icons.content_cut,
  2 => Icons.circle_outlined,
  3 => Icons.back_hand_outlined,
  _ => Icons.help_outline,
};

int _rpsOutcome(int mine, int other) {
  if (mine == other) return 0;
  final win =
      (mine == 1 && other == 3) ||
      (mine == 2 && other == 1) ||
      (mine == 3 && other == 2);
  return win ? 1 : -1;
}

/// 05b 猜拳：双方各出一个手势，倒计时结束自动出拳。

class _HandCircle extends StatelessWidget {
  const _HandCircle({required this.size, this.hand, this.highlight = false});

  final double size;
  final int? hand;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight ? const Color(0xFF0A1F2F) : const Color(0xFF09121C),
        border: Border.all(color: highlight ? duelCyan : duelLine),
      ),
      alignment: Alignment.center,
      child: hand == null
          ? Text(
              '?',
              style: TextStyle(
                color: highlight ? duelCyan : duelSub,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(
              _handIcon(hand!),
              color: highlight ? duelCyan : duelTextColor,
              size: size * 0.4,
            ),
    );
  }
}

class _RpsStage extends ConsumerWidget {
  const _RpsStage({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final chosen = room.myHandResult != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final handSize = compact ? 60.0 : 84.0;
        final btnW = compact ? 58.0 : 72.0;
        final btnH = compact ? 48.0 : 64.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('猜拳 · 决定先后攻', style: HudTheme.title),
              SizedBox(height: compact ? 6 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      _HandCircle(size: handSize, highlight: true),
                      const SizedBox(height: 6),
                      Text('你', style: HudTheme.caption.copyWith(fontSize: 9)),
                    ],
                  ),
                  SizedBox(width: compact ? 16 : 28),
                  Column(
                    children: [
                      _HandCircle(size: handSize),
                      const SizedBox(height: 6),
                      Text('对手', style: HudTheme.caption.copyWith(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HandButton(
                    width: btnW,
                    height: btnH,
                    icon: Icons.circle_outlined,
                    label: '石头',
                    enabled: !chosen,
                    onTap: () => notifier.sendHand(HandType.rock),
                  ),
                  const SizedBox(width: 10),
                  _HandButton(
                    width: btnW,
                    height: btnH,
                    icon: Icons.content_cut,
                    label: '剪刀',
                    enabled: !chosen,
                    onTap: () => notifier.sendHand(HandType.scissors),
                  ),
                  const SizedBox(width: 10),
                  _HandButton(
                    width: btnW,
                    height: btnH,
                    icon: Icons.back_hand_outlined,
                    label: '布',
                    enabled: !chosen,
                    onTap: () => notifier.sendHand(HandType.paper),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                chosen ? '已出拳，等待对方…' : '双方选择中 · 倒计时结束后自动出拳',
                style: HudTheme.caption.copyWith(
                  fontSize: 9,
                  color: chosen ? duelHeal : duelCyan,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RpsResultStage extends ConsumerWidget {
  const _RpsResultStage({required this.room, required this.result});

  final DuelRoomState room;
  final RoomHandResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = _rpsOutcome(result.myHand, result.opponentHand);
    final title = switch (outcome) {
      1 => '你胜出',
      -1 => '对手胜出',
      _ => '平局 · 重新出拳',
    };
    final color = switch (outcome) {
      1 => duelHeal,
      -1 => duelDanger,
      _ => duelSub,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final handSize = compact ? 60.0 : 84.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('出拳结果', style: HudTheme.title),
              SizedBox(height: compact ? 10 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      _HandCircle(
                        size: handSize,
                        hand: result.myHand,
                        highlight: outcome == 1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '你 · ${_handName(result.myHand)}',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  SizedBox(width: compact ? 16 : 28),
                  Column(
                    children: [
                      _HandCircle(
                        size: handSize,
                        hand: result.opponentHand,
                        highlight: outcome == -1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '对手 · ${_handName(result.opponentHand)}',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                title,
                style: HudTheme.title.copyWith(color: color, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                outcome == 0 ? '平局后重新猜拳' : '胜者选择先攻或后攻',
                style: HudTheme.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 05c 选择先后攻 / 05c2 等待对手选择阶段。
class _TurnSelectStage extends ConsumerWidget {
  const _TurnSelectStage({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final waiting = room.isFirstTurn != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final btnW = compact ? 84.0 : 104.0;
        final btnH = compact ? 56.0 : 68.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                waiting ? '等待对手选择先后攻' : '猜拳胜出 · 你先选',
                style: HudTheme.title.copyWith(
                  color: waiting ? duelTextColor : duelCyan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                waiting ? '对手正在选择先攻或后攻' : '选择先攻或后攻，进入决斗场地',
                style: HudTheme.caption.copyWith(fontSize: 9),
              ),
              SizedBox(height: compact ? 12 : 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TurnButton(
                    width: btnW,
                    height: btnH,
                    label: '先攻',
                    caption: waiting ? '等待中' : '先手开局',
                    enabled: !waiting,
                    onTap: () => notifier.sendTp(true),
                  ),
                  const SizedBox(width: 12),
                  _TurnButton(
                    width: btnW,
                    height: btnH,
                    label: '后攻',
                    caption: waiting ? '等待中' : '后手开局',
                    enabled: !waiting,
                    onTap: () => notifier.sendTp(false),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                waiting ? '对手正在选择…' : '选择后等待对手确认',
                style: HudTheme.caption.copyWith(
                  fontSize: 9,
                  color: waiting ? duelSub : duelCyan,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
