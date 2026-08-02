import 'package:flutter/foundation.dart';

/// 对局界面本地 UI 状态仓库。
///
/// 这里只放纯展示态，例如检查器、手牌选中、区域浏览器等，
/// 不承载来自服务端的规则状态。
class DuelUiStore extends ChangeNotifier {
  String? inspectedZoneKey;
  int? inspectedCardCode;
  int? selectedHandCardCode;
  String? openZoneBrowserKey;
  bool showInspector = true;

  void markChanged() {
    notifyListeners();
  }

  void reset() {
    inspectedZoneKey = null;
    inspectedCardCode = null;
    selectedHandCardCode = null;
    openZoneBrowserKey = null;
    showInspector = true;
    notifyListeners();
  }

  void inspectZone(String zoneKey) {
    inspectedZoneKey = zoneKey;
    notifyListeners();
  }

  void clearInspectedZone() {
    inspectedZoneKey = null;
    notifyListeners();
  }
}
