import 'dart:async';
import 'dart:developer' as console;
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';

import 'package:ygo_card/card_info.dart' as pkg;

/// 对局页面的轻量级聚合状态。
///
/// 当前仅保留跨多个子 store 共用、且不适合放入具体子域的状态，
/// 例如决斗日志与当前绑定的对局服务引用。
class DuelRoomState extends ChangeNotifier {
  List<String> duelLogs = [];

  // === 共享 ===
  IDuelService? _service;

  // ══════════════════════════════════════════
  // 等待房间方法 (from RoomStore)
  // ══════════════════════════════════════════

  DuelRoomState() {}

  void markChanged() {
    notifyListeners();
  }

  // ══════════════════════════════════════════
  // 决斗方法 (from DuelStore)
  // ══════════════════════════════════════════

  void bind(IDuelService service) {
    _service = service;
  }

  void reset() {
    duelLogs = [];
    _service = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    console.log('DuelRoomStore disposed');
  }
}
