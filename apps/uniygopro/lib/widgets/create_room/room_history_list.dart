// ── 创建房间历史记录（横滑卡片列表）──

import 'package:flutter/material.dart';

import '../../pages/create_room/room_history.dart';

/// 创建房间表单顶部的历史记录横滑列表。
///
/// - 点击卡片：[onFill] 回填表单
/// - 点击播放按钮：[onEnter] 以该记录直接创建并进入房间
/// - 点击关闭按钮：[onDelete] 删除该记录
class RoomHistoryList extends StatelessWidget {
  final List<CreatedRoomRecord> records;
  final ValueChanged<CreatedRoomRecord> onFill;
  final ValueChanged<CreatedRoomRecord> onEnter;
  final ValueChanged<CreatedRoomRecord> onDelete;

  const RoomHistoryList({
    super.key,
    required this.records,
    required this.onFill,
    required this.onEnter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('历史记录',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
        const SizedBox(height: 6),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _HistoryCard(
              record: records[i],
              onFill: () => onFill(records[i]),
              onEnter: () => onEnter(records[i]),
              onDelete: () => onDelete(records[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final CreatedRoomRecord record;
  final VoidCallback onFill;
  final VoidCallback onEnter;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.record,
    required this.onFill,
    required this.onEnter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blueGrey.shade800,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onFill,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 176,
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: IconButton(
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      tooltip: '删除',
                      icon: Icon(Icons.close,
                          color: Colors.blueGrey.shade400),
                    ),
                  ),
                ],
              ),
              Text(
                record.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.edit_outlined,
                      size: 14, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 3),
                  Text('回填',
                      style: TextStyle(
                          color: Colors.blueGrey.shade300, fontSize: 11)),
                  const Spacer(),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: IconButton(
                      onPressed: onEnter,
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: '直接创建并进入',
                      icon: Icon(Icons.play_circle_fill,
                          color: Colors.amber.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
