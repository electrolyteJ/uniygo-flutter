import 'package:flutter/foundation.dart';

/// 操作菜单条目：标签 + 点击回调。
/// 由业务侧（store / resolver）构建，UI 组件只负责渲染与触发回调。
class ActionMenuEntry {
  final String label;
  final VoidCallback onTap;

  const ActionMenuEntry({required this.label, required this.onTap});
}

/// 区域浏览弹窗中的一张卡（区域序号 + 卡号）。
class ZoneBrowserCardEntry {
  final int sequence;
  final int code;

  const ZoneBrowserCardEntry({required this.sequence, required this.code});
}
