/// 卡组编辑器保存结果（store 内部类型）。
///
/// 路由边界不直接使用本类型：`/deck-editor` 的参数与返回值均用
/// 通用 `Map<String, Object?>` 传递（见 config_route.dart 与
/// DeckEditorStore.lastSaveResultForRoute），让调用方（如 duel_room1
/// 的等待室）不必依赖卡组编辑器的类型。
class DeckEditorSaveResult {
  const DeckEditorSaveResult({required this.saved, this.validationErrors});

  final bool saved;
  final List<String>? validationErrors;

  bool get isCompliant => validationErrors?.isEmpty ?? true;
}
