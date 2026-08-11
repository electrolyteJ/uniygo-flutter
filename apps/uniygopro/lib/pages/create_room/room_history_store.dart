import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/created_room_record.dart';

/// 创建房间历史记录的本地持久化（SharedPreferences）。
class RoomHistoryStore {
  static const String _key = 'created_room_history';
  static const int _maxRecords = 20;

  /// 读取全部历史（按创建时间倒序）。
  static Future<List<CreatedRoomRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final records = <CreatedRoomRecord>[];
    for (final s in raw) {
      try {
        records.add(CreatedRoomRecord.fromJson(
            jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // 忽略损坏的记录
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// 新增一条记录：同参数记录去重置顶，最多保留 [_maxRecords] 条。
  static Future<void> add(CreatedRoomRecord record) async {
    final records = await load();
    records.removeWhere((r) => r.identity == record.identity);
    records.insert(0, record);
    if (records.length > _maxRecords) {
      records.removeRange(_maxRecords, records.length);
    }
    await _save(records);
  }

  static Future<void> remove(CreatedRoomRecord record) async {
    final records = await load();
    records.removeWhere((r) => r.identity == record.identity);
    await _save(records);
  }

  static Future<void> _save(List<CreatedRoomRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, records.map((r) => jsonEncode(r.toJson())).toList());
  }
}
