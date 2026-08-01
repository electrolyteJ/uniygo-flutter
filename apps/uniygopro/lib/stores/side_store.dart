import 'package:flutter/foundation.dart';

enum SideStage { none, sideChanging, sideChanged, waiting, tpSelecting, tpSelected, duelStart }

class SideStore extends ChangeNotifier {
  SideStage stage = SideStage.none;

  void enterSide() { stage = SideStage.sideChanging; notifyListeners(); }
  void waiting() { stage = SideStage.waiting; notifyListeners(); }
  void startDuel() { stage = SideStage.duelStart; notifyListeners(); }
  void reset() { stage = SideStage.none; notifyListeners(); }
}
