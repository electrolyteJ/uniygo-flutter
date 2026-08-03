import 'package:flutter/foundation.dart';

/// Side 阶段流程状态。
enum SideStage { none, sideChanging, sideChanged, waiting, tpSelecting, tpSelected, duelStart }

/// Side 流程仓库。
///
/// 用于表达换 side、等待、重新开局等流程节点，方便页面按阶段切换 UI。
class SideStore extends ChangeNotifier {
  SideStage stage = SideStage.none;

  void enterSide() { stage = SideStage.sideChanging; notifyListeners(); }
  void waiting() { stage = SideStage.waiting; notifyListeners(); }
  void startDuel() { stage = SideStage.duelStart; notifyListeners(); }
  void reset() { stage = SideStage.none; notifyListeners(); }
}
