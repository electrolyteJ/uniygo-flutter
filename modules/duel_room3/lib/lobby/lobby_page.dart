import 'dart:async';
import 'dart:math' as math;

import 'package:biz/duel/field/duel_field_state.dart' show teamOfSeat;
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:resource_data/lf_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../util/duel_room_exit.dart';
import 'widgets/invite_dialog.dart';
import 'widgets/deck_check_dialog.dart';
import '../widgets/duel_backdrop.dart';
import '../theme/duel_style.dart';
import 'widgets/room_actions.dart';
import 'widgets/player_card.dart';
import 'widgets/room_info_card.dart';
import 'widgets/spectator_list_card.dart';
import 'widgets/spectator_stack_icon.dart';

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

/// 一侧阵营的座位：ocgcore 约定 tag（双打）按 `pos % 2` 分队
/// （座位 0/2 = 队伍 0，1/3 = 队伍 1），1v1 每队恰有一个座位。
///
/// [selfFirst] 传入自己的座位号时，把自己排在该侧首位，队友依次跟在后面，
/// 保证从任何座位入局都能看到「我 + 队友」这一列。
List<PlayerInfo> _sideSeats(DuelRoomState room, int team, {int? selfFirst}) {
  final seats = <PlayerInfo>[
    for (final p in room.players)
      if (p.pos >= 0 && p.pos <= 3 && teamOfSeat(p.pos) == team) p,
  ]..sort((a, b) => a.pos.compareTo(b.pos));
  if (selfFirst == null) return seats;
  final mineIndex = seats.indexWhere((p) => p.pos == selfFirst);
  if (mineIndex > 0) {
    final mine = seats.removeAt(mineIndex);
    seats.insert(0, mine);
  }
  return seats;
}

/// 等待阶段的三个独立页：等待大厅 / 猜拳 / 选先后攻。
///
/// 三个页面共享同一套页壳（顶栏 + 左右选手卡 + 底栏），由 TabBarView
/// 在 room 页按 RoomStage 切换，而不是在页内临时换中心内容。
/// 05 对战-等候：顶部状态栏 + 左右选手卡 + 中央阶段区 + 规则条 + 操作栏。
class LobbyPage3D extends ConsumerStatefulWidget {
  const LobbyPage3D({
    super.key,
    this.roomId,
    this.roomName,
    this.serverHost,
    this.serverPort,
    this.isAiRoom = false,
  });

  /// 建房/进房链路携带的房间邀码与房间名（路由参数注入，避免房间状态被阶段刷新重置）。
  final String? roomId;
  final String? roomName;

  /// 房间所在服务器（写进邀请二维码，扫码方据此推断环境）。
  final String? serverHost;
  final int? serverPort;

  /// 人机对战房间：底栏额外提供「呼叫 AI」（往聊天室发 /ai 让 AI 入座）。
  final bool isAiRoom;

  @override
  ConsumerState<LobbyPage3D> createState() => _LobbyPage3DState();
}

