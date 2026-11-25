/// 右侧面板下方的最近房间列表。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import 'created_room_record.dart';
import 'room_history_store.dart';

class FreeRoomHistory extends StatefulWidget {
  const FreeRoomHistory({super.key, required this.onJoin, this.height = 66});

  final ValueChanged<CreatedRoomRecord> onJoin;
  final double height;

  @override
  State<FreeRoomHistory> createState() => _FreeRoomHistoryState();
}

class _FreeRoomHistoryState extends State<FreeRoomHistory> {
  late Future<List<CreatedRoomRecord>> _future = RoomHistoryStore.load();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 644,
      top: 262,
      width: 184,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080F19),
          border: Border.all(color: DuelColors.borderPanel),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近房间', style: DuelType.sans(8, color: DuelColors.textFaint)),
            const SizedBox(height: 2),
            Expanded(
              child: FutureBuilder<List<CreatedRoomRecord>>(
                future: _future,
                builder: (context, snapshot) {
                  final records = (snapshot.data ?? const <CreatedRoomRecord>[])
                      .take(2)
                      .toList();
                  if (records.isEmpty) {
                    return Text(
                      '还没有建房记录',
                      style: DuelType.sans(8, color: DuelColors.textGhost),
                    );
                  }
                  return Column(
                    children: [
                      for (final r in records)
                        DuelHit(
                          onTap: () => widget.onJoin(r),
                          child: SizedBox(
                            height: 18,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DuelType.sans(
                                      8,
                                      color: DuelColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '加入 ›',
                                  style: DuelType.sans(
                                    7.5,
                                    color: DuelColors.accent,
                                  ),
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
          ],
        ),
      ),
    );
  }
}
