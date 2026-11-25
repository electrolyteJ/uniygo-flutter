/// 05a3 房间信息面板（浮层卡片）。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:resource_data/lf_table.dart';

import 'duel_style.dart';

class RoomInfoCard extends StatelessWidget {
  const RoomInfoCard({
    super.key,
    required this.room,
    this.roomId,
    required this.lfTable,
    required this.onClose,
    required this.onOpenBanlist,
    required this.onShowDeckCheck,
  });

  final VoidCallback onShowDeckCheck;

  final DuelRoomState room;
  final String? roomId;
  final LfTable? lfTable;
  final VoidCallback onClose;
  final VoidCallback? onOpenBanlist;

  @override
  Widget build(BuildContext context) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    final o = room.roomOptions;
    final mode = switch (o?.mode) {
      RoomMode.single => '单局模式',
      RoomMode.match => '三局两胜',
      RoomMode.tag => '双打模式',
      null => '—',
    };
    final rule = switch (o?.rule) {
      1 => 'TCG',
      2 => 'OT 混',
      _ => 'OCG',
    };
    final master = switch (o?.duelRule) {
      DuelRule.mr3 => '大师规则 3',
      DuelRule.mr4 => '新大师规则',
      _ => '大师规则 2020',
    };
    final banlist = o == null || o.lfTableHash == 0
        ? '不限制'
        : (lfTable?.name ?? '加载中…');

    TextStyle labelStyle() => TextStyle(fontSize: 7.5 * k, color: duelSub);
    TextStyle valueStyle({Color color = duelTextColor}) =>
        TextStyle(fontSize: 8.5 * k, color: color);

    Widget row(
      double y,
      String leftLabel,
      String leftValue,
      String rightLabel,
      String rightValue, {
      Color rightColor = duelTextColor,
      VoidCallback? onRightTap,
    }) {
      return Stack(
        children: [
          Positioned(
            left: 16 * k,
            top: y * k,
            child: Text(leftLabel, style: labelStyle()),
          ),
          Positioned(
            left: 64 * k,
            top: y * k,
            width: 140 * k,
            child: Text(
              leftValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle(),
            ),
          ),
          Positioned(
            left: 210 * k,
            top: y * k,
            child: Text(rightLabel, style: labelStyle()),
          ),
          Positioned(
            left: 258 * k,
            top: y * k,
            width: 120 * k,
            child: GestureDetector(
              onTap: onRightTap,
              child: Text(
                rightValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle(color: rightColor),
              ),
            ),
          ),
        ],
      );
    }

    final panelW = 400 * k;
    final panelH = 262 * k;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 6 * k),
        child: SizedBox(
          width: panelW,
          height: panelH,
          child: Container(
            decoration: BoxDecoration(
              color: duelPanel,
              border: Border.all(color: duelLine),
              borderRadius: BorderRadius.circular(2 * k),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: panelW,
                  height: 2 * k,
                  child: const ColoredBox(color: duelCyan),
                ),
                Positioned(
                  left: 16 * k,
                  top: 12 * k,
                  child: Text(
                    '房间信息',
                    style: TextStyle(fontSize: 10.5 * k, color: duelTextColor),
                  ),
                ),
                if (roomId != null)
                  Positioned(
                    right: 30 * k,
                    top: 13 * k,
                    child: Text(
                      '房间 #$roomId',
                      style: TextStyle(fontSize: 8.5 * k, color: duelCyan),
                    ),
                  ),
                Positioned(
                  right: 8 * k,
                  top: 6 * k,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Padding(
                      padding: EdgeInsets.all(4 * k),
                      child: Icon(Icons.close, size: 12 * k, color: duelMuted),
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * k,
                  top: 32 * k,
                  width: 368 * k,
                  height: 1,
                  child: const ColoredBox(color: duelLine),
                ),
                row(
                  42,
                  '模式',
                  '$mode · $rule',
                  '禁限表',
                  banlist,
                  rightColor: duelCyan,
                  onRightTap: onOpenBanlist,
                ),
                row(
                  66,
                  '规则',
                  master,
                  '检查卡组',
                  o?.noCheckDeck == true ? '否' : '是',
                ),
                row(
                  90,
                  '初始',
                  'LP ${o?.startLp ?? 8000} · 手牌 ${o?.startHand ?? 5} · 抽卡 ${o?.drawCount ?? 1}',
                  '切洗卡组',
                  o?.noShuffleDeck == true ? '否' : '是',
                ),
                row(
                  114,
                  '限时',
                  '${o?.timeLimit ?? 0} 秒',
                  '观战',
                  '$room.observerCount / 2',
                ),
                Positioned(
                  left: 16 * k,
                  top: 146 * k,
                  width: 368 * k,
                  height: 1,
                  child: const ColoredBox(color: duelLine),
                ),
                Positioned(
                  left: 16 * k,
                  top: 156 * k,
                  child: Text(
                    '卡组校验',
                    style: TextStyle(fontSize: 8 * k, color: duelSub),
                  ),
                ),
                Positioned(
                  right: 16 * k,
                  top: 156 * k,
                  child: Text(
                    room.invalidationDeckResult == null
                        ? '未校验'
                        : (room.invalidationDeckResult!.isEmpty ? '通过' : '不通过'),
                    style: TextStyle(
                      fontSize: 8 * k,
                      color: room.invalidationDeckResult == null
                          ? duelSub
                          : (room.invalidationDeckResult!.isEmpty
                                ? duelHeal
                                : duelDanger),
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * k,
                  top: 172 * k,
                  width: 368 * k,
                  child: Text(
                    () {
                      final deck = room.availableDecks
                          .where((d) => d.deckName == room.selectedDeckName)
                          .firstOrNull;
                      final need = room.invalidationDeckResult?.length ?? 0;
                      return '卡数 ${deck?.mainCount ?? 0} / 40 · 副 ${deck?.sideCount ?? 0} · 未通过 $need 项';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 7 * k, color: duelSub),
                  ),
                ),
                Positioned(
                  left: 16 * k,
                  top: 188 * k,
                  child: GestureDetector(
                    onTap: () => onShowDeckCheck(),
                    child: Text(
                      '查看校验明细 ›',
                      style: TextStyle(fontSize: 7.5 * k, color: duelCyan),
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * k,
                  top: 210 * k,
                  width: 368 * k,
                  child: Text(
                    '禁限表 $banlist 已生效 · 观战仅好友可观看',
                    style: TextStyle(fontSize: 7 * k, color: duelFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
