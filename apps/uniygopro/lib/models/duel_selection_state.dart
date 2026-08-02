import 'BattleAction.dart';
import 'IdleAction.dart';
import 'SelectState.dart';

class DuelSelectionState {
  List<IdleAction> selectedIdleActions = [];
  List<BattleAction> selectedBattleActions = [];
  bool enableBp = false;
  bool enableM2 = false;
  bool enableEp = false;
  SelectState? currentSelect;

  bool get isWaitingForInput => currentSelect != null;

  void reset() {
    selectedIdleActions = [];
    selectedBattleActions = [];
    enableBp = false;
    enableM2 = false;
    enableEp = false;
    currentSelect = null;
  }
}