class _LobbyPage3DState extends ConsumerState<LobbyPage3D>
    with AutomaticKeepAliveClientMixin {
  /// 在房间页的 TabBarView 里保活：对局结束（第 ④ 页）后要切回本页，
  /// 不保活就会被销毁重建——卡表重拉、聊天记录丢失、连接重开。
  /// 单独使用时无副作用（KeepAlive 只是挂在 sliver 上的通知）。
  @override
  bool get wantKeepAlive => true;

  /// 路由参数优先；状态里也带一份（测试/预览场景无路由参数）。
  String? get _roomId => widget.roomId ?? ref.read(duelRoomProvider).roomId;
  LfTable? _lfTable;
  int _lfTableHash = 0;

  /// 房间信息卡常驻展示，需要提前加载禁限卡表（显示卡表名 + 可点开详情）。
  Future<void> _ensureLfTable(int hash) async {
    if (hash == 0 || hash == _lfTableHash) return;
    _lfTableHash = hash;
    LfTable? table;
    try {
      table = ref.read(duelRoomProvider.notifier).getLfTable(hash);
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
    super.build(context); // AutomaticKeepAliveClientMixin 要求先调。
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

    // 只有在需要玩家手动出拳/手动选先后攻时才显示倒计时进度条；
    // 开了自动出拳 / 自动先后攻时不需要倒计时。
    final seatW = 190.0 * k;
    // 席位按阵营分列：自己所在的队伍永远在左（队友跟在身后），观战者左列
    // 固定为队伍 1。2v2 时左右各两个座位，1v1 各一个。
    final selfSeat = room.selfType.isDuelist ? room.selfType.slot : null;
    final leftTeam = selfSeat == null ? 0 : teamOfSeat(selfSeat);
    final leftSeats = _sideSeats(room, leftTeam, selfFirst: selfSeat);
    final rightSeats = _sideSeats(room, 1 - leftTeam);

    // 设计稿 324:680 底纹：纯色 + 同心圆 + 两条横向分隔线。
    // 内容占满整页并垂直居中；顶栏与底栏悬浮覆盖，不再占用上下空间。
    return DuelRoomBackdrop(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(k)),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: seatW,
                        child: PlayerCard(
                          room: room,
                          roomId: _roomId,
                          seats: leftSeats,
                          isAlly: true,
                          selfSlot: selfSeat,
                          onChangeDeck: () =>
                              _showDeckPicker(context, ref, room),
                          onEditDeck: () => _onEditDeck(context, ref),
                          onShowDeckCheck: () =>
                              showDeckCheckDialog(context, room),
                          onInvite: () {},
                        ),
                      ),
                      SizedBox(width: 12 * k),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
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
                                    showDeckCheckDialog(context, room),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12 * k),
                      SizedBox(
                        width: seatW,
                        child: PlayerCard(
                          room: room,
                          roomId: _roomId,
                          seats: rightSeats,
                          isAlly: false,
                          selfSlot: selfSeat,
                          onChangeDeck: () {},
                          onEditDeck: () {},
                          onShowDeckCheck: () {},
                          onInvite: () {
                            final id = _roomId;
                            if (id != null) {
                              showInviteDialog(context, id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: _WaitingTopBar(
                  room: room,
                  stage: stage,
                  roomId: _roomId,
                  serverHost: widget.serverHost,
                  serverPort: widget.serverPort,
                ),
              ),
              Positioned(
                right: 52 * k,
                bottom: 72 * k,
                child: SpectatorStackIcon(
                  count: room.observerCount,
                  onTap: () => _openSpectators(room),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomActions(
                      room: room,
                      stage: stage,
                      isAiRoom: widget.isAiRoom,
                    ),
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

/// 大厅面板：卡组选择（含主/额/副数量）+ 校验状态 + 编辑卡组入口。

/// 选先后攻面板。

/// 底部操作栏：准备/开始 + 观战切换 + 聊天 + 自动化开关。

/// 顶部状态栏：取消 / 当前阶段 / 段位 / 房间信息 / 设置。
class _WaitingTopBar extends ConsumerWidget {
  const _WaitingTopBar({
    required this.room,
    required this.stage,
    required this.roomId,
    this.serverHost,
    this.serverPort,
  });

  final DuelRoomState room;
  final RoomStage stage;
  final String? roomId;

  /// 房间所在服务器（写进邀请二维码，扫码方据此推断环境）。
  final String? serverHost;
  final int? serverPort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;

    Widget square({
      required Key key,
      IconData? icon,
      String? glyph,
      required VoidCallback onTap,
      Color color = duelSub,
    }) {
      return InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(s(2)),
        child: Container(
          width: s(28),
          height: s(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(2)),
            border: Border.all(color: duelBtnLine),
          ),
          child: icon != null
              ? Icon(icon, size: s(15), color: color)
              : Text(
                  glyph ?? '',
                  style: TextStyle(fontSize: s(15), color: color),
                ),
        ),
      );
    }

    // 设计稿：右侧两个 28×28 图标距页面右边 30（页面内边距 16 + 14）。
    return Padding(
      padding: EdgeInsets.only(right: s(14)),
      child: Row(
        children: [
          InkWell(
            key: const ValueKey('waiting-exit'),
            onTap: () => backHomeDialog(
              context: context,
              ref: ref,
              title: '退出房间',
              content: '是否确认退出当前房间？',
            ),
            borderRadius: BorderRadius.circular(s(2)),
            child: Padding(
              padding: EdgeInsets.all(s(6)),
              child: Icon(Icons.arrow_back, color: duelSub, size: s(14)),
            ),
          ),
          const Spacer(),
          if (roomId != null) ...[
            square(
              key: const ValueKey('waiting-invite'),
              icon: Icons.person_add_alt,
              color: duelCyan,
              onTap: () => showInviteDialog(
                context,
                roomId!,
                host: serverHost,
                port: serverPort,
              ),
            ),
            SizedBox(width: s(6)),
          ],
          square(
            key: const ValueKey('waiting-settings'),
            icon: Icons.settings_outlined,
            color: duelMuted,
            onTap: () {
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
                autoHand: room.autoHandEnabled,
                autoTurnOrder: room.autoTurnOrderEnabled,
                onAutoHandChanged: (v) =>
                    unawaited(notifier.setAutoHandEnabled(v)),
                onAutoTurnOrderChanged: (v) =>
                    unawaited(notifier.setAutoTurnOrderEnabled(v)),
              );
            },
          ),
        ],
      ),
    );
  }
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
